import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/design/environment.dart';
import '../../../core/design/glass/glass_controls.dart';
import '../../../core/design/glass/glass_surface.dart';
import '../../../core/design/rise_in.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/time/minute_of_day.dart';
import '../application/hydration_controller.dart';
import '../domain/drink_log.dart';
import 'liquid_vessel.dart';

class HydrationDashboard extends StatelessWidget {
  const HydrationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.hydration,
      builder: (context, _) {
        final h = s.hydration;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            150 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            RiseIn(child: _HeroCard(h: h)),
            const SizedBox(height: 14),
            const RiseIn(index: 1, child: _QuickLogRow()),
            const SizedBox(height: 14),
            RiseIn(index: 2, child: _TimelineCard(h: h)),
            const SizedBox(height: 14),
            const RiseIn(index: 3, child: _InsightCard()),
            const SizedBox(height: 14),
            RiseIn(index: 4, child: _WeekCard(h: h)),
          ],
        );
      },
    );
  }
}

String formatMl(int ml) {
  final s = ml.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

String _hourLabel(MinuteOfDay m) {
  final h = m.hour % 12 == 0 ? 12 : m.hour % 12;
  final suffix = m.hour < 12 ? 'am' : 'pm';
  return m.minute == 0
      ? '$h $suffix'
      : '$h:${m.minute.toString().padLeft(2, '0')} $suffix';
}

String _whenLabel(DateTime at) {
  final now = DateTime.now();
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  return '${MinuteOfDay.of(at).format12()}${sameDay ? '' : ' tomorrow'}';
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.h});
  final HydrationController h;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final next = h.nextNudge;
    final last = h.lastLog;
    return GlassSurface(
      borderRadius: BorderRadius.circular(34),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiquidVessel(
                progress: h.progress,
                semanticLabel:
                    '${h.totalMl} of ${h.goalMl} millilitres, ${h.percent} percent of your goal',
              ),
              const SizedBox(width: 18),
              Expanded(
                child: SizedBox(
                  height: 188,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TODAY', style: AqType.eyebrow(t)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: _CountUp(
                              value: h.totalMl,
                              style: AqType.display(t, size: 54),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ml',
                            style: AqType.label(t, size: 15, color: t.ink2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'of your ${formatMl(h.goalMl)} ml goal',
                        style: AqType.body(t).copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: t.aquaSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          h.progress >= 1
                              ? 'Goal reached · no need for more'
                              : '${h.percent}% of your goal',
                          style: AqType.label(t, size: 12.5, color: t.aqua),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        last == null
                            ? 'No drinks yet today'
                            : '${h.today.length} ${h.today.length == 1 ? 'drink' : 'drinks'} · last at ${MinuteOfDay.of(last.loggedAt).format12()}',
                        style: AqType.caption(t),
                      ),
                      Text('Goal set by you', style: AqType.caption(t)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassSurface(
            weight: GlassWeight.thin,
            shareBackdrop: false,
            shadow: false,
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                Icon(Icons.notifications_none_rounded, size: 20, color: t.aqua),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next == null
                            ? 'No more nudges today'
                            : 'Next nudge · ${_whenLabel(next)}',
                        style: AqType.label(t, size: 13.5),
                      ),
                      const SizedBox(height: 1),
                      Text(h.nextNudgeReason, style: AqType.caption(t)),
                    ],
                  ),
                ),
                GlassButton(
                  label: h.snoozed ? 'Undo' : 'Snooze',
                  weight: GlassWeight.regular,
                  semanticLabel: h.snoozed
                      ? 'Undo snooze'
                      : 'Snooze the next nudge for 30 minutes',
                  onPressed: h.toggleSnooze,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style});
  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: value.toDouble()),
    duration: AqEnvironment.motionReduced(context)
        ? Duration.zero
        : const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) =>
        Text(formatMl(v.round()), style: style, maxLines: 1),
  );
}

class _QuickLogRow extends StatelessWidget {
  const _QuickLogRow();

