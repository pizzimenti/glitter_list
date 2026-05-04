import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'baked_bg.dart';
import 'glitter_colors.dart';
import 'per_line_backdrop_blur.dart';
import 'pre_baked_backdrop.dart';

const _rainbow = <Color>[
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF5AC8FA),
  Color(0xFF007AFF),
  Color(0xFFAF52DE),
];

/// Rainbow strikethrough that draws from left to right as `progress` goes 0→1.
/// The underlying text's color crossfades from [baseStyle.color] to
/// [mutedColor] over the same progress range.
class RainbowStrikethrough extends StatelessWidget {
  const RainbowStrikethrough({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.mutedColor,
    required this.progress,
    this.backdropOutset = EdgeInsets.zero,
    this.betweenLayerBuilder,
  });

  final String text;
  final TextStyle baseStyle;
  final Color mutedColor;
  final Animation<double> progress;
  final EdgeInsets backdropOutset;
  final Widget Function(List<LineMetrics> lines, Size size)?
  betweenLayerBuilder;

  @override
  Widget build(BuildContext context) {
    // Merge the ambient DefaultTextStyle (fontFamily, height, etc. from
    // the Theme) into baseStyle so the painter's TextPainter and the
    // rendered Text compute line metrics against identical typography.
    // Otherwise the painter falls back to the platform default font and
    // its lines/baselines diverge from what the Text actually draws.
    final resolved = DefaultTextStyle.of(context).style.merge(baseStyle);
    final textScaler = MediaQuery.textScalerOf(context);
    return AnimatedBuilder(
      animation: progress,
      builder: (_, _) {
        final t = progress.value.clamp(0.0, 1.0);
        final textColor =
            Color.lerp(resolved.color, mutedColor, t) ?? resolved.color;
        final styled = resolved.copyWith(color: textColor);
        // Per-line frosted blur sits inside the CustomPaint as the
        // child. PerLineBackdropBlur sizes to the same `tp.size` a plain
        // Text(text, style: styled) would produce, so the foreground
        // painter's own TextPainter computes matching line metrics off
        // the same (text, style, maxWidth, textScaler) and the rainbow
        // strikes still align to baselines. The strips themselves now
        // sample a pre-baked, pre-blurred bg image (sliced via
        // canvas.drawImageRect) rather than running a live
        // BackdropFilter, so vertical scroll doesn't tear them anymore.
        return CustomPaint(
          foregroundPainter: _StrikethroughPainter(
            progress: t,
            text: text,
            style: styled,
            textScaler: textScaler,
          ),
          child: PerLineBackdropBlur(
            text: text,
            style: styled,
            backdropOutset: backdropOutset,
            betweenLayerBuilder: betweenLayerBuilder,
          ),
        );
      },
    );
  }
}

class _StrikethroughPainter extends CustomPainter {
  _StrikethroughPainter({
    required this.progress,
    required this.text,
    required this.style,
    required this.textScaler,
  });

  final double progress;
  final String text;
  final TextStyle style;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: null,
    )..layout(maxWidth: size.width);

    final strokeWidth = (style.fontSize ?? 16) * 0.07;
    final paintBase = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const gradient = LinearGradient(colors: _rainbow);

    // One rainbow segment per laid-out line. Progress is split equally
    // across lines so they draw sequentially rather than in parallel —
    // line i goes from t=i/N to t=(i+1)/N of the overall animation.
    // The gradient spans the TOTAL text width (sum of line widths) so
    // color cycles through once across the whole item; each line uses a
    // shader offset by its cumulative start so the rainbow continues
    // seamlessly from one line to the next.
    final lines = tp.computeLineMetrics();
    final n = lines.length;
    if (n == 0) {
      tp.dispose();
      return;
    }
    final totalWidth =
        lines.fold<double>(0, (sum, line) => sum + line.width);
    if (totalWidth <= 0) {
      tp.dispose();
      return;
    }

    var cumulative = 0.0;
    for (var i = 0; i < n; i++) {
      final line = lines[i];
      final lineWidth = line.width;
      if (lineWidth <= 0) continue;

      final lineProgress = ((progress * n) - i).clamp(0.0, 1.0);
      if (lineProgress > 0) {
        final y = line.baseline - line.ascent + line.height / 2 + 2;
        final endX = lineWidth * lineProgress;
        paintBase.shader = gradient.createShader(
          Rect.fromLTWH(
            -cumulative,
            y - strokeWidth / 2,
            totalWidth,
            strokeWidth,
          ),
        );
        canvas.drawLine(Offset(0, y), Offset(endX, y), paintBase);
      }
      cumulative += lineWidth;
    }

    tp.dispose();
  }

  @override
  bool shouldRepaint(_StrikethroughPainter old) =>
      old.progress != progress ||
      old.text != text ||
      old.style != style ||
      old.textScaler != textScaler;
}

