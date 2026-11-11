import 'package:flutter/widgets.dart';

import '../enums/banner_edge.dart';

/// How the banner comes and goes, as Discord's.
abstract final class InAppNotificationMotion {
  /// How it comes: down from above its place, growing from a little smaller and fading in, a touch past its place and
  /// back, so it lands softly.
  static const arrive = Cubic(0.16, 1.22, 0.3, 1);

  /// How it goes: up, shrinking a little and fading out, quicker at the end.
  static const leave = Cubic(0.55, 0, 0.75, 0.6);

  /// Its coming and going, as Discord's: for the app's overlay that shows the banner. Built from transitions: a frame
  /// moves, fades and scales the banner without building it again.
  static Widget transition(Widget child, Animation<double> animation) => transitionAt(BannerEdge.top)(child, animation);

  /// [transition] for a banner at [edge]: in from that edge and back out to it.
  static AnimatedSwitcherTransitionBuilder transitionAt(BannerEdge edge) =>
      (child, animation) => _move(child, animation, edge);

  /// The curves made for each banner's animation, once: a transition built again (its banner rebuilt) reuses them
  /// rather than adding new ones to the animation each time. They go with it.
  static final _moves = Expando<(CurvedAnimation, CurvedAnimation)>();
  static final _pops = Expando<(CurvedAnimation, CurvedAnimation)>();

  static Widget _move(Widget child, Animation<double> animation, BannerEdge edge) {
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

  /// A popup's coming and going: in place, growing from a little smaller and fading in, a touch past its size; back
  /// out shrinking and fading.
  static Widget pop(Widget child, Animation<double> animation) {
    final (grow, fade) = _pops[animation] ??= (
      CurvedAnimation(parent: animation, curve: arrive, reverseCurve: leave.flipped),
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      ),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: Tween(begin: 0.86, end: 1.0).animate(grow), child: child),
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