  static const List<DrinkKind> _kinds = [
    DrinkKind.sip,
    DrinkKind.cup,
    DrinkKind.glass,
    DrinkKind.bottle,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _kinds.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _QuickChip(kind: _kinds[i])),
        ],
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.kind});
  final DrinkKind kind;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = AqTokens.of(context);
    final radius = BorderRadius.circular(24);
    final icon = switch (kind) {
      DrinkKind.sip => Icons.water_drop_outlined,
      DrinkKind.cup => Icons.coffee_outlined,
      DrinkKind.glass => Icons.local_drink_outlined,
      _ => null,
    };
    return Semantics(
      button: true,
      label: 'Log a ${kind.label.toLowerCase()}, ${kind.defaultMl} millilitres',
      excludeSemantics: true,
      child: PressScale(
        child: GlassSurface(
          weight: GlassWeight.thin,
          borderRadius: radius,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: () => s.quickLog(kind),
              child: SizedBox(
                height: 84,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null)
                      Icon(icon, size: 24, color: t.aqua)
                    else
                      CustomPaint(
                        size: const Size(24, 24),
                        painter: _BottleIconPainter(t.aqua),
                      ),
                    const SizedBox(height: 3),
                    Text(kind.label, style: AqType.label(t)),
                    Text(
                      '${kind.defaultMl} ml',
                      style: AqType.caption(t)
                          .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottleIconPainter extends CustomPainter {
  const _BottleIconPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.scale(s);
    final path = Path()
      ..moveTo(10, 2.5)
      ..lineTo(14, 2.5)
      ..moveTo(10.5, 2.5)
      ..lineTo(10.5, 5.7)
      ..lineTo(8.4, 8.4)
      ..quadraticBezierTo(8, 9, 8, 9.9)
      ..lineTo(8, 19)
      ..quadraticBezierTo(8, 21.5, 10.5, 21.5)
      ..lineTo(13.5, 21.5)
      ..quadraticBezierTo(16, 21.5, 16, 19)
      ..lineTo(16, 9.9)
      ..quadraticBezierTo(16, 9, 15.6, 8.4)
      ..lineTo(13.5, 5.7)
      ..lineTo(13.5, 2.5)
      ..moveTo(8, 13)
      ..lineTo(16, 13);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_BottleIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.h});
  final HydrationController h;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final policy = h.policy;
    final start = policy.wakeStart;
    final span = start.minutesUntil(policy.wakeEnd);
    final labels = List<String>.generate(
      5,
      (i) => _hourLabel(start + (span * i / 4).round()),
    );
    final next = h.nextNudge;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text("Today's rhythm", style: AqType.title(t))),
              Text(
                'Waking hours ${_hourLabel(start)} – ${_hourLabel(policy.wakeEnd)}',
                style: AqType.caption(t),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label:
                '${h.today.length} drinks logged today.'
                '${next == null ? '' : ' Next nudge at ${_whenLabel(next)}.'}',
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: CustomPaint(
                painter: _TimelinePainter(
                  tokens: t,
                  start: start,
                  span: span,
                  quietStart: policy.quietStart,
                  now: MinuteOfDay.of(DateTime.now()),
                  next: next == null ? null : MinuteOfDay.of(next),
                  drops: [
                    for (final l in h.today)
                      (MinuteOfDay.of(l.loggedAt), l.amountMl),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in labels)
                Text(l, style: AqType.caption(t).copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.tokens,
    required this.start,
    required this.span,
    required this.quietStart,
    required this.now,
    required this.next,
    required this.drops,
  });

  final AqTokens tokens;
  final MinuteOfDay start;
  final int span;
  final MinuteOfDay quietStart;
  final MinuteOfDay now;
  final MinuteOfDay? next;
  final List<(MinuteOfDay, int)> drops;

  double _x(MinuteOfDay m, double width) {
    final d = start.minutesUntil(m);
    if (d > span) return d > span + (1440 - span) / 2 ? 0.0 : width;
    return d / span * width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    final w = size.width;
    const mid = 32.0;

    // Quiet hours, hatched.
    if (start.minutesUntil(quietStart) < span) {
      final qx = _x(quietStart, w);
      final zone = Rect.fromLTRB(qx, 16, w, 48);
      canvas
        ..save()
        ..clipRRect(RRect.fromRectAndRadius(zone, const Radius.circular(8)));
      final hatch = Paint()
        ..color = t.track
        ..strokeWidth = 3;
      for (var x = zone.left - zone.height; x < zone.right; x += 7) {
        canvas.drawLine(
          Offset(x, zone.bottom),
          Offset(x + zone.height, zone.top),
          hatch,
        );
      }
      canvas.restore();
    }

    final track = Paint()
      ..color = t.track
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, mid), Offset(w, mid), track);

    final nx = _x(now, w);
    canvas.drawLine(
      const Offset(0, mid),
      Offset(nx, mid),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [t.waterTop, t.aqua])
            .createShader(Rect.fromLTWH(0, mid - 1, math.max(1, nx), 2)),
    );

    final n = next;
    if (n != null) {
      final c = Offset(_x(n, w), mid);
      final dash = Paint()
        ..color = t.aqua
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final rect = Rect.fromCircle(center: c, radius: 6);
      for (var i = 0; i < 8; i++) {
        canvas.drawArc(rect, i * math.pi / 4, math.pi / 8, false, dash);
      }
    }

    for (final (m, ml) in drops) {
      final r = ml >= 500 ? 8.0 : (ml >= 250 ? 6.5 : 5.0);
      final c = Offset(_x(m, w), mid);
      canvas.drawCircle(c, r + 3, Paint()..color = t.glassStrong);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.waterTop, t.waterBottom],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    canvas.drawLine(
      Offset(nx, 12),
      Offset(nx, 52),
      Paint()
        ..color = t.ink.withValues(alpha: 0.75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final label = TextPainter(
      text: TextSpan(
        text: 'NOW',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: t.ink2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(
        (nx - label.width / 2).clamp(0.0, math.max(0.0, w - label.width)),
        -2,
      ),
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) => true;
}

/// Short educational cards. In production these come from reviewed,
/// versioned `content_items` (blueprint sections 05 and 10); until a
/// qualified reviewer signs them off they are labelled "review pending".
class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final hour = DateTime.now().hour;
    final (title, body) = hour < 12
        ? (
            'A gentle start',
            'Water from food and other drinks counts too. A plain-water log is only part of the picture.',
          )
        : (
            'Warm afternoon',
            'Needs rise with heat and activity. Sipping through the afternoon is gentler than drinking a lot at once.',
          );
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.leafSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.eco_outlined, size: 22, color: t.leaf),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AqType.title(t)),
                const SizedBox(height: 4),
                Text(body, style: AqType.body(t)),
                const SizedBox(height: 8),
                Text(
                  'Source: NHS hydration guidance · review pending',
                  style: AqType.caption(t).copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.h});
  final HydrationController h;

  static const List<String> _names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final kept = h.week.where((d) => d.state == RhythmDayState.kept).length;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('This week', style: AqType.title(t))),
              Text(
                'Routine kept on $kept ${kept == 1 ? 'day' : 'days'}',
                style: AqType.caption(t),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in h.week)
                Semantics(
                  label:
                      '${_names[day.date.weekday - 1]}, ${switch (day.state) {
                        RhythmDayState.kept => 'routine kept',
                        RhythmDayState.rest => 'rest day',
                        RhythmDayState.today => 'today, in progress',
                      }}',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      _DayCapsule(day: day),
                      const SizedBox(height: 6),
                      Text(
                        _names[day.date.weekday - 1][0],
                        style: AqType.label(t, size: 11, color: t.ink3),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Rest days are part of the rhythm.', style: AqType.caption(t)),
        ],
      ),
    );
  }
}

class _DayCapsule extends StatelessWidget {
  const _DayCapsule({required this.day});
  final RhythmDay day;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final kept = day.state == RhythmDayState.kept;
    final today = day.state == RhythmDayState.today;
    return Container(
      width: 34,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kept ? t.aqua : t.glassThin,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: today ? t.aqua : t.edge,
          width: today ? 2 : 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (today)
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: day.progress,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [t.waterTop, t.waterBottom],
                    ),
                  ),
                ),
              ),
            ),
          if (kept) Icon(Icons.check_rounded, size: 18, color: t.onAccent),
        ],
      ),
    );
  }
}
