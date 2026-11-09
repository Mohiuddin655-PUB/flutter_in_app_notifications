import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../enums/banner_edge.dart';

/// The banner where the drag has it: moved by [offset], and faded and shrunk as far as it is out. Painted, not built:
/// each frame only sets the transform and the opacity.
class InAppNotificationFollow extends StatelessWidget {
  const InAppNotificationFollow({super.key, required this.offset, required this.height, this.edge = BannerEdge.top, required this.child});

  final Animation<double> offset;
  final double Function() height;

  /// The edge it goes out at: how far out it is counts that way.
  final BannerEdge edge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final out = _Out(offset, height, edge.outward);
    return _Translate(
      offset: offset,
      child: FadeTransition(
        opacity: _Fade(out),
        child: ScaleTransition(scale: _Shrink(out), alignment: edge.anchor, child: child),
      ),
    );
  }
}

/// How far out it is, 0 in its place to 1 gone.
class _Out extends Animation<double> with AnimationWithParentMixin<double> {
  _Out(this.parent, this.height, this.outward);

  @override
  final Animation<double> parent;
  final double Function() height;
  final double outward;

  @override
  double get value => (parent.value * outward / (height() + 24)).clamp(0.0, 1.0);
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
    return result.addWithPaintOffset(
      offset: Offset(0, _offset.value),
      position: position,
      hitTest: (r, p) => super.hitTestChildren(r, position: p),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) => super.paint(context, offset + Offset(0, _offset.value));

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(0, _offset.value, 0, 1);
}
