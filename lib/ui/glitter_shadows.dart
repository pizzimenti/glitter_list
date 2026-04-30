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

  // 8 stacked shadows of sigma = 140 px, each at 50% surface alpha.
  // Half-again more shadows (5 → 8) and a small alpha bump (0.4 → 0.5)
  // vs. the prior cut so the cloud reads as a real shadowy halo again
  // — keeping the wide reach (σ=140) but pushing cumulative alpha well
  // back up toward "obvious" without going all the way to opaque.
  //
  //     d (px) | per-shadow → cumulative over 8
  //     -------|-------------------------------
  //        0   |  ~0.25  →  ~90%
  //       20   |  ~0.22  →  ~86%
  //       50   |  ~0.18  →  ~80%
  //      100   |  ~0.12  →  ~64%
  //      150   |  ~0.07  →  ~45%
  //      200   |  ~0.04  →  ~27%
  static List<Shadow> aroundText(Color surface) => List.filled(
        8,
        Shadow(color: surface.withValues(alpha: 0.5), blurRadius: 140),
      );
}
