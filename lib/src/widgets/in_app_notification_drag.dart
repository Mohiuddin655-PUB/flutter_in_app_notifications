import 'dart:math' as math;

import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:flutter/gestures.dart' show VelocityTracker;
import 'package:flutter/widgets.dart';

import '../in_app_notifications.dart';
import '../enums/banner_edge.dart';
import 'in_app_notification_follow.dart';

/// Lets the banner be held and swiped up, as Discord's do. A finger on it holds it (it doesn't go by itself); dragged,
/// it follows the finger exactly (up one to one; down only a little, ever harder). Let go far enough up, or flung up,
/// it carries on out from where it is, at the finger's speed, fading and shrinking as it goes, then [onDismiss]; let go
/// short of that, it springs back from where it is.
class InAppNotificationDrag extends StatefulWidget {
  const InAppNotificationDrag({super.key, required this.onDismiss, required this.child, this.enabled = true});

  final VoidCallback onDismiss;
  final Widget child;

  /// False: it can't be dragged (a finger on it still holds it).
  final bool enabled;

  @override
  State<InAppNotificationDrag> createState() => _InAppNotificationDragState();
}

class _InAppNotificationDragState extends State<InAppNotificationDrag> with SingleTickerProviderStateMixin {
  /// How far it is from its place, in pixels (up is negative).
  late final _offset = AnimationController.unbounded(vsync: this);

  double _height = 1;
  bool _leaving = false;

  /// Up past this share of its height, a let-go carries it out.
  static const _outShare = 0.35;

  /// Flung up faster than this (pixels a second), it goes whatever the distance.
  static const _flingSpeed = 600.0;

  static const _spring = SpringDescription(mass: 1, stiffness: 520, damping: 34);

  @override
  void dispose() {
    InAppNotifications.hold(false, reason: this);
    _offset.dispose();
    super.dispose();
  }

  // The finger is followed from the moment it touches, by its own position, not by the drag's deltas: a drag is only
  // recognised once it has moved a little, and following its deltas would leave the banner that far behind.
  int? _pointer;
  double _downY = 0;
  double _from = 0;
  VelocityTracker? _velocity;

  void _down(PointerDownEvent e) {
    if (_leaving || _pointer != null) return;
    InAppNotifications.hold(true, reason: this);
    if (!widget.enabled) return;
    _offset.stop();
    _pointer = e.pointer;
    _downY = e.position.dy;
    _from = _offset.value;
    _height = math.max(context.size?.height ?? 1, 1);
    _velocity = VelocityTracker.withKind(e.kind)..addPosition(e.timeStamp, e.position);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer || _leaving) return;
    _velocity?.addPosition(e.timeStamp, e.position);
    // Outward (toward its edge): exactly with the finger. Inward past its place: ever less, as if held by a spring
    // (never past 60).
    final s = BannerEdge.of(context).outward;
    final out = (_from + e.position.dy - _downY) * s;
    _offset.value = (out >= 0 ? out : -60 * -out / (-out + 60)) * s;
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) {
      // Not dragging (turned off): a finger let go lets it go on its time.
      if (_pointer == null && !_leaving) InAppNotifications.hold(false, reason: this);
      return;
    }
    _pointer = null;
    final speed = e is PointerUpEvent ? _velocity?.getVelocity().pixelsPerSecond.dy ?? 0 : 0.0;
    _velocity = null;
    // Barely moved (a tap, a hold): back in its place, and it goes on its time again.
    if (_offset.value.abs() < 1 && speed.abs() < 100) {
      _offset.value = 0;
      InAppNotifications.hold(false, reason: this);
      return;
    }
    _end(speed);
  }

  /// Let go at [speed] (pixels a second, up is negative).
  void _end(double speed) {
    if (_leaving) return;
    final edge = BannerEdge.of(context);
    final s = edge.outward;
    final out = _offset.value * s > _height * _outShare || speed * s > _flingSpeed;
    if (!out) {
      // Back from where it is, with the finger's speed.
      _offset.animateWith(SpringSimulation(_spring, _offset.value, 0, speed)).whenComplete(() {
        if (mounted) InAppNotifications.hold(false, reason: this);
      });
      return;
    }
    _leaving = true;
    // Out from where it is: the rest of the way past the top, starting at the finger's speed (ease-out starts three
    // times its average speed), so nothing jumps.
    final inset = edge == BannerEdge.top ? MediaQuery.paddingOf(context).top : MediaQuery.paddingOf(context).bottom;
    final target = s * (_height + inset + 24);
    final distance = (target - _offset.value).abs();
    final start = math.max(speed * s, 900);
    final ms = (3 * distance / start * 1000).clamp(120, 360).round();
    _offset
        .animateTo(
          target,
          duration: Duration(milliseconds: ms),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted) widget.onDismiss();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      // Claims a vertical drag once it is one, so it isn't also a tap on the banner (which would open it).
      child: GestureDetector(
        onVerticalDragStart: widget.enabled ? (_) {} : null,
        onVerticalDragEnd: widget.enabled ? (_) {} : null,
        // Driven straight from the drag: a frame moves, fades and scales it without building anything again.
        child: InAppNotificationFollow(offset: _offset, height: () => _height, edge: BannerEdge.of(context), child: widget.child),
      ),
    );
  }
}
