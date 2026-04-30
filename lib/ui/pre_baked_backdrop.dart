import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'baked_bg.dart';

/// Paints a slice of the pre-baked, pre-blurred bg [BakedBg.image] at
/// this widget's current screen position via `canvas.drawImageRect` —
/// no live `BackdropFilter`, so no engine re-rasterization race during
/// scroll. The slice is computed at paint time from the render box's
/// global position, so as the parent scrollable shifts items, each
/// strip naturally samples the corresponding screen-aligned region of
/// the bake.
///
/// The widget sizes itself to its parent's tight constraint (typically
/// a `Positioned` rect inside `PerLineBackdropBlur`'s `Stack`) and
/// paints fully.
class PreBakedBackdrop extends LeafRenderObjectWidget {
  const PreBakedBackdrop({super.key, required this.baked});

  final BakedBg baked;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPreBakedBackdrop(image: baked.image, bakedSize: baked.size);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPreBakedBackdrop)
      ..image = baked.image
      ..bakedSize = baked.size;
  }
}

class _RenderPreBakedBackdrop extends RenderBox {
  _RenderPreBakedBackdrop({
    required ui.Image image,
    required Size bakedSize,
  })  : _image = image,
        _bakedSize = bakedSize;

  ui.Image _image;
  set image(ui.Image value) {
    if (identical(value, _image)) return;
    _image = value;
    markNeedsPaint();
  }

  Size _bakedSize;
  set bakedSize(Size value) {
    if (value == _bakedSize) return;
    _bakedSize = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;

    // Where am I on screen?
    final screenPos = localToGlobal(Offset.zero);

    // Pre-baked image coords are 1:1 with the screen viewport, so the
    // src rect is just my screen-space rect, scaled by image-pixel /
    // logical-pixel for the height/width of the bake.
    final scaleX = _image.width / _bakedSize.width;
    final scaleY = _image.height / _bakedSize.height;
    final src = Rect.fromLTWH(
      screenPos.dx * scaleX,
      screenPos.dy * scaleY,
      size.width * scaleX,
      size.height * scaleY,
    );
    final dst = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width,
      size.height,
    );

    // `filterQuality: medium` so the GPU bilinearly samples the bake when
    // the bake's pixel ratio doesn't exactly match the device's.
    context.canvas.drawImageRect(
      _image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}
