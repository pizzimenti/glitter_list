import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show PipelineOwner;
import 'package:flutter/widgets.dart';

import 'baked_bg.dart';

/// Paints a slice of the pre-baked, pre-blurred bg [BakedBg.image] at
/// this widget's current screen position via `canvas.drawImageRect`,
/// shifted by the live parallax alignment so the slice matches the
/// surrounding sharp bg layer's view.
///
/// The strip subscribes to `BgParallaxScope`'s listenable and force-
/// repaints on every notification, which avoids the `RepaintBoundary`-
/// cache staleness that otherwise pinned each strip to the screen
/// position it had at first paint (visible as "some items blurred,
/// some not" after a page swipe).
class PreBakedBackdrop extends StatelessWidget {
  const PreBakedBackdrop({super.key, required this.baked});

  final BakedBg baked;

  @override
  Widget build(BuildContext context) {
    final parallax = BgParallaxScope.maybeOf(context);
    return _PreBakedBackdropRender(
      baked: baked,
      listenable: parallax?.listenable,
      alignment: parallax?.alignment ?? Alignment.center,
    );
  }
}

class _PreBakedBackdropRender extends LeafRenderObjectWidget {
  const _PreBakedBackdropRender({
    required this.baked,
    required this.listenable,
    required this.alignment,
  });

  final BakedBg baked;
  final Listenable? listenable;
  final Alignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPreBakedBackdrop(
      baked: baked,
      listenable: listenable,
      alignment: alignment,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPreBakedBackdrop)
      ..baked = baked
      ..listenable = listenable
      ..alignment = alignment;
  }
}

class _RenderPreBakedBackdrop extends RenderBox {
  _RenderPreBakedBackdrop({
    required BakedBg baked,
    required Listenable? listenable,
    required Alignment alignment,
  })  : _baked = baked,
        _listenable = listenable,
        _alignment = alignment;

  BakedBg _baked;
  set baked(BakedBg value) {
    if (identical(value, _baked)) return;
    _baked = value;
    markNeedsPaint();
  }

  Listenable? _listenable;
  set listenable(Listenable? value) {
    if (identical(value, _listenable)) return;
    if (attached) _listenable?.removeListener(markNeedsPaint);
    _listenable = value;
    if (attached) value?.addListener(markNeedsPaint);
  }

  Alignment _alignment;
  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listenable?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _listenable?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;

    // Where am I on screen, in logical pixels?
    final screenPos = localToGlobal(Offset.zero);

    final viewport = _baked.viewportSize;
    final scale = _baked.scaleFactor;

    // Compute the strip's logical srcRect on the *scaled* image. Live
    // bg displays the scaled image with its alignment-fixed point at
    // `alignment` of both parent (screen) and scaled child; the
    // scaled child's origin sits at:
    //
    //   screenOriginX = -(αx + 1) / 2 * viewport.width  * (scaleX - 1)
    //   screenOriginY = -(αy + 1) / 2 * viewport.height * (scaleY - 1)
    //
    // For a strip at screen (sx, sy), the corresponding pixel in the
    // scaled image is (sx - originX, sy - originY) — i.e. positive
    // shift by the parallax delta on each axis.
    final ax = _alignment.x;
    final ay = _alignment.y;
    final shiftX = (ax + 1) / 2 * viewport.width * (scale.width - 1);
    final shiftY = (ay + 1) / 2 * viewport.height * (scale.height - 1);

    final logicalSrcLeft = screenPos.dx + shiftX;
    final logicalSrcTop = screenPos.dy + shiftY;

    // Convert logical coords into bake-image pixel coords.
    final ratio = _baked.pixelRatio;
    final src = Rect.fromLTWH(
      logicalSrcLeft * ratio,
      logicalSrcTop * ratio,
      size.width * ratio,
      size.height * ratio,
    );
    final dst = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width,
      size.height,
    );

    context.canvas.drawImageRect(
      _baked.image,
      src,
      dst,
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }
}
