import 'package:flutter/widgets.dart';

import 'environment.dart';
import 'motion.dart';

/// Cards rise 14 px and fade in on first show, [index] × 40 ms apart.
/// Uses one controller per card with an [Interval] for the stagger, so no
/// timers are left pending. Instant under reduced motion.
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final delay = AqMotion.stagger * widget.index;
    final total = AqMotion.riseDuration + delay;
    _controller = AnimationController(vsync: this, duration: total);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AqMotion.rise,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AqEnvironment.motionReduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, child) {
      final v = _progress.value;
      return Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 14),
          child: Transform.scale(scale: 0.985 + 0.015 * v, child: child),
        ),
      );
    },
    child: widget.child,
  );
}
