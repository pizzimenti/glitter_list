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

  // 5 stacked shadows of sigma = 140 px, each at 40% surface alpha.
  // Halves both stack count and per-shadow alpha vs. the prior tuning
  // (10 × σ=100, α=0.8); bumps sigma another 40% so the cloud reaches
  // further out. Net: roughly half the cumulative alpha across the
  // profile, with a wider tail.
  //
  //     d (px) | per-shadow → cumulative over 5
  //     -------|-------------------------------
  //        0   |  ~0.20  →  ~67%
  //       20   |  ~0.18  →  ~62%
  //       50   |  ~0.14  →  ~54%
  //      100   |  ~0.10  →  ~39%
  //      150   |  ~0.06  →  ~26%
  //      200   |  ~0.03  →  ~15%
  static List<Shadow> aroundText(Color surface) => List.filled(
        5,
        Shadow(color: surface.withValues(alpha: 0.4), blurRadius: 140),
      );
}
