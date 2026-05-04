import 'dart:ui' as ui;

import 'package:flutter/material.dart' show ThemeData;
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
///
/// While [baked] is null (the bake's first-frame loading window — PNG
/// decode + saturation + blur + `picture.toImage` readback all run on
/// the root isolate and the per-line strips would otherwise pop in
/// late), this paints a flat [fallbackColor] through the same feather
/// mask. The silhouette matches the eventual bake's silhouette, so the
/// flat→glittery swap-in stays in place rather than emerging from
/// nothing.
class PreBakedBackdrop extends StatelessWidget {
  const PreBakedBackdrop({
    super.key,
    required this.baked,
    required this.fallbackColor,
  });

  final BakedBg? baked;

  /// Painted as a flat slab through the feather mask whenever [baked] is
  /// null. Call sites pass a theme-derived translucent surface tint so
  /// the slab reads as plausible frosting until the real bake lands.
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final parallax = BgParallaxScope.maybeOf(context);
    return _PreBakedBackdropRender(
      baked: baked,
      fallbackColor: fallbackColor,
      // No need to repaint the flat fallback on parallax ticks — it
      // doesn't sample the bake. Listener only attached once the real
      // bake arrives.
      listenable: baked == null ? null : parallax?.listenable,
      alignment: parallax?.alignment ?? Alignment.center,
    );
  }
}

class _PreBakedBackdropRender extends LeafRenderObjectWidget {
  const _PreBakedBackdropRender({
    required this.baked,
    required this.fallbackColor,
    required this.listenable,
    required this.alignment,
  });

  final BakedBg? baked;
  final Color fallbackColor;
  final Listenable? listenable;
  final Alignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPreBakedBackdrop(
      baked: baked,
      fallbackColor: fallbackColor,
      listenable: listenable,
      alignment: alignment,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPreBakedBackdrop)
      ..baked = baked
      ..fallbackColor = fallbackColor
      ..listenable = listenable
      ..alignment = alignment;
  }
}

class _RenderPreBakedBackdrop extends RenderBox {
  _RenderPreBakedBackdrop({
    required BakedBg? baked,
    required Color fallbackColor,
    required Listenable? listenable,
    required Alignment alignment,
  })  : _baked = baked,
        _fallbackColor = fallbackColor,
        _listenable = listenable,
        _alignment = alignment;

  BakedBg? _baked;
  set baked(BakedBg? value) {
    if (identical(value, _baked)) return;
    _baked = value;
    markNeedsPaint();
  }

  Color _fallbackColor;
  set fallbackColor(Color value) {
    if (value == _fallbackColor) return;
    _fallbackColor = value;
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

    final dst = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width,
      size.height,
    );

    // Save a layer so the radial alpha mask below composites against
    // the freshly-drawn image only — not against whatever was painted
    // into the parent canvas before us.
    context.canvas.saveLayer(dst, Paint());

    final baked = _baked;
    if (baked == null) {
      // Pre-bake fallback: flat translucent fill through the same
      // feather mask the bake uses, so the silhouette is identical and
      // the swap-in (flat → glittery) doesn't shift any pixel outside
      // the slab area.
      context.canvas.drawRect(dst, Paint()..color = _fallbackColor);
      _drawFeatherMask(context.canvas, dst);
      context.canvas.restore();
      return;
    }

    // Where am I on screen, in logical pixels?
    final screenPos = localToGlobal(Offset.zero);

    final viewport = baked.viewportSize;
    final scale = baked.scaleFactor;

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
    final ratio = baked.pixelRatio;
    final src = Rect.fromLTWH(
      logicalSrcLeft * ratio,
      logicalSrcTop * ratio,
      size.width * ratio,
      size.height * ratio,
    );

    context.canvas.drawImageRect(
      baked.image,
      src,
      dst,
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
    _drawFeatherMask(context.canvas, dst);
    context.canvas.restore();
  }

  // Vertical linear alpha feather: transparent at top, opaque through
  // the middle band, transparent at bottom. BlendMode.dstIn keeps the
  // freshly-drawn pixels (bake slice or fallback color) only where this
  // gradient has alpha — top and bottom edges fade to the unblurred
  // live bg behind us, while the line itself sits in a fully-opaque
  // band.
  void _drawFeatherMask(ui.Canvas canvas, Rect dst) {
    final maskPaint = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = ui.Gradient.linear(
        Offset(dst.center.dx, dst.top),
        Offset(dst.center.dx, dst.bottom),
        const [
          Color(0x00000000),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x00000000),
        ],
        const [
          0.0,
          _featherFraction,
          1.0 - _featherFraction,
          1.0,
        ],
      );
    canvas.drawRect(dst, maskPaint);
  }
}

/// Vertical feather size as a fraction of the strip's height — the
/// gradient fades in from 0 to 1 over the top `_featherFraction` of the
/// strip and back to 0 over the bottom `_featherFraction`. Higher → wider
/// fade band, narrower fully-blurred middle.
const double _featherFraction = 0.25;

/// Theme-derived flat color used by [PreBakedBackdrop] before the bake
/// settles. Picked to read as plausible frosting against either glittery
/// bg — light mode lands on a milky pinkish tone (the bake's average
/// after saturation × scale × lift); dark mode lands on a translucent
/// purple-magenta tone. Both are slightly translucent so the live sharp
/// bg shows through and the swap-in to the real bake stays in place
/// instead of flashing.
Color preBakedBackdropFallback(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0x99362442) // ~purple-magenta @ 60%
      : const Color(0x99F0CFD8); // ~milky pink @ 60%
}
