import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'glitter_colors.dart';

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
  });

  final String text;
  final TextStyle baseStyle;
  final Color mutedColor;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (_, _) {
        final t = progress.value.clamp(0.0, 1.0);
        final textColor =
            Color.lerp(baseStyle.color, mutedColor, t) ?? baseStyle.color;
        final styled = baseStyle.copyWith(color: textColor);
        return CustomPaint(
          foregroundPainter: _StrikethroughPainter(
            progress: t,
            text: text,
            style: styled,
          ),
          child: Text(text, style: styled),
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
  });

  final double progress;
  final String text;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: size.width);

    final strokeWidth = (style.fontSize ?? 16) * 0.1;
    final paintBase = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const gradient = LinearGradient(colors: _rainbow);

    // Draw one rainbow segment per laid-out line so wrapped text gets a
    // strikethrough on every line, vertically centered on that line.
    final lines = tp.computeLineMetrics();
    for (final line in lines) {
      final lineWidth = line.width;
      if (lineWidth <= 0) continue;
      final y = line.baseline - line.ascent + line.height / 2;
      final endX = lineWidth * progress;
      paintBase.shader = gradient.createShader(
        Rect.fromLTWH(0, y - strokeWidth / 2, lineWidth, strokeWidth),
      );
      canvas.drawLine(Offset(0, y), Offset(endX, y), paintBase);
    }

    tp.dispose();
  }

  @override
  bool shouldRepaint(_StrikethroughPainter old) =>
      old.progress != progress || old.text != text || old.style != style;
}

/// Wraps a [Checkbox] and paints a bell-curved glow around it during the
/// 1s animation window.
class GlowingCheckbox extends StatelessWidget {
  const GlowingCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.progress,
    required this.glowColor,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final Animation<double> progress;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    final checkbox = Checkbox(
      value: value,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: onChanged,
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
