import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The painted lake-and-hills scene the glass refracts.
///
/// Drawn in a 390×844 design space and scaled to cover the screen. Every
/// colour comes from [AqTokens], so the sun sets and the moon and stars
/// fade in as Day lerps to Night. Static: it repaints only when tokens change.
class NatureBackdrop extends StatelessWidget {
  const NatureBackdrop({super.key});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _NaturePainter(AqTokens.of(context)),
      child: const SizedBox.expand(),
    ),
  );
}

class _NaturePainter extends CustomPainter {
  _NaturePainter(this.t);
  final AqTokens t;

  static const double _w = 390;
  static const double _h = 844;
  static const Color _moonlight = Color(0xFFECE8FA);

  static const List<(double, double, double)> _stars = [
    (48, 90, 1.6),
    (132, 58, 1.2),
    (196, 120, 1.4),
    (88, 190, 1.0),
    (362, 250, 1.3),
    (228, 40, 1.1),
  ];
  static const List<(double, double, double)> _lakeLines = [
    (40, 520, 90),
    (210, 540, 120),
    (80, 600, 70),
    (240, 642, 100),
    (30, 700, 120),
    (200, 760, 90),
  ];

  static final Path _hill1 = Path()
    ..moveTo(0, 330)
    ..cubicTo(70, 290, 140, 300, 200, 325)
    ..cubicTo(260, 350, 320, 300, 390, 310)
    ..lineTo(390, 844)
    ..lineTo(0, 844)
    ..close();
  static final Path _hill2 = Path()
    ..moveTo(0, 420)
    ..cubicTo(90, 372, 170, 400, 240, 420)
    ..cubicTo(300, 438, 350, 402, 390, 406)
    ..lineTo(390, 844)
    ..lineTo(0, 844)
    ..close();
  static final Path _leafLeft = Path()
    ..moveTo(-20, 844)
    ..cubicTo(10, 720, 60, 650, 124, 606)
    ..cubicTo(102, 700, 72, 780, 62, 844)
    ..close();
  static final Path _leafRight = Path()
    ..moveTo(410, 844)
    ..cubicTo(380, 740, 340, 690, 278, 660)
    ..cubicTo(310, 740, 330, 800, 330, 844)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.max(size.width / _w, size.height / _h);
    canvas
      ..save()
      ..translate((size.width - _w * scale) / 2, (size.height - _h * scale) / 2)
      ..scale(scale);

    const full = Rect.fromLTWH(0, 0, _w, _h);
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.skyTop, t.skyBottom],
        ).createShader(full),
    );

    const glowCentre = Offset(300, 150);
    canvas.drawCircle(
      glowCentre,
      180,
      Paint()
        ..shader = RadialGradient(
          colors: [t.glow.withValues(alpha: 0.85), t.glow.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: glowCentre, radius: 180)),
    );

    final day = 1 - t.nightness;
    if (day > 0.01) {
      canvas.drawCircle(
        glowCentre,
        40,
        Paint()..color = t.gold2.withValues(alpha: 0.6 * day),
      );
    }
    if (t.nightness > 0.01) {
      canvas.drawCircle(
        const Offset(296, 140),
        30,
        Paint()..color = _moonlight.withValues(alpha: 0.95 * t.nightness),
      );
      final star = Paint()
        ..color = _moonlight.withValues(alpha: 0.75 * t.nightness);
      for (final (x, y, r) in _stars) {
        canvas.drawCircle(Offset(x, y), r, star);
      }
    }

    // Soft colour orbs: this is what glows through the glass.
    canvas.drawCircle(
      const Offset(60, 320),
      96,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34)
        ..color = t.aqua2.withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      const Offset(340, 560),
      120,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34)
        ..color = t.lav2.withValues(alpha: 0.26),
    );

    canvas.drawPath(_hill1, Paint()..color = t.hill1);
    canvas.drawPath(_hill2, Paint()..color = t.hill2);

    const lake = Rect.fromLTWH(0, 470, _w, 374);
    canvas.drawRect(
      lake,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.lake, t.hill2],
        ).createShader(lake),
    );
    final ripple = Paint()
      ..color = t.lakeLine
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final (x, y, len) in _lakeLines) {
      canvas.drawLine(Offset(x, y), Offset(x + len, y), ripple);
    }

    final leaf = Paint()..color = t.hill3;
    canvas
      ..drawPath(_leafLeft, leaf)
      ..drawPath(_leafRight, leaf)
      ..restore();
  }

  @override
  bool shouldRepaint(_NaturePainter oldDelegate) => oldDelegate.t != t;
}
