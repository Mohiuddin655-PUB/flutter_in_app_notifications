import 'dart:math' as math;

import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../in_app_notifications.dart';

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

  void _down(PointerDownEvent _) {
    if (!_leaving) InAppNotifications.hold(true, reason: this);
  }

  void _up(PointerEvent _) {
    // Still in its place (a tap, a hold): it goes on its time again. Dragged, the let-go decides.
    if (!_leaving && !_offset.isAnimating && _offset.value == 0) InAppNotifications.hold(false, reason: this);
  }

  void _start(DragStartDetails _) {
    _offset.stop();
    _height = math.max(context.size?.height ?? 1, 1);
  }

  void _update(DragUpdateDetails d) {
    if (_leaving) return;
    final y = _offset.value;
    final dy = d.delta.dy;
    // Up: exactly with the finger. Down past its place: ever less, as if held by a spring.
    _offset.value = (y + dy <= 0 || dy < 0) && y <= 0 ? y + dy : y + dy / (1 + math.max(y, 0) / 24);
  }

  void _end(DragEndDetails d) {
    if (_leaving) return;
    final speed = d.velocity.pixelsPerSecond.dy;
    final out = _offset.value < -_height * _outShare || speed < -_flingSpeed;
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
    final target = -(_height + MediaQuery.paddingOf(context).top + 24);
    final distance = (target - _offset.value).abs();
    final start = math.max(-speed, 900);
    final ms = (3 * distance / start * 1000).clamp(120, 360).round();
    _offset.animateTo(target, duration: Duration(milliseconds: ms), curve: Curves.easeOutCubic).whenComplete(() {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: GestureDetector(
        onVerticalDragStart: widget.enabled ? _start : null,
        onVerticalDragUpdate: widget.enabled ? _update : null,
        onVerticalDragEnd: widget.enabled ? _end : null,
        // Driven straight from the drag: a frame moves, fades and scales it without building anything again.
        child: _Follow(offset: _offset, height: () => _height, child: widget.child),
      ),
    );
  }
}

/// The banner where the drag has it: moved by [offset], and faded and shrunk as far as it is out. Painted, not built:
/// each frame only sets the transform and the opacity.
class _Follow extends StatelessWidget {
  const _Follow({required this.offset, required this.height, required this.child});

  final Animation<double> offset;
  final double Function() height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final out = _Out(offset, height);
    return _Translate(
      offset: offset,
      child: FadeTransition(
        opacity: _Fade(out),
        child: ScaleTransition(scale: _Shrink(out), alignment: Alignment.topCenter, child: child),
      ),
    );
  }
}

/// How far out it is, 0 in its place to 1 gone.
class _Out extends Animation<double> with AnimationWithParentMixin<double> {
  _Out(this.parent, this.height);

  @override
  final Animation<double> parent;
  final double Function() height;

  @override
  double get value => (-parent.value / (height() + 24)).clamp(0.0, 1.0);
}

class _Fade extends Animation<double> with AnimationWithParentMixin<double> {
  _Fade(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => 1 - parent.value;
}

class _Shrink extends Animation<double> with AnimationWithParentMixin<double> {
  _Shrink(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => 1 - 0.06 * parent.value;
}

/// Moved by [offset] pixels down (up when negative), repainted on each change without a build.
class _Translate extends SingleChildRenderObjectWidget {
  const _Translate({required this.offset, super.child});

  final Animation<double> offset;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTranslate(offset);

  @override
  void updateRenderObject(BuildContext context, _RenderTranslate renderObject) => renderObject.offset = offset;
}

class _RenderTranslate extends RenderProxyBox {
  _RenderTranslate(this._offset);

  Animation<double> _offset;
  set offset(Animation<double> value) {
    if (value == _offset) return;
    if (attached) _offset.removeListener(markNeedsPaint);
    _offset = value;
    if (attached) _offset.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _offset.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(offset: Offset(0, _offset.value), position: position, hitTest: (r, p) => super.hitTestChildren(r, position: p));
  }

  @override
  void paint(PaintingContext context, Offset offset) => super.paint(context, offset + Offset(0, _offset.value));

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(0, _offset.value, 0, 1);
}
