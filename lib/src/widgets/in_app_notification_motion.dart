import 'package:flutter/widgets.dart';

import '../enums/in_app_notification_edge.dart';

/// How the in-app notification comes and goes, as Discord's.
abstract final class InAppNotificationMotion {
  /// How it comes: down from above its place, growing from a little smaller and fading in, a touch past its place and
  /// back, so it lands softly.
  static const arrive = Cubic(0.16, 1.22, 0.3, 1);

  /// How it goes: up, shrinking a little and fading out, quicker at the end.
  static const leave = Cubic(0.55, 0, 0.75, 0.6);

  /// Its coming and going, as Discord's: for the app's overlay that shows the in-app notification. Built from
  /// transitions: a frame moves, fades and scales the in-app notification without building it again.
  static Widget transition(Widget child, Animation<double> animation) => transitionAt(InAppNotificationEdge.top)(child, animation);

  /// [transition] for an in-app notification at [edge]: in from that edge and back out to it.
  static AnimatedSwitcherTransitionBuilder transitionAt(InAppNotificationEdge edge) =>
      (child, animation) => _move(child, animation, edge);

  /// The curves made for each in-app notification's animation, once: a transition built again (its in-app notification
  /// rebuilt) reuses them rather than adding new ones to the animation each time. They go with it.
  static final _moves = Expando<(CurvedAnimation, CurvedAnimation)>();

  static Widget _move(Widget child, Animation<double> animation, InAppNotificationEdge edge) {
    final (move, fade) = _moves[animation] ??= (
      CurvedAnimation(parent: animation, curve: arrive, reverseCurve: leave.flipped),
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      ),
    );
    return SlideTransition(
      position: Tween(begin: Offset(0, edge.outward), end: Offset.zero).animate(move),
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(move), alignment: edge.anchor, child: child),
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
