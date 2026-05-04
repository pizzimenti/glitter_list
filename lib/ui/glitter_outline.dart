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
    this.precomputedLines,
    this.precomputedSize,
  });

  final String text;
  final TextStyle style;
  final bool glittered;
  final int seed;

  /// When provided (alongside [precomputedSize]), skip the internal
  /// TextPainter layout and use these line metrics directly. Set by
  /// `PerLineBackdropBlur`'s `betweenLayerBuilder` so the squiggle's
  /// contour is computed against the OUTER painter's break points
  /// rather than re-laying out at a tighter inner constraint.
  final List<LineMetrics>? precomputedLines;
  final Size? precomputedSize;

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
      duration: const Duration(milliseconds: 2400),
      reverseDuration: const Duration(milliseconds: 700),
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

    Widget paint(List<LineMetrics> lines, Size size) {
      return SizedBox(
        width: size.width,
        height: size.height,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => CustomPaint(
            painter: _SquigglePainter(
              lines: lines,
              brightness: Theme.of(context).brightness,
              progress: _ctrl.value,
              puffing: _puffing && _ctrl.status == AnimationStatus.reverse,
              seed: widget.seed,
              fontSize: widget.style.fontSize ?? 16,
            ),
          ),
        ),
      );
    }

    final preLines = widget.precomputedLines;
    final preSize = widget.precomputedSize;
    if (preLines != null && preSize != null) {
      return IgnorePointer(child: paint(preLines, preSize));
    }

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
          return paint(lines, size);
        },
      ),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter({
    required this.lines,
    required this.brightness,
    required this.progress,
    required this.puffing,
    required this.seed,
    required this.fontSize,
  });

  final List<LineMetrics> lines;
  final Brightness brightness;
  final double progress;
  final bool puffing;
  final int seed;
  final double fontSize;

  // Theme-tuned palette: light mode uses a deep magenta paired with
  // the muted purple `lightContent`; dark mode pairs the hot accent
  // pink with the soft chrome lilac. Both pairs sit far enough from
  // the bg in luminance to read clearly without an opaque backdrop.
  static const _lightAwareColors = <Color>[
    Color(0xFFC01875),
    GlitterColors.lightContent,
  ];
  static const _darkAwareColors = <Color>[
    GlitterColors.accent,
    GlitterColors.darkChrome,
  ];

  // Contrast under-stroke painted slightly wider behind each squiggle
  // segment so the rainbow doesn't squirm directly against the busy
  // glitter bg. Light mode goes dark (against pink); dark mode goes
  // light (against deep purple).
  Color get _understrokeColor => brightness == Brightness.dark
      ? const Color(0xFFFFE4F3)
      : const Color(0xFF2A153F);

  List<Color> get _colors =>
      brightness == Brightness.dark ? _darkAwareColors : _lightAwareColors;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty || progress <= 0) return;
    final strokeWidth = math.max(1.5, fontSize * 0.06);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;
    final underPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth + 2.4;
    final understrokeAlpha = brightness == Brightness.dark ? 0.62 : 0.42;

    // Per-line contour — one squiggle wraps the whole item, but the
    // right side traces each line's actual width so a shorter line
    // doesn't get empty bg between its glyphs and the outline. The
    // path is a CW polygon: down the left edge (shared minLeft), top
    // of line 0, then a staircase on the right that drops down each
    // line's right edge and cuts horizontally at each line boundary
    // to the next line's right.
    final corners = _contourCorners(lines, padH: 12, padV: 2);
    if (corners.length < 3) return;

    final pts = _squigglePath(corners, seed);
    final visibleCount = (pts.length * progress).round();
    if (visibleCount >= 2) {
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
        underPaint.color = _understrokeColor.withValues(
          alpha: alpha * understrokeAlpha,
        );
        canvas.drawPath(path, underPaint);
        canvas.drawPath(path, basePaint);
        j = end;
      }
    }

    if (puffing) {
      final t = 1.0 - progress;
      final rng = math.Random(seed ^ 5077);
      // Bounding rect of the contour for puff particle scatter.
      var pminX = double.infinity;
      var pmaxX = double.negativeInfinity;
      var pminY = double.infinity;
      var pmaxY = double.negativeInfinity;
      for (final c in corners) {
        if (c.dx < pminX) pminX = c.dx;
        if (c.dx > pmaxX) pmaxX = c.dx;
        if (c.dy < pminY) pminY = c.dy;
        if (c.dy > pmaxY) pmaxY = c.dy;
      }
      final puffW = pmaxX - pminX;
      final puffH = pmaxY - pminY;
      // Scale particle count with bounding area so a multi-line item
      // puffs at roughly the same density a single line did.
      final particleCount = (puffW * puffH / 330).clamp(10, 40).round();
      final particlePaint = Paint();
      for (var k = 0; k < particleCount; k++) {
        final x0 = pminX + rng.nextDouble() * puffW;
        final y0 = pminY + rng.nextDouble() * puffH;
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

  /// CW corners of the per-line text contour.
  ///
  /// Layout for a 3-line item with widths [200, 120, 140]:
  /// ```
  ///  TL ─────────────────► (right0, top0)
  ///  ▲                     │
  ///  │                     ▼
  ///  │                    (right0, bot0)
  ///  │                     ◄────── (right1, bot0)
  ///  │                            │
  ///  │                            ▼
  ///  │                           (right1, bot1)
  ///  │                            ──────► (right2, bot1)
  ///  │                                    │
  ///  │                                    ▼
  ///  │                                   (right2, bot2)
  ///  └─────── BL (left, bot2) ◄───────────┘
  /// ```
  static List<Offset> _contourCorners(
    List<LineMetrics> lines, {
    required double padH,
    required double padV,
  }) {
    final n = lines.length;
    var minLeft = double.infinity;
    final tops = <double>[];
    final bottoms = <double>[];
    final rights = <double>[];
    for (var i = 0; i < n; i++) {
      final m = lines[i];
      if (m.left < minLeft) minLeft = m.left;
      final top = m.baseline - m.ascent;
      final bottom = top + m.height;
      // padV only on the OUTER top/bottom — inner tops/bottoms are
      // shared boundaries with adjacent lines, no padding there.
      tops.add(i == 0 ? top - padV : top);
      bottoms.add(i == n - 1 ? bottom + padV : bottom);
      rights.add(m.left + m.width + padH);
    }
    final left = minLeft - padH;

    final corners = <Offset>[];
    corners.add(Offset(left, tops[0]));
    corners.add(Offset(rights[0], tops[0]));
    for (var i = 0; i < n; i++) {
      corners.add(Offset(rights[i], bottoms[i]));
      if (i < n - 1) {
        corners.add(Offset(rights[i + 1], bottoms[i]));
      }
    }
    corners.add(Offset(left, bottoms[n - 1]));
    return corners;
  }

  /// Walk the closed polygon defined by [corners] (CW outer boundary
  /// of the text contour) and emit a wavy point sequence stepping
  /// every `stepLen` along arc length.
  ///
  /// `perp` (= 90° CCW from segment direction) points INWARD on every
  /// segment of a CW outer-boundary traversal — including the
  /// horizontal "cuts" between staircase lines, where each cut sits
  /// on the y-boundary between an above-line and a below-line and
  /// perp points back into whichever line side is text. The wave is
  /// therefore clamped to outward-only (`w ≤ 0` so the offset is in
  /// `-perp` direction) on every segment, guaranteeing the squiggle
  /// can never dip inward into glyphs regardless of which random
  /// phase the line draws.
  List<Offset> _squigglePath(List<Offset> corners, int rngSeed) {
    final rng = math.Random(rngSeed);
    // Two layered sines with non-integer wavelength ratio give a
    // wavy, varied character without looking like a pure sine. A
    // random phase pair keeps neighbouring squiggles from marching
    // in lockstep. `cornerTaper` damps the wave amplitude near each
    // polygon corner so the perpendicular discontinuity at corners
    // doesn't produce a visible kink.
    const stepLen = 4.0;
    const wobble = 4.5;
    const wavelengthA = 28.0;
    const wavelengthB = 17.0;
    const cornerTaperPx = 14.0;
    final phaseA = rng.nextDouble() * 2 * math.pi;
    final phaseB = rng.nextDouble() * 2 * math.pi;
    final loop = [...corners, corners.first];
    final pts = <Offset>[];
    var arc = 0.0;
    for (var s = 0; s < loop.length - 1; s++) {
      final a = loop[s];
      final b = loop[s + 1];
      final dist = (b - a).distance;
      if (dist == 0) continue;
      final steps = (dist / stepLen).floor();
      final dir = (b - a) / dist;
      final perp = Offset(-dir.dy, dir.dx);
      for (var k = 0; k <= steps; k++) {
        final dAlong = k * stepLen;
        final t = arc + dAlong;
        final taperStart = (dAlong / cornerTaperPx).clamp(0.0, 1.0);
        final taperEnd = ((dist - dAlong) / cornerTaperPx).clamp(0.0, 1.0);
        final taper = math.min(taperStart, taperEnd);
        var w =
            wobble *
            taper *
            (0.7 * math.sin(t / wavelengthA * 2 * math.pi + phaseA) +
                0.3 * math.sin(t / wavelengthB * 2 * math.pi + phaseB));
        if (w > 0) w = -w;
        pts.add(a + dir * dAlong + perp * w);
      }
      arc += dist;
    }
    return pts;
  }

  @override
  bool shouldRepaint(_SquigglePainter old) =>
      old.progress != progress ||
      old.brightness != brightness ||
      old.puffing != puffing ||
      old.lines != lines ||
      old.seed != seed ||
      old.fontSize != fontSize;
}
