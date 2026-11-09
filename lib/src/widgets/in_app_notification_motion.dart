import 'package:flutter/widgets.dart';

/// How the banner comes and goes, as Discord's.
abstract final class InAppNotificationMotion {
  /// How it comes: down from above its place, growing from a little smaller and fading in, a touch past its place and
  /// back, so it lands softly.
  static const arrive = Cubic(0.16, 1.22, 0.3, 1);

  /// How it goes: up, shrinking a little and fading out, quicker at the end.
  static const leave = Cubic(0.55, 0, 0.75, 0.6);

  /// Its coming and going, as Discord's: for `InAppNotificationGate.transitionBuilder` (the gate's default). Built
  /// from transitions, so a frame only repaints and moves it, nothing is built again.
  static Widget transition(Widget child, Animation<double> animation) {
    final move = CurvedAnimation(parent: animation, curve: arrive, reverseCurve: leave.flipped);
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    return SlideTransition(
      position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(move),
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(move), alignment: Alignment.topCenter, child: child),
      ),
    );
  }

  /// A plain slide down from the top, and back up.
  static Widget slide(Widget child, Animation<double> animation) {
    return SlideTransition(
      position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }
}
