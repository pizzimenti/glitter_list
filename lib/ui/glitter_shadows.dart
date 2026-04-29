import 'package:flutter/material.dart';

/// Per-glyph diffusion cloud — used as `TextStyle.shadows` so each
/// character carries a soft halo of the surface color, muting the busy
/// glitter background within ~10 px of any letter and leaving it raw
/// beyond ~15 px.
///
/// A single full-alpha shadow caps at ~50% local alpha at the glyph edge
/// (Gaussian-blurring a filled silhouette gives
/// `0.5 * erfc(d / (sqrt(2) * sigma))` — half the kernel sits inside the
/// glyph at d = 0). Stacking compounds via srcOver:
///
///     total_alpha(d) = 1 − Π_i (1 − alpha_i(d))
///
/// With sigmas `[12, 5, 2, 2]` px and full-alpha surface color, the
/// cumulative falloff approximates:
///
///     d (px) | alpha
///     -------|------
///        0   | ~94%
///        1   | ~85%
///        3   | ~58%
///        4   | ~48%
///       10   | ~18%
///       15   | ~7%
///      >20   | ~0%
///
/// Hits the spirit of the requested 90 / 70 / 40 / 10 profile at
/// d = 1 / 3 / 4 / 10 — single Gaussians can't fit the d=3-to-d=4 elbow
/// exactly, but the shape (sharp peak under the glyph, smooth fade to
/// nothing past ~15 px) reads as a calm cloud of surface color around
/// the text.
class GlitterShadows {
  const GlitterShadows._();

  static List<Shadow> aroundText(Color surface) => [
        Shadow(color: surface, blurRadius: 12),
        Shadow(color: surface, blurRadius: 5),
        Shadow(color: surface, blurRadius: 2),
        Shadow(color: surface, blurRadius: 2),
      ];
}
