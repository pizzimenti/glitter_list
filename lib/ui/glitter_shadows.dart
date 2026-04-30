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

  // 10 stacked shadows of sigma = 140 px, each at 60% surface alpha.
  // Bumps both count (8 → 10) and per-shadow alpha (0.5 → 0.6) for a
  // denser, more obviously shadowy cloud while keeping the wide reach
  // (σ stays at 140 px).
  //
  //     d (px) | per-shadow → cumulative over 10
  //     -------|--------------------------------
  //        0   |  ~0.30  →  ~97%
  //       20   |  ~0.27  →  ~95%
  //       50   |  ~0.22  →  ~91%
  //      100   |  ~0.14  →  ~78%
  //      150   |  ~0.09  →  ~59%
  //      200   |  ~0.05  →  ~37%
  static List<Shadow> aroundText(Color surface) => List.filled(
        10,
        Shadow(color: surface.withValues(alpha: 0.6), blurRadius: 140),
      );
}
