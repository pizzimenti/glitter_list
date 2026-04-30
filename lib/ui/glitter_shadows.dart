import 'package:flutter/material.dart';

/// Per-glyph diffusion cloud — used as `TextStyle.shadows` so each
/// character carries a soft halo of the surface color, muting the busy
/// glitter background near text and leaving it raw far away.
///
/// Math: a single full-alpha shadow caps at ~50% local alpha at the
/// glyph edge — Gaussian-blurring a filled silhouette gives
/// `0.5 * erfc(d / (sqrt(2) * sigma))`, so half the kernel sits inside
/// the glyph at d = 0 and only the other half fades outward. Stacking
/// compounds via srcOver:
///
///     total_alpha(d) = 1 − Π_i (1 − alpha_i(d))
class GlitterShadows {
  const GlitterShadows._();

  // 10 stacked shadows of sigma = 100 px, each at 80% surface alpha. The
  // larger sigma widens the cloud; the per-shadow alpha drop trims the
  // overall intensity ~20% so the bg shows through more.
  //
  //     d (px) | per-shadow → cumulative over 10
  //     -------|--------------------------------
  //        0   |  ~0.40  →  ~99.4%
  //       20   |  ~0.34  →  ~98%
  //       50   |  ~0.25  →  ~93%
  //      100   |  ~0.13  →  ~75%
  //      150   |  ~0.05  →  ~40%
  //      200   |  ~0.02  →  ~14%
  static List<Shadow> aroundText(Color surface) => List.filled(
        10,
        Shadow(color: surface.withValues(alpha: 0.8), blurRadius: 100),
      );
}
