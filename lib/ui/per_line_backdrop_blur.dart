import 'dart:ui' show ImageFilter, LineMetrics, TileMode;

import 'package:flutter/widgets.dart';

/// Renders [text] with a Gaussian-blur frosted strip behind **each
/// individual line**, tight to that line's actual content width — empty
/// space at the end of a wrapped line is left raw, not frosted.
///
/// Internally lays out a `TextPainter` once at the available constraint
/// width, pulls per-line metrics, and emits a `Stack` of `Positioned`
/// `ClipRRect → BackdropFilter → Text` strips, one per line. The
/// outer size matches `tp.size`, so callers that wrap this in a
/// `CustomPaint` (notably `RainbowStrikethrough`) get the same paint
/// surface they'd have gotten from a plain `Text` widget — the
/// strikethrough painter's own `TextPainter` will compute matching
/// line metrics off the same `(text, style, maxWidth)`.
///
/// Set [grouped] when an ancestor `BackdropGroup` is present — N
/// grouped filters share one backdrop snapshot per frame, which is
/// what eliminates the vertical-scroll re-rasterization tearing the
/// plain `BackdropFilter` shows inside scrollables.
class PerLineBackdropBlur extends StatelessWidget {
  const PerLineBackdropBlur({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.sigma = 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.grouped = false,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final bool softWrap;
  final TextOverflow overflow;
  final double sigma;
  final BorderRadius borderRadius;

  /// When true, emits `BackdropFilter.grouped` so the per-line filters
  /// share one backdrop snapshot via an ancestor `BackdropGroup`. When
  /// false, emits plain `BackdropFilter` — for non-scrollable contexts
  /// like the AppBar where there's no group to join.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useEllipsis = overflow == TextOverflow.ellipsis;
        final layoutMaxWidth =
            softWrap ? constraints.maxWidth : double.infinity;

        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
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

        final filter = ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        );

        return SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              for (final line in lines)
                Positioned(
                  left: line.metrics.left,
                  top: line.metrics.baseline - line.metrics.ascent,
                  width: line.metrics.width,
                  height: line.metrics.height,
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: grouped
                        ? BackdropFilter.grouped(
                            filter: filter,
                            child: _lineWidget(line.text),
                          )
                        : BackdropFilter(
                            filter: filter,
                            child: _lineWidget(line.text),
                          ),
                  ),
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
