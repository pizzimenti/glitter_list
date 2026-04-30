import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'glitter_colors.dart';

class GlitterOutline extends StatefulWidget {
  const GlitterOutline({
    super.key,
    required this.text,
    required this.style,
    required this.glittered,
    required this.seed,
  });

  final String text;
  final TextStyle style;
  final bool glittered;
  final int seed;

  @override
  State<GlitterOutline> createState() => _GlitterOutlineState();
}

class _GlitterOutlineState extends State<GlitterOutline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _puffing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      reverseDuration: const Duration(milliseconds: 350),
      value: widget.glittered ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(GlitterOutline old) {
    super.didUpdateWidget(old);
    if (widget.glittered != old.glittered) {
      if (widget.glittered) {
        _puffing = false;
        _ctrl.forward(from: 0);
      } else {
        _puffing = true;
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.glittered && _ctrl.value == 0) return const SizedBox.shrink();
    final textScaler = MediaQuery.textScalerOf(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tp = TextPainter(
            text: TextSpan(text: widget.text, style: widget.style),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
            maxLines: null,
          )..layout(maxWidth: constraints.maxWidth);
          final size = tp.size;
          final lines = tp.computeLineMetrics();
          tp.dispose();
          return SizedBox(
            width: size.width,
            height: size.height,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => CustomPaint(
                painter: _SquigglePainter(
                  lines: lines,
                  progress: _ctrl.value,
                  puffing: _puffing && _ctrl.status == AnimationStatus.reverse,
                  seed: widget.seed,
                  fontSize: widget.style.fontSize ?? 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter({
    required this.lines,
    required this.progress,
    required this.puffing,
    required this.seed,
    required this.fontSize,
  });

  final List<LineMetrics> lines;
  final double progress;
  final bool puffing;
  final int seed;
  final double fontSize;

  static const _colors = <Color>[
    GlitterColors.accent,
    GlitterColors.lightChrome,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty || progress <= 0) return;
    final n = lines.length;
    final strokeWidth = math.max(1.5, fontSize * 0.06);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    for (var i = 0; i < n; i++) {
      final line = lines[i];
      final lineProgress = ((progress * n) - i).clamp(0.0, 1.0);
      if (lineProgress <= 0) continue;
      final lineRect = Rect.fromLTWH(
        line.left - 4,
        line.baseline - line.ascent - 2,
        line.width + 8,
        line.height + 4,
      );
      final pts = _squigglePath(lineRect, seed ^ (i * 1009));
      final visibleCount = (pts.length * lineProgress).round();
      if (visibleCount < 2) continue;

      const segLen = 10;
      var j = 0;
      while (j < visibleCount - 1) {
        final end = math.min(j + segLen, visibleCount - 1);
        final colorIdx = (j ~/ segLen) % _colors.length;
        final color = _colors[colorIdx];
        final alpha = puffing ? progress : 1.0;
        basePaint.color = color.withValues(alpha: alpha);
        final path = Path()..moveTo(pts[j].dx, pts[j].dy);
        for (var k = j + 1; k <= end; k++) {
          path.lineTo(pts[k].dx, pts[k].dy);
        }
        canvas.drawPath(path, basePaint);
        j = end;
      }

      if (puffing) {
        final t = 1.0 - progress;
        final rng = math.Random(seed ^ (i * 5077));
        const particleCount = 10;
        final particlePaint = Paint();
        for (var k = 0; k < particleCount; k++) {
          final x0 = lineRect.left + rng.nextDouble() * lineRect.width;
          final y0 =
              lineRect.center.dy + (rng.nextDouble() - 0.5) * lineRect.height;
          final dx = (rng.nextDouble() - 0.5) * 16 * t;
          final dy = -16 * t;
          final radius = 1.5 + 2 * t;
          final pAlpha = (1.0 - t).clamp(0.0, 1.0) * 0.7;
          particlePaint.color =
              const Color(0xFFFFFFFF).withValues(alpha: pAlpha);
          canvas.drawCircle(Offset(x0 + dx, y0 + dy), radius, particlePaint);
        }
      }
    }
  }

  List<Offset> _squigglePath(Rect rect, int rngSeed) {
    final rng = math.Random(rngSeed);
    const stepLen = 3.0;
    const wobble = 5.0;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
      rect.topLeft,
    ];
    final pts = <Offset>[];
    for (var s = 0; s < corners.length - 1; s++) {
      final a = corners[s];
      final b = corners[s + 1];
      final dist = (b - a).distance;
      if (dist == 0) continue;
      final steps = (dist / stepLen).floor();
      final dir = (b - a) / dist;
      final perp = Offset(-dir.dy, dir.dx);
      for (var k = 0; k <= steps; k++) {
        final base = a + dir * (k * stepLen);
        final w = (rng.nextDouble() - 0.5) * 2 * wobble;
        pts.add(base + perp * w);
      }
    }
    return pts;
  }

  @override
  bool shouldRepaint(_SquigglePainter old) =>
      old.progress != progress ||
      old.puffing != puffing ||
      old.lines != lines ||
      old.seed != seed ||
      old.fontSize != fontSize;
}
