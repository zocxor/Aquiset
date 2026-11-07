import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/environment.dart';
import '../../../core/design/motion.dart';
import '../../../core/design/tokens.dart';

/// Glass tumbler whose water level rises on a spring after each log, with a
/// slow two-layer surface wave. Static under reduced motion.
class LiquidVessel extends StatefulWidget {
  const LiquidVessel({
    super.key,
    required this.progress,
    required this.semanticLabel,
    this.size = const Size(116, 188),
  });

  /// 0–1 of the person's own goal. Above 1 simply shows full.
  final double progress;
  final String semanticLabel;
  final Size size;

  @override
  State<LiquidVessel> createState() => _LiquidVesselState();
}

class _LiquidVesselState extends State<LiquidVessel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: AqMotion.wavePeriod,
  );
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AqEnvironment.motionReduced(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _wave.stop();
    } else {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final reduced = _reduced ?? false;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.progress.clamp(0.06, 1.0)),
        duration: reduced ? Duration.zero : AqMotion.fillDuration,
        curve: AqMotion.fill,
        builder:
            (context, level, _) => AnimatedBuilder(
              animation: _wave,
              builder:
                  (context, _) => CustomPaint(
                    size: widget.size,
                    painter: _VesselPainter(
                      tokens: t,
                      level: level,
                      phase: _wave.value,
                    ),
                  ),
            ),
      ),
    );
  }
}

class _VesselPainter extends CustomPainter {
  _VesselPainter({
    required this.tokens,
    required this.level,
    required this.phase,
  });

  final AqTokens tokens;
  final double level;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    final shape = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: const Radius.circular(40),
      topRight: const Radius.circular(40),
      bottomLeft: const Radius.circular(50),
      bottomRight: const Radius.circular(50),
    );

    canvas
      ..save()
      ..clipRRect(shape)
      ..drawRRect(shape, Paint()..color = t.track);

    final surface = size.height * (1 - level.clamp(0.0, 1.0));
    final angle = phase * math.pi * 2;

    canvas.drawPath(
      _wave(size, surface - 3, 4, angle + math.pi),
      Paint()..color = t.waterTop.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      _wave(size, surface, 5, angle),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.waterTop, t.waterBottom],
        ).createShader(Rect.fromLTRB(0, surface - 6, size.width, size.height)),
    );

    // Vertical shine down the left of the glass.
    const shine = Rect.fromLTWH(14, 18, 9, 124);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shine, const Radius.circular(5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(shine),
    );

    // Measuring marks at 25 / 50 / 75 %.
    final mark =
        Paint()
          ..color = t.edge
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
    for (final (frac, len) in const [(0.25, 12.0), (0.5, 18.0), (0.75, 12.0)]) {
      final y = size.height * frac;
      canvas.drawLine(
        Offset(size.width - 12 - len, y),
        Offset(size.width - 12, y),
        mark,
      );
    }

    canvas.restore();
    canvas.drawRRect(
      shape.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = t.edge,
    );
  }

  Path _wave(Size size, double top, double amplitude, double angle) {
    final wavelength = size.width * 0.9;
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 3) {
      path.lineTo(
        x,
        top + amplitude * math.sin(x / wavelength * math.pi * 2 + angle),
      );
    }
    return path
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldRepaint(_VesselPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.phase != phase ||
      oldDelegate.tokens != tokens;
}