/// Wraps a [Checkbox] and paints a bell-curved glow around it during the
/// 1s animation window. The checkbox itself is scaled up for readability
/// and keeps a visible [borderColor] border in both checked and unchecked
/// states.
class GlowingCheckbox extends ConsumerWidget {
  const GlowingCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.progress,
    required this.glowColor,
    required this.borderColor,
    this.scale = 1.55,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final Animation<double> progress;
  final Color glowColor;
  final Color borderColor;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read from Theme so MaterialApp.themeMode (the hamburger
    // override) controls which baked bg we sample — see the matching
    // comment in PerLineBackdropBlur.
    final brightness = Theme.of(context).brightness;
    final viewportSize = MediaQuery.sizeOf(context);
    final bakedAsync = ref.watch(
      bakedBgProvider(BakedBgKey(brightness: brightness, size: viewportSize)),
    );
    final baked = bakedAsync.value;

    // M3 Checkbox paints transparent fill in unselected state; frost
    // shows through. When checked, primary fill paints over the frost.
    final frosted = baked == null
        ? const SizedBox.shrink()
        : SizedBox(
            width: 18,
            height: 18,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              child: PreBakedBackdrop(baked: baked),
            ),
          );

    final checkbox = Transform.scale(
      scale: scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          frosted,
          Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: borderColor, width: 2.5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: progress,
      builder: (_, child) {
        final t = progress.value.clamp(0.0, 1.0);
        // Bell: peaks around t=0.3 then fades. sin(π·t) peaks at 0.5; bias
        // earlier with a power so the glow feels like a "pop" not a hold.
        final bell = math.sin(math.pi * t);
        final strength = (bell * bell).clamp(0.0, 1.0);
        if (strength <= 0.001) return child!;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.75 * strength),
                blurRadius: 18 * strength,
                spreadRadius: 3 * strength,
              ),
            ],
          ),
          child: child,
        );
      },
      child: checkbox,
    );
  }
}

/// Paints N four-pointed stars emanating radially from the center of this
/// widget as `progress` goes 0→1. Motion eases out; opacity is a sin bell.
class SparkleBurst extends StatelessWidget {
  const SparkleBurst({
    super.key,
    required this.progress,
    required this.color,
    this.count = 10,
    this.maxRadius = 24,
    this.starSize = 3.5,
  });

  final Animation<double> progress;
  final Color color;
  final int count;
  final double maxRadius;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, _) => CustomPaint(
          painter: _SparklePainter(
            progress: progress.value.clamp(0.0, 1.0),
            color: color,
            count: count,
            maxRadius: maxRadius,
            starSize: starSize,
          ),
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({
    required this.progress,
    required this.color,
    required this.count,
    required this.maxRadius,
    required this.starSize,
  });

  final double progress;
  final Color color;
  final int count;
  final double maxRadius;
  final double starSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(progress);
    final radius = maxRadius * eased;
    final opacity = math.sin(math.pi * progress).clamp(0.0, 1.0);
    final paint = Paint()..color = color.withValues(alpha: opacity);

    // Stars grow slightly then shrink over the animation.
    final scale = lerpDouble(0.6, 1.0, eased) ?? 1.0;
    final effectiveStarSize = starSize * scale;

    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      final offset = Offset(
        math.cos(angle) * radius,
        math.sin(angle) * radius,
      );
      _drawStar(canvas, center + offset, effectiveStarSize, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double s, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..lineTo(c.dx + s * 0.3, c.dy - s * 0.3)
      ..lineTo(c.dx + s, c.dy)
      ..lineTo(c.dx + s * 0.3, c.dy + s * 0.3)
      ..lineTo(c.dx, c.dy + s)
      ..lineTo(c.dx - s * 0.3, c.dy + s * 0.3)
      ..lineTo(c.dx - s, c.dy)
      ..lineTo(c.dx - s * 0.3, c.dy - s * 0.3)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.count != count ||
      old.maxRadius != maxRadius ||
      old.starSize != starSize;
}

/// Convenience: the glow color for the whole family.
const Color kCheckGlow = GlitterColors.accent;
