import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

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

/// Color filter applied to the bg image. Public because the live bg
/// layer in `home_page.dart` and the bake here MUST apply the
/// identical filter; otherwise per-line frosted strips composite
/// tonally off vs. the surrounding sharp bg.
///
/// **Dark mode** keeps the poppy `s=1.3` Rec. 709 saturation boost —
/// the deep purple `bg_dark.png` reads richer with the high-end
/// amplification, and the limited dynamic range of dark pinks rarely
/// pushes any channel near 255. Pure-channel theoretical inputs (eg.
/// `R=255,G=B=0`) would clip to white, but that combination doesn't
/// occur in `bg_dark.png`.
///
/// **Light mode** uses a modest `s=1.1` saturation boost composed
/// with a 0.72 scale + 68 lift. The off-diagonals preserve the
/// channel-vs-channel contrast that the per-line frosted strips read
/// as "diffusion" — a flat brightness-only matrix flattened the bg
/// enough that the blurred strip became visually identical to the
/// surrounding sharp bg, killing the frosted-glass effect. The
/// scale/lift combo keeps every realistic bg pixel under 255 (white
/// `0.72·255 + 68 ≈ 252`; brightest pinkish glitter ≈ 255) while
/// lifting mid-tones to ~160 (vs ~150 original) and shadows from
/// ~72 → ~104 — a noticeable brightening across the histogram.
/// Pure red (R=255, G=B=0) theoretically clips at ~262 but the
/// pink bg asset doesn't contain that combination.
const ColorFilter _bgSaturationDark = ColorFilter.matrix(<double>[
  1.23622, -0.21456, -0.02166, 0, 0,
  -0.06378, 1.08544, -0.02166, 0, 0,
  -0.06378, -0.21456, 1.27834, 0, 0,
  0, 0, 0, 1, 0,
]);

// s=1.1 saturation matrix scaled by 0.72, with +68 lift. Composing
// these linearly (each coefficient = scale × s_coef) keeps it a
// single matrix-pass — the bake and live bg layer apply identical
// math.
const ColorFilter _bgSaturationLight = ColorFilter.matrix(<double>[
  0.77666, -0.05148, -0.00518, 0, 68,
  -0.01531, 0.74051, -0.00518, 0, 68,
  -0.01531, -0.05148, 0.78680, 0, 68,
  0, 0, 0, 1, 0,
]);

ColorFilter bgSaturationFilterFor(Brightness b) =>
    b == Brightness.dark ? _bgSaturationDark : _bgSaturationLight;

/// Effective Gaussian blur sigma the strips render with, in *logical*
/// screen pixels. Same value the prior `BackdropFilter` chain used.
const double _effectiveBlurSigma = 8;

/// Parallax oversize factor — the live bg layer wraps its
/// `DecorationImage` in
/// `Transform(Matrix4.diagonal3Values(width, height, 1), alignment:
/// alignment, ...)` and the bake renders at the matching scaled
/// size so strips can sample any alignment. Public so both paint
/// paths read the same numbers; if these drift, strip sampling
/// will diverge from the live bg.
const Size bgParallaxScale = Size(1.48, 1.39);

/// Reduce the bake's pixel resolution to keep `ui.Image` memory in
/// check AND shorten the first-bake window the user waits through at
/// app startup. The content is heavily blurred; bilinear upscale
/// during `drawImageRect` is visually indistinguishable from a full-
/// res bake. Bake sigma scales with this ratio (`_effectiveBlurSigma
/// * _bakePixelRatio`) so the blur in screen space stays the same.
const double _bakePixelRatio = 0.35;

