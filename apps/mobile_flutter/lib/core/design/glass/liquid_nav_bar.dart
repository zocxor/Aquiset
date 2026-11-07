import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../environment.dart';
import '../motion.dart';
import '../tokens.dart';
import '../typography.dart';
import 'glass_surface.dart';

class LiquidNavItem {
  const LiquidNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Floating liquid glass tab bar.
///
/// The selection lens has two independently sprung edges. When the user
/// moves to another tab, the leading edge travels on a stiff spring and the
/// trailing edge on a soft one, so the lens stretches like a droplet, thins
/// slightly while stretched, then settles. Velocity carries over if the user
/// taps again mid-flight. With reduced motion the lens jumps.
class LiquidGlassNavBar extends StatefulWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.height = 66,
  });

  final List<LiquidNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar> with TickerProviderStateMixin {
  late final AnimationController _left =
      AnimationController.unbounded(vsync: this, value: widget.index.toDouble());
  late final AnimationController _right =
      AnimationController.unbounded(vsync: this, value: widget.index.toDouble());
  bool _reduceMotion = false;

  @override
  void didUpdateWidget(LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final target = widget.index.toDouble();
    if (_reduceMotion) {
      _left.value = target;
      _right.value = target;
      return;
    }
    final movingRight = target > _left.value;
    final lead = movingRight ? _right : _left;
    final trail = movingRight ? _left : _right;
    lead.animateWith(SpringSimulation(AqMotion.lensLead, lead.value, target, lead.velocity));
    trail.animateWith(SpringSimulation(AqMotion.lensTrail, trail.value, target, trail.velocity));
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = AqEnvironment.motionReduced(context);
    const pad = 6.0;
    return GlassSurface(
      weight: GlassWeight.strong,
      borderRadius: BorderRadius.circular(widget.height / 2),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = (constraints.maxWidth - pad * 2) / widget.items.length;
            final lensHeight = widget.height - pad * 2;
            return Stack(
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_left, _right]),
                  builder: (context, _) {
                    final l = _left.value;
                    final r = _right.value;
                    final stretch = (r - l).abs();
                    final h = lensHeight * (1 - 0.1 * math.min(stretch, 1.0));
                    return Positioned(
                      left: pad + math.min(l, r) * slot,
                      top: (widget.height - h) / 2,
                      width: (stretch + 1) * slot,
                      height: h,
                      child: GlassSurface(
                        weight: GlassWeight.lens,
                        shareBackdrop: false,
                        shadow: false,
                        borderRadius: BorderRadius.circular(h / 2),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  left: pad,
                  right: pad,
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: widget.items[i],
                            selected: i == widget.index,
                            onTap: () {
                              if (i == widget.index) return;
                              HapticFeedback.selectionClick();
                              widget.onChanged(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final LiquidNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: selected ? 1 : 0),
          duration: const Duration(milliseconds: 280),
          builder: (context, v, _) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 22, color: Color.lerp(t.ink3, t.aqua, v)),
              const SizedBox(height: 3),
              Text(item.label, style: AqType.label(t, size: 11, color: Color.lerp(t.ink3, t.ink, v))),
            ],
          ),
        ),
      ),
    );
  }
}
