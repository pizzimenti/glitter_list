import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

/// Renders a sharp `bg`, then on top of it a Gaussian-blurred copy of `bg`
/// masked by the alpha of `foreground` (also Gaussian-blurred outward to
/// produce a soft cloud falloff), then the sharp `foreground` on top.
///
/// Effect: the bg pixels behind and around opaque foreground content
/// (text, icons, the FAB) are genuinely blurred — `ImageFilter.blur` is
/// applied to the bg, not just a colored shadow over it. Empty regions
/// of the screen show the raw bg. The softness of the transition is
/// controlled by [maskBlurSigma]: the foreground silhouette is convolved
/// with that blur kernel before it gates the blurred-bg layer via
/// `BlendMode.dstIn`, so alpha falls off Gaussianly with distance from
/// the silhouette edge.
///
/// The foreground render object is painted twice per frame — once as the
/// alpha mask, once visibly on top. Cost is roughly 2× foreground paint
/// plus two blur passes; budget accordingly.
class CloudBlur extends MultiChildRenderObjectWidget {
  CloudBlur({
    super.key,
    required Widget bg,
    required Widget foreground,
    this.bgBlurSigma = 14,
    this.maskBlurSigma = 8,
  }) : super(children: [bg, foreground]);

  /// Sigma of the Gaussian blur applied to the cloned bg copy. Bigger →
  /// the bg behind text gets fuzzier.
  final double bgBlurSigma;

  /// Sigma of the Gaussian blur applied to the foreground silhouette
  /// before it's used as the alpha mask. Bigger → the cloud spreads
  /// further from text into the surrounding bg.
  final double maskBlurSigma;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCloudBlur(
      bgBlurSigma: bgBlurSigma,
      maskBlurSigma: maskBlurSigma,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderCloudBlur)
      ..bgBlurSigma = bgBlurSigma
      ..maskBlurSigma = maskBlurSigma;
  }
}

class _CloudBlurParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderCloudBlur extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CloudBlurParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CloudBlurParentData> {
  _RenderCloudBlur({
    required double bgBlurSigma,
    required double maskBlurSigma,
  })  : _bgBlurSigma = bgBlurSigma,
        _maskBlurSigma = maskBlurSigma;

  double _bgBlurSigma;
  set bgBlurSigma(double v) {
    if (v == _bgBlurSigma) return;
    _bgBlurSigma = v;
    markNeedsPaint();
  }

  double _maskBlurSigma;
  set maskBlurSigma(double v) {
    if (v == _maskBlurSigma) return;
    _maskBlurSigma = v;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CloudBlurParentData) {
      child.parentData = _CloudBlurParentData();
    }
  }

  @override
  void performLayout() {
    final cs = constraints;
    RenderBox? c = firstChild;
    while (c != null) {
      c.layout(cs, parentUsesSize: false);
      (c.parentData! as _CloudBlurParentData).offset = Offset.zero;
      c = (c.parentData! as _CloudBlurParentData).nextSibling;
    }
    size = cs.biggest;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Only the foreground child handles input. The bg is purely visual.
    final kids = getChildrenAsList();
    if (kids.length >= 2) {
      return kids[1].hitTest(result, position: position);
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final kids = getChildrenAsList();
    if (kids.length < 2) {
      for (final c in kids) {
        context.paintChild(c, offset);
      }
      return;
    }
    final bg = kids[0];
    final fg = kids[1];
    final rect = offset & size;

    // Layer 1: sharp bg, normal compositing.
    context.paintChild(bg, offset);

    // Layer 2: blurred-bg copy gated by foreground silhouette mask.
    // Outer saveLayer establishes the compositing scope so the inner
    // dstIn blend only affects the blurred-bg pixels we just painted,
    // not the sharp bg from Layer 1.
    context.canvas.saveLayer(rect, Paint());

    // 2a — blurred-bg copy. ImageFilter.blur on the saveLayer's paint
    // applies the convolution as the layer composites back to its parent.
    context.canvas.saveLayer(
      rect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: _bgBlurSigma,
          sigmaY: _bgBlurSigma,
        ),
    );
    context.paintChild(bg, offset);
    context.canvas.restore();

    // 2b — alpha mask. Paint the foreground silhouette through a saveLayer
    // whose imageFilter blurs the silhouette outward (the cloud spread)
    // and whose blendMode dstIn keeps Layer 2's existing pixels (the
    // blurred bg) only where this layer has alpha.
    context.canvas.saveLayer(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: _maskBlurSigma,
          sigmaY: _maskBlurSigma,
        ),
    );
    context.paintChild(fg, offset);
    context.canvas.restore();

    context.canvas.restore(); // close Layer 2

    // Layer 3: sharp foreground on top of the masked-blur composite.
    context.paintChild(fg, offset);
  }
}