Future<BakedBg> _bake({
  required AssetBundle bundle,
  required String assetPath,
  required Size viewportSize,
  required Brightness brightness,
}) async {
  final scaledLogicalSize = Size(
    viewportSize.width * bgParallaxScale.width,
    viewportSize.height * bgParallaxScale.height,
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
      Paint()..colorFilter = bgSaturationFilterFor(brightness),
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
        scaleFactor: bgParallaxScale,
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
    brightness: key.brightness,
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

/// Hosts the parallax state (`PageController`, vertical-scroll progress,
/// merged listenable) and publishes [BgParallaxScope] above
/// [MaterialApp]. Sits inside `GlitterListApp.build` so the scope is
/// reachable from every `OverlayEntry` (`showDialog`, `PopupMenuButton`,
/// `ReorderableListView`'s drag proxy) — those reparent into Navigator's
/// root Overlay, which is below this host.
///
/// Two scopes are published below the host:
/// - [BgParallaxScope] — read-only `listenable` + `alignment` for any
///   widget that paints frosted strips (overlay-routed or otherwise).
/// - [BgParallaxControls] — the live `PageController` + vertical-scroll
///   `ValueNotifier<double>` that `HomePage` wires into `PageView` and
///   the `NotificationListener`.
class BgParallaxHost extends ConsumerStatefulWidget {
  const BgParallaxHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BgParallaxHost> createState() => _BgParallaxHostState();
}

class _BgParallaxHostState extends ConsumerState<BgParallaxHost> {
  late final PageController _controller;
  // Background's vertical pan, mapped from the active list's scroll
  // offset into [-1, +1]. Drives `Alignment(_, y)` on the bg image so
  // glitter pans down as the list scrolls down. Starts at -1 (top of
  // image, matching an unscrolled list).
  final ValueNotifier<double> _verticalT = ValueNotifier(-1);
  late final Listenable _bgListenable;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: ref.read(appStateProvider).currentListIndex,
    );
    _bgListenable = Listenable.merge([_controller, _verticalT]);
  }

  @override
  void dispose() {
    _verticalT.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppState>(appStateProvider, (prev, next) {
      if (!_controller.hasClients) return;
      final page = _controller.page?.round();
      if (page != next.currentListIndex &&
          next.currentListIndex < next.lists.length) {
        _controller.animateToPage(
          next.currentListIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });

    final state = ref.watch(appStateProvider);

    return AnimatedBuilder(
      animation: _bgListenable,
      builder: (context, child) {
        final maxIndex = state.lists.length - 1;
        double alignmentX = 0;
        if (maxIndex > 0) {
          // Before the controller has clients (first frame) `page` throws,
          // so fall back to the initial index until the PageView attaches.
          final page = _controller.hasClients
              ? (_controller.page ?? state.currentListIndex.toDouble())
              : state.currentListIndex.toDouble();
          alignmentX = ((page / maxIndex) * 2 - 1).clamp(-1.0, 1.0);
        }
        final alignment = Alignment(alignmentX, _verticalT.value);
        return BgParallaxScope(
          parallax: BgParallax(
            listenable: _bgListenable,
            alignment: alignment,
          ),
          child: child!,
        );
      },
      child: BgParallaxControls(
        controller: _controller,
        verticalT: _verticalT,
        bgListenable: _bgListenable,
        child: widget.child,
      ),
    );
  }
}

/// Exposes the live [PageController], vertical-scroll [ValueNotifier],
/// and merged repaint listenable owned by [BgParallaxHost] to
/// `HomePage`'s `PageView`, `NotificationListener`, and bg-layer
/// `AnimatedBuilder`. All three references are stable for the host's
/// lifetime, so [updateShouldNotify] returns false and dependents do
/// not rebuild on every parallax tick — `HomePage`'s expensive
/// [TextPainter] title measurement only re-runs on real state changes.
class BgParallaxControls extends InheritedWidget {
  const BgParallaxControls({
    super.key,
    required this.controller,
    required this.verticalT,
    required this.bgListenable,
    required super.child,
  });

  final PageController controller;
  final ValueNotifier<double> verticalT;
  final Listenable bgListenable;

  static BgParallaxControls of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BgParallaxControls>();
    assert(scope != null,
        'BgParallaxControls.of called above the BgParallaxHost.');
    return scope!;
  }

  @override
  bool updateShouldNotify(BgParallaxControls old) =>
      !identical(controller, old.controller) ||
      !identical(verticalT, old.verticalT) ||
      !identical(bgListenable, old.bgListenable);
}
