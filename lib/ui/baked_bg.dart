import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pre-rendered, full-pipeline copy of the active glitter background —
/// cover-fit to a *scaled* viewport (so per-tile strips can sample any
/// parallax position without running out of pixels at the edges),
/// saturation matrix applied, Gaussian blur baked in. Lives as a single
/// `ui.Image` so per-line strips can render cheap `drawImageRect` slices
/// instead of hosting a live `BackdropFilter`.
///
/// The bake is per-`(brightness, viewport size)` — re-bakes when the
/// theme flips or the screen rotates. Re-bake cost on a typical phone
/// is small (a few ms on a Pixel 6 per the deep-research benchmark) and
/// happens off the raster thread.
@immutable
class BakedBg {
  const BakedBg({
    required this.image,
    required this.viewportSize,
    required this.scaleFactor,
    required this.pixelRatio,
  });

  /// The baked frame.
  final ui.Image image;

  /// Logical viewport this bake covers — same as `MediaQuery.sizeOf`
  /// at the time of bake.
  final Size viewportSize;

  /// Parallax oversize factor. The live bg layer applies
  /// `Transform(Matrix4.diagonal3Values(scaleFactor.width, scaleFactor.height, 1))`
  /// for parallax slack on both axes; the bake is rendered at the
  /// matching scaled size so strips can sample any alignment.
  final Size scaleFactor;

  /// Pixel-ratio applied to the bake to keep RAM down. The bake is at
  /// `(viewportSize * scaleFactor * pixelRatio)` physical pixels;
  /// `drawImageRect` upscales bilinearly at composite time. Blur sigma
  /// is scaled by the same factor so the on-screen blur intensity
  /// stays at the configured `_effectiveBlurSigma`.
  final double pixelRatio;

  void dispose() {
    image.dispose();
  }
}

/// Saturation matrix used by the live bg layer's `DecorationImage`
/// (`s = 1.3` Rec. 709). Re-applied here so the bake matches the live
/// bg pixel-for-pixel in tone — strips composite seamlessly into the
/// surrounding sharp bg.
const ColorFilter _saturationFilter = ColorFilter.matrix(<double>[
  1.23622, -0.21456, -0.02166, 0, 0,
  -0.06378, 1.08544, -0.02166, 0, 0,
  -0.06378, -0.21456, 1.27834, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Effective Gaussian blur sigma the strips render with, in *logical*
/// screen pixels. Same value the prior `BackdropFilter` chain used.
const double _effectiveBlurSigma = 8;

/// Parallax oversize factor — must match the Transform applied to the
/// live bg layer in `home_page.dart` so the bake covers exactly the
/// same scaled-image region the live bg renders.
const Size _parallaxScale = Size(1.48, 1.39);

/// Reduce the bake's pixel resolution to keep `ui.Image` memory in
/// check. The content is heavily blurred; bilinear upscale during
/// `drawImageRect` is visually indistinguishable from a full-res bake.
const double _bakePixelRatio = 0.5;

Future<BakedBg> _bake({
  required AssetBundle bundle,
  required String assetPath,
  required Size viewportSize,
}) async {
  final scaledLogicalSize = Size(
    viewportSize.width * _parallaxScale.width,
    viewportSize.height * _parallaxScale.height,
  );
  final bakedPixelSize = Size(
    scaledLogicalSize.width * _bakePixelRatio,
    scaledLogicalSize.height * _bakePixelRatio,
  );
  final bakedSigma = _effectiveBlurSigma * _bakePixelRatio;

  final byteData = await bundle.load(assetPath);
  final codec =
      await ui.instantiateImageCodec(byteData.buffer.asUint8List());
  final ui.Image source;
  try {
    final frame = await codec.getNextFrame();
    source = frame.image;
  } finally {
    // Native decoder resources accumulate across re-bakes (theme flip,
    // rotation, viewport resize) if we don't dispose the codec — only
    // one frame per bake, no further use after this point.
    codec.dispose();
  }

  try {
    // Cover-fit src rect on the source image so the bake's aspect
    // matches the live bg.
    final srcAspect = source.width / source.height;
    final dstAspect = scaledLogicalSize.width / scaledLogicalSize.height;
    final Rect srcRect;
    if (srcAspect > dstAspect) {
      final keepWidth = source.height * dstAspect;
      final cropX = (source.width - keepWidth) / 2;
      srcRect =
          Rect.fromLTWH(cropX, 0, keepWidth, source.height.toDouble());
    } else {
      final keepHeight = source.width / dstAspect;
      final cropY = (source.height - keepHeight) / 2;
      srcRect =
          Rect.fromLTWH(0, cropY, source.width.toDouble(), keepHeight);
    }
    final dstRect =
        Rect.fromLTWH(0, 0, bakedPixelSize.width, bakedPixelSize.height);

    // Render through saveLayers so source pixels are colored by the
    // saturation matrix first and then convolved by the blur kernel —
    // matching the order the live BackdropFilter chain composited
    // (saturation on the DecorationImage, blur over).
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, dstRect);
    canvas.saveLayer(
      dstRect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: bakedSigma,
          sigmaY: bakedSigma,
          tileMode: TileMode.decal,
        ),
    );
    canvas.saveLayer(
      dstRect,
      Paint()..colorFilter = _saturationFilter,
    );
    canvas.drawImageRect(source, srcRect, dstRect, Paint());
    canvas.restore();
    canvas.restore();
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        bakedPixelSize.width.ceil(),
        bakedPixelSize.height.ceil(),
      );
      return BakedBg(
        image: image,
        viewportSize: viewportSize,
        scaleFactor: _parallaxScale,
        pixelRatio: _bakePixelRatio,
      );
    } finally {
      picture.dispose();
    }
  } finally {
    source.dispose();
  }
}

