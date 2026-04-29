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

  // **TEMPORARY DIAGNOSTIC CONFIG** — 10 stacked shadows of sigma = 80 px
  // to confirm the cloud is rendering at all. Should hold near-100% alpha
  // out to ~50 px from each glyph, decaying past ~100 px:
  //
  //     d (px) | alpha (per-shadow → cumulative over 10)
  //     -------|----------------------------------------
  //        0   |  0.50  →  ~99.9%
  //       20   |  ~0.39 →  ~99%
  //       50   |  ~0.27 →  ~96%
  //      100   |  ~0.11 →  ~67%
  //      150   |  ~0.03 →  ~30%
  //
  // Once we confirm visibility, revert to a tighter stack like
  // [12, 5, 2, 2] for the production cloud.
  static List<Shadow> aroundText(Color surface) =>
      List.filled(10, Shadow(color: surface, blurRadius: 80));
}
