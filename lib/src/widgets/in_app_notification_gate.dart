import 'dart:async' show Timer;

import 'package:flutter/widgets.dart';

import '../in_app_notifications.dart';
import 'in_app_notification_banner.dart';
import '../models/push_message.dart';

/// What shows for a push [message] inside the app: [onOpen] when it is tapped, [onDismiss] when it is swiped away.
typedef InAppNotificationBuilder = Widget Function(BuildContext context, PushMessage message, VoidCallback onOpen, VoidCallback onDismiss);

/// Wraps the app (in `MaterialApp.builder`, say) and shows what [builder] gives over [child], at [alignment], for each
/// push that comes while the app is open, with `setup(visibility: LocalNotificationVisibility.inApp)`: the newest
/// replaces the one showing, and it goes by itself after [showFor]. A tap opens its data (`InAppNotifications.open`).
/// It comes and goes through [transitionBuilder] ([enter] as it comes, [exit] as it goes, kept on screen until it has
/// gone); with animations turned off on the phone, at once. It draws nothing of its own: the app gives the look.
class InAppNotificationGate extends StatefulWidget {
  const InAppNotificationGate({
    super.key,
    required this.builder,
    required this.child,
    this.transitionBuilder = InAppNotificationBanner.transition,
    this.alignment = AlignmentDirectional.topCenter,
    this.showFor = const Duration(seconds: 4),
    this.enter = const Duration(milliseconds: 460),
    this.exit = const Duration(milliseconds: 240),
  });

  final InAppNotificationBuilder builder;
  final AnimatedSwitcherTransitionBuilder transitionBuilder;
  final AlignmentGeometry alignment;
  final Duration showFor;
  final Duration enter;
  final Duration exit;
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
    if (InAppNotifications.inApp.value != null && !InAppNotifications.holding.value) {
      _timer = Timer(widget.showFor, InAppNotifications.dismiss);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    InAppNotifications.inApp.removeListener(_changed);
    InAppNotifications.holding.removeListener(_changed);
    super.dispose();
  }

  Widget _layout(Widget? current, List<Widget> previous) => Stack(alignment: widget.alignment, children: [...previous, ?current]);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        ValueListenableBuilder<PushMessage?>(
          valueListenable: InAppNotifications.inApp,
          builder: (context, message, _) => AnimatedSwitcher(
            duration: still ? Duration.zero : widget.enter,
            reverseDuration: still ? Duration.zero : widget.exit,
            transitionBuilder: widget.transitionBuilder,
            layoutBuilder: _layout,
            child: message == null
                ? const SizedBox.shrink()
                : KeyedSubtree(key: ValueKey(message.id), child: widget.builder(context, message, InAppNotifications.open, InAppNotifications.dismiss)),
          ),
        ),
      ],
    );
  }
}
