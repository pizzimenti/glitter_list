import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'baked_bg.dart';
import 'pre_baked_backdrop.dart';

/// Renders [text] with a Gaussian-blur frosted strip behind **each
/// individual line**, tight to that line's actual content width — empty
/// space at the end of a wrapped line is left raw, not frosted.
///
/// Lays out a `TextPainter` once at the available constraint, pulls per-
/// line metrics, and emits a `Stack` of `Positioned` `ClipRRect →
/// PreBakedBackdrop → Text` strips, one per line. The outer size matches
/// `tp.size`, so callers that wrap this in a `CustomPaint` (notably
/// `RainbowStrikethrough`) get the same paint surface they'd have gotten
/// from a plain `Text` widget — the strikethrough painter's own
/// `TextPainter` will compute matching line metrics off the same
/// `(text, style, maxWidth)`.
///
/// Each strip's "blur" is a slice of a single pre-baked, pre-blurred
/// `ui.Image` of the bg ([BakedBg]) sampled at the strip's current
/// screen position via `canvas.drawImageRect` — no live `BackdropFilter`,
/// so the engine re-rasterization race that produced vertical-scroll
/// tearing on grouped filters can't fire here.
class PerLineBackdropBlur extends ConsumerWidget {
  const PerLineBackdropBlur({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.backdropOutset = EdgeInsets.zero,
    this.betweenLayerBuilder,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final bool softWrap;
  final TextOverflow overflow;
  final BorderRadius borderRadius;

  /// Extends each per-line frosted strip past the line's text bounds
  /// — used for glittered rows so the squiggle has a clean substrate
  /// to draw against instead of pressing right up to the glyphs. The
  /// inner text stays at its original position.
  final EdgeInsets backdropOutset;

  /// Builder for an optional widget rendered BETWEEN the slabs and
  /// the text. Receives the OUTER TextPainter's already-computed line
  /// metrics + content size so the between-layer can render against
  /// the SAME line breaks as the strips. A naive `Widget` would
  /// re-layout its own TextPainter at the inner Stack's tighter
  /// `constraints.maxWidth` (= `tp.size.width`, narrower than the
  /// outer's `layoutMaxWidth`) and could pick different break points
  /// — when the second-or-later line is the widest, the squiggle
  /// then wraps a different polygon than what's behind it.
  final Widget Function(List<LineMetrics> lines, Size size)?
  betweenLayerBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read brightness from the resolved Theme rather than
    // `MediaQuery.platformBrightness`. MaterialApp.themeMode
    // (set by the user's hamburger override) is what flips
    // light↔dark for the rest of the app's theme; the bake
    // must follow the same signal so a `ThemeMode.dark` override
    // on a system-light device picks `bg_dark.png` instead of
    // staying on the light asset.
    final brightness = Theme.of(context).brightness;
    final viewportSize = MediaQuery.sizeOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final bakedAsync = ref.watch(
      bakedBgProvider(
        BakedBgKey(brightness: brightness, size: viewportSize),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useEllipsis = overflow == TextOverflow.ellipsis;
        final layoutMaxWidth =
            softWrap ? constraints.maxWidth : double.infinity;

        // Pass textScaler so per-line metrics match what the rendered
        // Text widgets will lay out at — they inherit the ambient
        // textScaler from MediaQuery, so without this our outer
        // SizedBox + per-line Positioned strips would be sized to
        // unscaled metrics while the glyphs render larger under
        // accessibility scaling, clipping the bottom and missing the
        // right edge.
        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: maxLines,
          ellipsis: useEllipsis ? '…' : null,
        )..layout(maxWidth: layoutMaxWidth);

        final metrics = tp.computeLineMetrics();
        final size = tp.size;
        final lines = <_Line>[];
        for (var i = 0; i < metrics.length; i++) {
          final m = metrics[i];
          // Sample one logical pixel inside the line; getLineBoundary
          // maps it back to a TextRange in the source string.
          final pos =
              tp.getPositionForOffset(Offset(m.left + 1, m.baseline));
          final range = tp.getLineBoundary(pos);
          var lineText = text.substring(range.start, range.end).trimRight();
          if (i == metrics.length - 1 &&
              useEllipsis &&
              tp.didExceedMaxLines) {
            // The outer painter applied an ellipsis to the last visible
            // line. getLineBoundary's range is in the original string,
            // so reproduce the ellipsis on our extracted substring.
            lineText = '$lineText…';
          }
          lines.add(_Line(lineText, m));
        }
        tp.dispose();

        final baked = bakedAsync.value;

        return SizedBox(
          width: size.width,
          height: size.height,
          // Glittered rows pass a non-zero `backdropOutset`; the wider
          // strip extends past the line's text bounds, so the parent
          // Stack must not clip. The three logical layers — slab,
          // optional between-layer (glitter squiggle), text — are
          // drawn as separate children so a sibling at higher z (e.g.
          // squiggle outline) can paint over slabs but still below
          // the glyphs that would otherwise be obscured by it.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (baked != null)
                for (final line in lines)
                  Positioned(
                    left: line.metrics.left - backdropOutset.left,
                    top: line.metrics.baseline -
                        line.metrics.ascent -
                        backdropOutset.top,
                    width:
                        line.metrics.width + backdropOutset.horizontal,
                    height:
                        line.metrics.height + backdropOutset.vertical,
                    child: ClipRRect(
                      borderRadius: borderRadius,
                      child: PreBakedBackdrop(baked: baked),
                    ),
                  ),
              if (betweenLayerBuilder != null)
                Positioned.fill(
                  child: betweenLayerBuilder!(
                    metrics,
                    size,
                  ),
                ),
              for (final line in lines)
                Positioned(
                  left: line.metrics.left,
                  top: line.metrics.baseline - line.metrics.ascent,
                  child: _lineWidget(line.text),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _lineWidget(String lineText) => Text(
        lineText,
        style: style,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
      );
}

class _Line {
  const _Line(this.text, this.metrics);
  final String text;
  final LineMetrics metrics;
}
