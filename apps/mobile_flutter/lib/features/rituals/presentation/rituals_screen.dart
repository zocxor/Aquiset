import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/glass/glass_controls.dart';
import '../../../core/design/glass/glass_surface.dart';
import '../../../core/design/rise_in.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';

/// Optional challenges (blueprint section 07). No volume targets, no public
/// ranking, rest days allowed, and everything can be paused.
class RitualsScreen extends StatefulWidget {
  const RitualsScreen({super.key});

  @override
  State<RitualsScreen> createState() => _RitualsScreenState();
}

class _RitualsScreenState extends State<RitualsScreen> {
  bool _doneToday = false;
  bool _paused = false;
  final Map<String, bool> _joined = {
    'morning': false,
    'wind': true,
    'rhythm': false,
  };

  static const List<(String, String, String)> _catalog = [
    ('morning', 'Morning reset', '3 steps · your timing'),
    ('wind', 'Wind-down week', '7 evenings · any order'),
    ('rhythm', 'Hydration rhythm', '5 days · moments you choose'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final day = _doneToday ? 4 : 3;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        150 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        RiseIn(
          child: GlassSurface(
            borderRadius: BorderRadius.circular(34),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _paused ? 'PAUSED RITUAL' : 'ACTIVE RITUAL',
                  style: AqType.eyebrow(t),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Semantics(
                      label: 'Day $day of 5',
                      excludeSemantics: true,
                      child: SizedBox.square(
                        dimension: 84,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: day / 5),
                          duration: const Duration(milliseconds: 900),
                          curve: const Cubic(0.3, 1.2, 0.4, 1),
                          builder: (context, v, _) => CustomPaint(
                            painter: _RingPainter(
                              progress: v,
                              track: t.track,
                              color: t.leaf,
                            ),
                            child: Center(
                              child: Text(
                                '$day/5',
                                style: AqType.display(t, size: 26),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nature pause',
                            style: AqType.display(t, size: 30),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Step outside for five minutes whenever it suits you. No location needed.',
                            style: AqType.body(t),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: _doneToday
                            ? 'Done for today'
                            : 'Mark today done',
                        icon: _doneToday ? Icons.check_rounded : null,
                        expand: true,
                        height: 48,
                        weight: GlassWeight.regular,
                        tint: _doneToday ? t.leafSoft : t.leaf,
                        foreground: _doneToday ? t.leaf : t.onAccent,
                        onPressed: _paused
                            ? null
                            : () => setState(() => _doneToday = !_doneToday),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GlassButton(
                      label: _paused ? 'Resume' : 'Pause',
                      height: 48,
                      onPressed: () => setState(() => _paused = !_paused),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        RiseIn(
          index: 1,
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Explore rituals', style: AqType.title(t)),
                ),
                for (final (id, title, meta) in _catalog)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: t.track)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AqType.label(t, size: 14)),
                              const SizedBox(height: 2),
                              Text(meta, style: AqType.caption(t)),
                            ],
                          ),
                        ),
                        GlassButton(
                          label: (_joined[id] ?? false) ? 'Joined' : 'Join',
                          foreground: (_joined[id] ?? false) ? t.leaf : null,
                          semanticLabel:
                              '${(_joined[id] ?? false) ? 'Leave' : 'Join'} $title',
                          onPressed: () => setState(
                            () => _joined[id] = !(_joined[id] ?? false),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        RiseIn(
          index: 2,
          child: Row(
            children: [
              Expanded(
                child: _Badge(
                  icon: Icons.eco_outlined,
                  title: 'First pause',
                  note: 'Unlocked',
                  color: t.leaf,
                  soft: t.leafSoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Badge(
                  icon: Icons.water_drop_outlined,
                  title: 'Easy rhythm',
                  note: 'Unlocked',
                  color: t.aqua,
                  soft: t.aquaSoft,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _Badge(
                  icon: Icons.lock_outline_rounded,
                  title: 'Steady week',
                  note: 'Any 4 days',
                  locked: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.title,
    required this.note,
    this.color,
    this.soft,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String note;
  final Color? color;
  final Color? soft;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return GlassSurface(
      weight: GlassWeight.thin,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Semantics(
        label: '$title, ${locked ? 'locked, $note' : note}',
        excludeSemantics: true,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: locked ? null : soft,
                border: locked ? Border.all(color: t.ink3, width: 1.5) : null,
              ),
              child: Icon(icon, size: 20, color: locked ? t.ink3 : color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AqType.label(t, size: 12.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(note, style: AqType.caption(t).copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 8,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}
