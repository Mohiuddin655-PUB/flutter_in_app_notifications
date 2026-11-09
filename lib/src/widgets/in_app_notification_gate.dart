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

  @override
  void initState() {
    super.initState();
    InAppNotifications.inApp.addListener(_changed);
    InAppNotifications.holding.addListener(_changed);
    _changed();
  }

  void _changed() {
    _timer?.cancel();
    // Held (a reply being typed): it stays until let go, then has its full time again.
    final message = InAppNotifications.inApp.value;
    if (message == null || InAppNotifications.holding.value) return;
    final look = _look(message);
    if (look?.stays ?? false) return;
    _timer = Timer(look?.showFor ?? widget.showFor, InAppNotifications.dismiss);
  }

  /// The look [message] names, if the gate has it.
  BannerLook? _look(PushMessage? message) => message?.look == null ? null : widget.looks[message!.look];

  @override
  void dispose() {
    _timer?.cancel();
    InAppNotifications.inApp.removeListener(_changed);
    InAppNotifications.holding.removeListener(_changed);
    super.dispose();
  }

  Widget _layout(Widget? current, List<Widget> previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]);

  /// Each banner comes and goes its own look's way, and sits where it says: one going keeps its own while the next
  /// comes in another.
  Widget _transition(Widget child, Animation<double> animation) {
    final look = child is _Shown ? child.look : null;
    final edge = look?.edge ?? widget.edge;
    final move = look?.transitionBuilder ?? (look?.edge == null ? widget.transitionBuilder : null) ?? InAppNotificationMotion.transitionAt(edge);
    final at = look?.alignment ?? (look?.edge == null ? widget.alignment : null) ?? edge.alignment;
    return Align(alignment: at, child: move(child, animation));
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        ValueListenableBuilder<PushMessage?>(
          valueListenable: InAppNotifications.inApp,
          builder: (context, message, _) {
            final look = _look(message);
            return AnimatedSwitcher(
              duration: still ? Duration.zero : look?.enter ?? widget.enter,
              reverseDuration: still ? Duration.zero : look?.exit ?? widget.exit,
              transitionBuilder: _transition,
              layoutBuilder: _layout,
              child: message == null
                  ? const SizedBox.shrink()
                  : _Shown(
                      key: ValueKey(message.id),
                      look: look,
                      child: BannerEdgeScope(
                        edge: look?.edge ?? widget.edge,
                        child: Builder(
                          builder: (context) => (look?.builder ?? widget.builder)(context, message, InAppNotifications.open, InAppNotifications.dismiss),
                        ),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

/// A banner with the look it shows in, for its transition.
class _Shown extends StatelessWidget {
  const _Shown({super.key, required this.look, required this.child});

  final BannerLook? look;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
