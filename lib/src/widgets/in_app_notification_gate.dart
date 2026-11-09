import 'dart:async' show Timer;

import 'package:flutter/widgets.dart';

import '../in_app_notifications.dart';
import '../enums/banner_edge.dart';
import '../models/push_message.dart';
import '../parts/banner_state.dart';
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
  BannerState get _b => BannerState.i;

  /// Each lane's message (the main one under null), and what listens to it.
  var _lanes = <String?, ValueNotifier<PushMessage?>>{};
  final _listeners = <String?, VoidCallback>{};
  final _timers = <String?, Timer>{};

  /// The banners' layers, made once per configuration: a rebuild of the gate (the keyboard moving, the screen turning)
  /// hands the same widget down, so nothing under it is built again.
  late Widget _layer;

  @override
  void initState() {
    super.initState();
    _configure();
    _b.holding.addListener(_held);
  }

  @override
  void didUpdateWidget(InAppNotificationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  /// The lanes the looks ask for, each listened to and laid over the app.
  void _configure() {
    _unlisten();
    _b.laneOfLook
      ..clear()
      ..addAll({for (final e in widget.looks.entries) e.key: ?e.value.lane});
    _lanes = {null: _b.inApp, for (final lane in _b.laneOfLook.values) lane: _b.lane(lane)};
    for (final lane in _lanes.keys) {
      _listeners[lane] = () => _changed(lane);
      _lanes[lane]!.addListener(_listeners[lane]!);
      _changed(lane);
    }
    _layer = Overlay.wrap(
      child: Stack(
        fit: StackFit.expand,
        children: [for (final e in _lanes.entries) _Banners(gate: widget, lane: e.value, main: e.key == null)],
      ),
    );
  }

  void _unlisten() {
    for (final e in _listeners.entries) {
      _lanes[e.key]?.removeListener(e.value);
    }
    _listeners.clear();
  }

  void _held() => _changed(null);

  /// A lane's new message, or the banner held or let go: it goes by itself after its time, unless held (the main
  /// lane's) or its look [BannerLook.stays]; a time asked by `show()` comes first.
  void _changed(String? lane) {
    _timers.remove(lane)?.cancel();
    final notifier = _lanes[lane];
    final message = notifier?.value;
    if (notifier == null || message == null || (lane == null && _b.holding.value)) return;
    final look = _Banners.lookOf(widget, message);
    final time = _b.placement[message]?.showFor ?? (look?.stays ?? false ? null : look?.showFor ?? widget.showFor);
    if (time == null) return;
    _timers[lane] = Timer(time, () {
      if (lane == null) return InAppNotifications.dismiss();
      if (identical(notifier.value, message)) notifier.value = null;
    });
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _unlisten();
    _b.holding.removeListener(_held);
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

/// One lane's banners over the app, each in its look: built only when the lane's message changes.
class _Banners extends StatelessWidget {
  const _Banners({required this.gate, required this.lane, required this.main});

  final InAppNotificationGate gate;
  final ValueNotifier<PushMessage?> lane;

  /// The main lane: its tap and swipe go through `InAppNotifications` (open, dismiss).
  final bool main;

  /// The look [message] names, if the gate has it.
  static BannerLook? lookOf(InAppNotificationGate gate, PushMessage? message) => message?.look == null ? null : gate.looks[message!.look];

  Widget _layout(Widget? current, List<Widget> previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]);

  /// Each banner comes and goes its own look's way, and sits where it says (or where `show()` asked): one going keeps
  /// its own while the next comes in another. One going can't be touched: a tap meant for it would open the next.
  Widget _transition(Widget child, Animation<double> animation) {
    final shown = child is _Shown ? child : null;
    final look = shown?.look;
    final edge = shown?.edge ?? gate.edge;
    final own = look?.edge == null && shown?.placement?.edge == null;
    final move = look?.transitionBuilder ?? (own ? gate.transitionBuilder : null) ?? InAppNotificationMotion.transitionAt(edge);
    final at = look?.alignment ?? (own ? gate.alignment : null) ?? edge.alignment;
    final moved = _UntouchableLeaving(animation: animation, child: move(child, animation));
    final padding = shown?.placement?.padding;
    return Align(
      alignment: at,
      child: padding == null ? moved : Padding(padding: padding, child: moved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ValueListenableBuilder<PushMessage?>(
      valueListenable: lane,
      builder: (context, message, _) {
        final look = lookOf(gate, message);
        return AnimatedSwitcher(
          duration: still ? Duration.zero : look?.enter ?? gate.enter,
          reverseDuration: still ? Duration.zero : look?.exit ?? gate.exit,
          transitionBuilder: _transition,
          layoutBuilder: _layout,
          child: message == null
              ? const SizedBox.shrink()
              : _Shown(
                  key: ValueKey(message.id),
                  gate: gate,
                  lane: lane,
                  main: main,
                  message: message,
                  look: look,
                  placement: BannerState.i.placement[message],
                ),
        );
      },
    );
  }
}

/// One banner in its look. Its tap and its swipe act on it alone: once another has replaced it, they do nothing.
class _Shown extends StatelessWidget {
  const _Shown({super.key, required this.gate, required this.lane, required this.main, required this.message, required this.look, required this.placement});

  final InAppNotificationGate gate;
  final ValueNotifier<PushMessage?> lane;
  final bool main;
  final PushMessage message;
  final BannerLook? look;
  final BannerPlacement? placement;

  BannerEdge get edge => placement?.edge ?? look?.edge ?? gate.edge;

  bool get _current => lane.value?.id == message.id;

  void _open() {
    if (!_current) return;
    if (main) return InAppNotifications.open();
    lane.value = null;
    BannerState.i.open(message.data);
  }

  void _dismiss() {
    if (!_current) return;
    main ? InAppNotifications.dismiss() : lane.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return BannerEdgeScope(edge: edge, child: (look?.builder ?? gate.builder)(context, message, _open, _dismiss));
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
