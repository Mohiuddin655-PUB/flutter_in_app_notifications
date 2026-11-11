import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:in_app_notifications/in_app_notifications.dart';

/// The smallest place an app can draw [InAppNotifications.inApp] in, over its pages: the in-app notification comes in
/// from [edge] as Discord's, goes after [showFor] (not while held: a finger on it, a reply typed), sits above the
/// keyboard, and has its own Overlay so its reply field can be focused. A real app shows it where it shows its other
/// overlays (an app shell's extension, say).
class InAppNotificationHost extends StatefulWidget {
  const InAppNotificationHost({super.key, required this.edge, required this.child, this.showFor = const Duration(seconds: 4)});

  final InAppNotificationEdge edge;
  final Duration showFor;
  final Widget child;

  @override
  State<InAppNotificationHost> createState() => _BannerHostState();
}

class _BannerHostState extends State<InAppNotificationHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    InAppNotifications.inApp.addListener(_time);
    InAppNotifications.holding.addListener(_time);
  }

  @override
  void dispose() {
    _timer?.cancel();
    InAppNotifications.inApp.removeListener(_time);
    InAppNotifications.holding.removeListener(_time);
    super.dispose();
  }

  /// Its time starts again with each new one, and after each hold.
  void _time() {
    _timer?.cancel();
    if (InAppNotifications.inApp.value == null || InAppNotifications.holding.value) return;
    _timer = Timer(widget.showFor, InAppNotifications.dismiss);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: MediaQuery(
            data: media.removeViewInsets(removeBottom: true).removePadding(removeBottom: keyboard > 0),
            child: Overlay.wrap(
              child: ValueListenableBuilder<PushMessage?>(
                valueListenable: InAppNotifications.inApp,
                builder: (context, message, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 460),
                  reverseDuration: const Duration(milliseconds: 240),
                  transitionBuilder: InAppNotificationMotion.transitionAt(widget.edge),
                  layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
                  child: message == null
                      ? const SizedBox.shrink()
                      : Align(
                          key: ValueKey(message),
                          alignment: widget.edge.alignment,
                          child: InAppNotificationEdgeScope(
                            edge: widget.edge,
                            child: InAppNotificationView(message: message, onOpen: InAppNotifications.open, onDismiss: InAppNotifications.dismiss),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