/// Composite key for the bake cache. A new viewport size or brightness
/// triggers a fresh bake.
@immutable
class BakedBgKey {
  const BakedBgKey({required this.brightness, required this.size});

  final Brightness brightness;
  final Size size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BakedBgKey &&
          brightness == other.brightness &&
          size == other.size;

  @override
  int get hashCode => Object.hash(brightness, size);
}

String _assetFor(Brightness b) =>
    b == Brightness.dark
        ? 'assets/images/bg_dark.png'
        : 'assets/images/bg_light.png';

final bakedBgProvider =
    FutureProvider.autoDispose.family<BakedBg, BakedBgKey>((ref, key) async {
  // Register dispose BEFORE awaiting. If the provider's autoDispose
  // fires while `_bake` is still in flight (theme flip / rotation /
  // keyboard show changing the BakedBgKey), Riverpod doesn't cancel
  // the pending Future — `_bake` resolves later and would orphan the
  // ui.Image's GPU memory if we registered the disposer afterwards.
  // The holder closes over the eventual result so the same callback
  // works whether dispose fires before or after the bake settles.
  //
  // Defer the actual `image.dispose()` to a post-frame callback. When
  // the brightness/viewport key changes, the new `BakedBg` lands in
  // every PerLineBackdropBlur via `ref.watch` in the same frame's
  // build phase, but the engine may still hold a paint job that
  // references the OLD `ui.Image` (e.g. a deferred raster from before
  // the rebuild). Synchronous disposal mid-frame can race that and
  // raise "Image has been disposed" in paint. Deferring by one frame
  // gives every active render object a chance to pick up the new
  // image before the old one's native handle is freed.
  BakedBg? baked;
  ref.onDispose(() {
    final pending = baked;
    if (pending == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pending.dispose();
    });
  });
  baked = await _bake(
    bundle: rootBundle,
    assetPath: _assetFor(key.brightness),
    viewportSize: key.size,
  );
  return baked;
});

/// Live parallax state pushed down from `HomePage` so per-line strips
/// can compute the correct slice of the bake (`alignment`) and know
/// when to repaint (`listenable`).
@immutable
class BgParallax {
  const BgParallax({
    required this.listenable,
    required this.alignment,
  });

  /// Notifies whenever any input that affects the strip's `srcRect`
  /// changes — combined `PageController` + vertical-scroll listenables
  /// in HomePage. Subscribed by `_RenderPreBakedBackdrop` to call
  /// `markNeedsPaint`, so caches don't go stale during scroll.
  final Listenable listenable;

  /// Current parallax alignment of the live bg. Same value the bg
  /// layer's `Transform(Matrix4.diagonal3Values(...), alignment: ...)`
  /// uses, so strips sample exactly the slice the surrounding sharp
  /// bg displays.
  final Alignment alignment;
}

class BgParallaxScope extends InheritedWidget {
  const BgParallaxScope({
    super.key,
    required this.parallax,
    required super.child,
  });

  final BgParallax parallax;

  static BgParallax? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BgParallaxScope>()?.parallax;

  @override
  bool updateShouldNotify(BgParallaxScope old) =>
      parallax.listenable != old.parallax.listenable ||
      parallax.alignment != old.parallax.alignment;
}
