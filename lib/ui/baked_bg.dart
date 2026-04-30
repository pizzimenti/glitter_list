import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pre-rendered, full-pipeline copy of the active glitter background —
/// cover-fit to the viewport, saturation matrix applied, Gaussian blur
/// baked in. Lives as a single `ui.Image` so per-line strips can render
/// cheap `drawImageRect` slices instead of hosting a live `BackdropFilter`
/// (which is what was getting torn during vertical scroll).
///
/// The bake is per-`(brightness, viewport size)` — re-bakes when the
/// theme flips or the screen rotates. Re-bake cost on a typical phone
/// is small (a few ms on a Pixel 6 per the deep-research benchmark) and
/// happens off the raster thread.
@immutable
class BakedBg {
  const BakedBg({required this.image, required this.size});

  /// The baked frame — saturation + Gaussian blur applied, cover-fit to
  /// [size]. Coordinates are 1:1 with the viewport: a screen rect at
  /// `(x, y, w, h)` maps directly to `Rect.fromLTWH(x, y, w, h)` in image
  /// coords.
  final ui.Image image;

  /// Logical viewport this bake covers — same as `MediaQuery.sizeOf` at
  /// the time of bake. Used by `PreBakedBackdrop` to map its world-space
  /// rect into image coords.
  final Size size;

  void dispose() {
    image.dispose();
  }
}

/// Saturation matrix used by the live bg layer's `DecorationImage`
/// (`s = 1.3` Rec. 709). Re-applied here so the bake matches the live bg
/// pixel-for-pixel in tone — strips composite seamlessly into the
/// surrounding sharp bg.
const ColorFilter _saturationFilter = ColorFilter.matrix(<double>[
  1.23622, -0.21456, -0.02166, 0, 0,
  -0.06378, 1.08544, -0.02166, 0, 0,
  -0.06378, -0.21456, 1.27834, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Gaussian blur sigma applied to the bake. Same value the prior
/// `BackdropFilter` chain used so the visual weight of the frosted
/// strips is unchanged.
const double _blurSigma = 10;

Future<BakedBg> _bake({
  required AssetBundle bundle,
  required String assetPath,
  required Size targetSize,
}) async {
  final byteData = await bundle.load(assetPath);
  final codec =
      await ui.instantiateImageCodec(byteData.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final source = frame.image;

  try {
    // Compute the cover-fit src rect on the source image so the bake's
    // aspect ratio matches the live bg (`BoxFit.cover`).
    final srcAspect = source.width / source.height;
    final dstAspect = targetSize.width / targetSize.height;
    final Rect srcRect;
    if (srcAspect > dstAspect) {
      // Source wider than viewport — crop horizontally, top-to-bottom.
      final keepWidth = source.height * dstAspect;
      final cropX = (source.width - keepWidth) / 2;
      srcRect = Rect.fromLTWH(cropX, 0, keepWidth, source.height.toDouble());
    } else {
      // Source taller than viewport — crop vertically, left-to-right.
      final keepHeight = source.width / dstAspect;
      final cropY = (source.height - keepHeight) / 2;
      srcRect = Rect.fromLTWH(0, cropY, source.width.toDouble(), keepHeight);
    }
    final dstRect = Offset.zero & targetSize;

    // Render through saveLayers so the source pixels are first colored
    // by the saturation matrix and then convolved by the blur kernel —
    // matching the order the live BackdropFilter chain composited
    // (saturation on the DecorationImage, then blur over).
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, dstRect);
    canvas.saveLayer(
      dstRect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: _blurSigma,
          sigmaY: _blurSigma,
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
        targetSize.width.ceil(),
        targetSize.height.ceil(),
      );
      return BakedBg(image: image, size: targetSize);
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

/// Resolves the bg asset path for the active brightness.
String _assetFor(Brightness b) =>
    b == Brightness.dark
        ? 'assets/images/bg_dark.png'
        : 'assets/images/bg_light.png';

/// Async-cached bake. Watchers receive `AsyncValue<BakedBg>`; the
/// underlying `ui.Image` is disposed when the family entry's last
/// listener detaches.
final bakedBgProvider =
    FutureProvider.autoDispose.family<BakedBg, BakedBgKey>((ref, key) async {
  final baked = await _bake(
    bundle: rootBundle,
    assetPath: _assetFor(key.brightness),
    targetSize: key.size,
  );
  ref.onDispose(baked.dispose);
  return baked;
});
