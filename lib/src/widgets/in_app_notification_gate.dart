import 'dart:async' show Timer;

import 'package:flutter/widgets.dart';

import '../in_app_notifications.dart';
import '../enums/banner_edge.dart';
import '../models/push_message.dart';
import 'in_app_notification_look.dart';
import 'in_app_notification_motion.dart';

/// What shows for a push [message] inside the app: [onOpen] when it is tapped, [onDismiss] when it is swiped away.
typedef InAppNotificationBuilder = Widget Function(BuildContext context, PushMessage message, VoidCallback onOpen, VoidCallback onDismiss);

/// Wraps the app (in `MaterialApp.builder`, say) and shows what [builder] gives over [child], at [alignment], for each
/// message sent with `InAppNotifications.show()`, and each notification while the app is open with
/// `setup(whileOpen: WhileOpen.banner)` or `bannerOnly`: the newest
/// replaces the one showing, and it goes by itself after [showFor]. A tap opens its data (`InAppNotifications.open`).
/// It comes and goes through [transitionBuilder] ([enter] as it comes, [exit] as it goes, kept on screen until it has
/// gone); with animations turned off on the phone, at once. It draws nothing of its own: the app gives the look.
/// The same banner shows other ways by name, from [looks] (a toast, a snackbar, a popup): a message naming one
/// (`show(look: 'toast')`, a push's `look` in its data) shows that way, each value the look leaves out the gate's own.
class InAppNotificationGate extends StatefulWidget {
  const InAppNotificationGate({
    super.key,
    required this.builder,
    required this.child,
    this.edge = BannerEdge.top,
    this.transitionBuilder,
    this.alignment,
    this.showFor = const Duration(seconds: 4),
    this.enter = const Duration(milliseconds: 460),
    this.exit = const Duration(milliseconds: 240),
    this.looks = const {},
  });

  final InAppNotificationBuilder builder;

  /// The edge it shows at: it comes in from there and is swiped back out that way.
  final BannerEdge edge;

  /// Its coming and going; by default as Discord's, from [edge] (`InAppNotificationMotion.transitionAt`).
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;

  /// Where it sits; by default at [edge].
  final AlignmentGeometry? alignment;
  final Duration showFor;
  final Duration enter;
  final Duration exit;

  /// Other ways it shows, by name (`{'toast': BannerLook.toast(), 'popup': BannerLook.popup()}`).
  final Map<String, BannerLook> looks;
  final Widget child;

  @override
  State<InAppNotificationGate> createState() => _InAppNotificationGateState();
}

class _InAppNotificationGateState extends State<InAppNotificationGate> {
  Timer? _timer;

  /// The banners' layer, made once per configuration: a rebuild of the gate (the keyboard moving, the screen turning)
  /// hands the same widget down, so nothing under it is built again.
  late Widget _layer = _layerFor(widget);

  static Widget _layerFor(InAppNotificationGate gate) => Overlay.wrap(child: _Banners(gate));

  @override
  void initState() {
    super.initState();
    InAppNotifications.inApp.addListener(_changed);
    InAppNotifications.holding.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(InAppNotificationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _layer = _layerFor(widget);
    if (widget.showFor != oldWidget.showFor || widget.looks != oldWidget.looks) _changed();
  }

  /// A new banner, or one held or let go: it goes by itself after its time, unless held or its look [BannerLook.stays].
  void _changed() {
    _timer?.cancel();
    final message = InAppNotifications.inApp.value;
    if (message == null || InAppNotifications.holding.value) return;
    final look = _Banners.lookOf(widget, message);
    if (look?.stays ?? false) return;
    _timer = Timer(look?.showFor ?? widget.showFor, InAppNotifications.dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    InAppNotifications.inApp.removeListener(_changed);
    InAppNotifications.holding.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Over the keyboard: one at the bottom (a reply being typed) sits above it, not under it. Above it, neither the
    // keyboard nor the screen's bottom edge it covers is in the way.
    final keyboard = media.viewInsets.bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: MediaQuery(
            data: media.removeViewInsets(removeBottom: true).removePadding(removeBottom: keyboard > 0),
            child: _layer,
          ),
        ),
      ],
    );
  }
}

/// The banners over the app, each in its look: built only when the banner changes.
class _Banners extends StatelessWidget {
  const _Banners(this.gate);

  final InAppNotificationGate gate;

  /// The look [message] names, if the gate has it.
  static BannerLook? lookOf(InAppNotificationGate gate, PushMessage? message) => message?.look == null ? null : gate.looks[message!.look];

  Widget _layout(Widget? current, List<Widget> previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]);

  /// Each banner comes and goes its own look's way, and sits where it says: one going keeps its own while the next
  /// comes in another. One going can't be touched: a tap meant for it would open the next.
  Widget _transition(Widget child, Animation<double> animation) {
    final look = child is _Shown ? child.look : null;
    final edge = look?.edge ?? gate.edge;
    final own = look?.edge == null;
    final move = look?.transitionBuilder ?? (own ? gate.transitionBuilder : null) ?? InAppNotificationMotion.transitionAt(edge);
    final at = look?.alignment ?? (own ? gate.alignment : null) ?? edge.alignment;
    return Align(
      alignment: at,
      child: _UntouchableLeaving(animation: animation, child: move(child, animation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ValueListenableBuilder<PushMessage?>(
      valueListenable: InAppNotifications.inApp,
      builder: (context, message, _) {
        final look = lookOf(gate, message);
        return AnimatedSwitcher(
          duration: still ? Duration.zero : look?.enter ?? gate.enter,
          reverseDuration: still ? Duration.zero : look?.exit ?? gate.exit,
          transitionBuilder: _transition,
          layoutBuilder: _layout,
          child: message == null ? const SizedBox.shrink() : _Shown(key: ValueKey(message.id), gate: gate, message: message, look: look),
        );
      },
    );
  }
}

/// One banner in its look. Its tap and its swipe act on it alone: once another has replaced it, they do nothing.
class _Shown extends StatelessWidget {
  const _Shown({super.key, required this.gate, required this.message, required this.look});

  final InAppNotificationGate gate;
  final PushMessage message;
  final BannerLook? look;

  bool get _current => InAppNotifications.inApp.value?.id == message.id;

  void _open() {
    if (_current) InAppNotifications.open();
  }

  void _dismiss() {
    if (_current) InAppNotifications.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return BannerEdgeScope(edge: look?.edge ?? gate.edge, child: (look?.builder ?? gate.builder)(context, message, _open, _dismiss));
  }
}

/// [child] can't be touched while [animation] runs back (it is going).
class _UntouchableLeaving extends StatefulWidget {
  const _UntouchableLeaving({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_UntouchableLeaving> createState() => _UntouchableLeavingState();
}

class _UntouchableLeavingState extends State<_UntouchableLeaving> {
  bool get _leaving => widget.animation.status == AnimationStatus.reverse || widget.animation.status == AnimationStatus.dismissed;

  late bool _ignoring = _leaving;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_status);
  }

  @override
  void didUpdateWidget(_UntouchableLeaving oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) return;
    oldWidget.animation.removeStatusListener(_status);
    widget.animation.addStatusListener(_status);
    _status(widget.animation.status);
  }

  void _status(AnimationStatus _) {
    if (_leaving != _ignoring) setState(() => _ignoring = _leaving);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_status);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(ignoring: _ignoring, child: widget.child);
}
