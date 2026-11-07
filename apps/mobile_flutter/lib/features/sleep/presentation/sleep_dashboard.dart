import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/design/glass/glass_controls.dart';
import '../../../core/design/glass/glass_surface.dart';
import '../../../core/design/rise_in.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/time/minute_of_day.dart';
import '../../../platform/rhythm_platform.dart';
import '../application/sleep_controller.dart';
import '../domain/sleep_schedule.dart';

class SleepDashboard extends StatelessWidget {
  const SleepDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.sleep,
      builder: (context, _) {
        final c = s.sleep;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 150 + MediaQuery.paddingOf(context).bottom),
          children: [
            RiseIn(child: _DialCard(c: c)),
            const SizedBox(height: 14),
            RiseIn(index: 1, child: _WindDownCard(c: c)),
            const SizedBox(height: 14),
            RiseIn(index: 2, child: _AlarmCard(c: c)),
            const SizedBox(height: 14),
            RiseIn(index: 3, child: _LastNightCard(c: c)),
            const SizedBox(height: 14),
            RiseIn(index: 4, child: _ConsistencyCard(c: c)),
          ],
        );
      },
    );
  }
}

String _restLabel(Duration d) => '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

String weekdaysLabel(Set<int> days) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && days.containsAll(const {1, 2, 3, 4, 5})) return 'Weekdays';
  if (days.length == 2 && days.containsAll(const {6, 7})) return 'Weekends';
  if (days.isEmpty) return 'Once';
  return (days.toList()..sort()).map((d) => names[d - 1]).join(', ');
}

class _DialCard extends StatelessWidget {
  const _DialCard({required this.c});
  final SleepController c;

  static const double _size = 236;
  static const double _radius = 92;

  Widget _handle(MinuteOfDay m, IconData icon, Color color) {
    final a = m.value / 1440 * math.pi * 2 - math.pi / 2;
    return Positioned(
      left: _size / 2 + _radius * math.cos(a) - 17,
      top: _size / 2 + _radius * math.sin(a) - 17,
      child: GlassSurface(
        weight: GlassWeight.strong,
        shareBackdrop: false,
        borderRadius: BorderRadius.circular(17),
        child: SizedBox.square(dimension: 34, child: Icon(icon, size: 16, color: color)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final sch = c.schedule;
    final rest = sch.plannedRest;
    return GlassSurface(
      borderRadius: BorderRadius.circular(34),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('PLANNED REST', style: AqType.eyebrow(t))),
              Text('Wind-down from ${sch.windDownStart.format12()}', style: AqType.caption(t)),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Bedtime ${sch.bedtime.format12()}, wake ${sch.wake.format12()}, '
                '${rest.inHours} hours ${rest.inMinutes % 60} minutes planned',
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: _size,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size.square(_size),
                    painter: _DialPainter(tokens: t, bed: sch.bedtime, wake: sch.wake, radius: _radius),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_restLabel(rest), style: AqType.display(t, size: 36)),
                        const SizedBox(height: 4),
                        Text('planned rest', style: AqType.caption(t)),
                      ],
                    ),
                  ),
                  _handle(sch.bedtime, Icons.nightlight_outlined, t.lav),
                  _handle(sch.wake, Icons.wb_sunny_outlined, t.gold),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TimeStepper(
                  label: 'Bedtime',
                  value: sch.bedtime.format12(),
                  onMinus: () => c.shiftBedtime(-15),
                  onPlus: () => c.shiftBedtime(15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TimeStepper(
                  label: 'Wake',
                  value: sch.wake.format12(),
                  onMinus: () => c.shiftWake(-15),
                  onPlus: () => c.shiftWake(15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.tokens, required this.bed, required this.wake, required this.radius});

  final AqTokens tokens;
  final MinuteOfDay bed;
  final MinuteOfDay wake;
  final double radius;

  Offset _point(Offset c, double minute, double r) {
    final a = minute / 1440 * math.pi * 2 - math.pi / 2;
    return Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    final c = size.center(Offset.zero);
    final ring = Rect.fromCircle(center: c, radius: radius);

    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..color = t.track,
    );

    final tick = Paint()
      ..color = t.ink3.withValues(alpha: 0.6)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 48; i++) {
      final m = i * 30.0;
      canvas.drawLine(_point(c, m, i.isEven ? 63 : 67), _point(c, m, 72), tick);
    }

    final start = bed.value / 1440 * math.pi * 2 - math.pi / 2;
    final sweep = bed.minutesUntil(wake) / 1440 * math.pi * 2;
    canvas.drawArc(
      ring,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.lav, t.aqua2],
        ).createShader(ring),
    );

    for (final (minute, text) in const [(0.0, '12 am'), (360.0, '6 am'), (720.0, '12 pm'), (1080.0, '6 pm')]) {
      final p = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: t.ink3)),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = _point(c, minute, 54);
      p.paint(canvas, at - Offset(p.width / 2, p.height / 2));
    }
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.bed != bed || oldDelegate.wake != wake || oldDelegate.tokens != tokens;
}

/// − time + stepper on thin glass. Each button is a 44×44 target.
class TimeStepper extends StatelessWidget {
  const TimeStepper({super.key, required this.label, required this.value, required this.onMinus, required this.onPlus});

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    Widget button(IconData icon, String semantic, VoidCallback onTap) => Semantics(
          button: true,
          label: semantic,
          excludeSemantics: true,
          child: InkResponse(
            onTap: onTap,
            radius: 24,
            child: SizedBox.square(dimension: 44, child: Icon(icon, size: 18, color: t.ink)),
          ),
        );
    return GlassSurface(
      weight: GlassWeight.thin,
      shareBackdrop: false,
      shadow: false,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            button(Icons.remove_rounded, '$label 15 minutes earlier', onMinus),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label.toUpperCase(), style: AqType.eyebrow(t, size: 10)),
                  const SizedBox(height: 2),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AqType.stat(t, size: 15))),
                ],
              ),
            ),
            button(Icons.add_rounded, '$label 15 minutes later', onPlus),
          ],
        ),
      ),
    );
  }
}

class _WindDownCard extends StatelessWidget {
  const _WindDownCard({required this.c});
  final SleepController c;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Wind-down', style: AqType.title(t))),
              Text('${c.stepsDone} of ${c.steps.length} done', style: AqType.caption(t)),
            ],
          ),
          const SizedBox(height: 6),
          for (final step in c.steps)
            _CheckRow(label: step.label, meta: step.meta, done: c.isDone(step.id), onTap: () => c.toggleStep(step.id)),
          if (c.windDownLive) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.phone_iphone_rounded, size: 18, color: t.lav),
                const SizedBox(width: 8),
                Expanded(child: Text('Counting down on your Lock Screen', style: AqType.caption(t))),
                TextButton(onPressed: c.endWindDown, child: Text('Stop', style: AqType.label(t, color: t.lav))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.meta, required this.done, required this.onTap});

  final String label;
  final String meta;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return Semantics(
      checked: done,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done ? t.lav : Colors.transparent,
                    shape: BoxShape.circle,
                    border: done ? null : Border.all(color: t.ink3, width: 1.5),
                  ),
                  child: done ? Icon(Icons.check_rounded, size: 16, color: t.onAccent) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: AqType.label(t, size: 14))),
                Text(meta, style: AqType.caption(t)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.c});
  final SleepController c;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = AqTokens.of(context);
    final parts = c.schedule.wake.format12().split(' ');
    final cap = c.capability;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WAKE-UP ALARM', style: AqType.eyebrow(t)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(parts.first, style: AqType.display(t, size: 48)),
                        const SizedBox(width: 6),
                        Text(parts.last, style: AqType.label(t, size: 15, color: t.ink2)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${weekdaysLabel(c.schedule.alarmWeekdays)} · Gentle wake · Snooze 9 min',
                      style: AqType.caption(t).copyWith(color: t.ink2, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              GlassSwitch(value: c.alarmOn, onChanged: c.setAlarmOn, semanticLabel: 'Wake-up alarm'),
            ],
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: t.track)),
          Row(
            children: [
              Icon(cap.ready ? Icons.verified_user_outlined : Icons.info_outline_rounded, size: 20, color: cap.ready ? t.leaf : t.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.alarmOn ? cap.statusText : 'Alarm off · nothing scheduled',
                  style: AqType.caption(t).copyWith(color: t.ink2, fontSize: 12.5),
                ),
              ),
              GlassButton(
                label: 'Test alarm',
                onPressed: () async {
                  final ok = await c.testAlarm();
                  s.showToast(ok ? 'Test alarm rings in 10 seconds' : 'Couldn\'t schedule a test alarm');
                },
              ),
            ],
          ),
          if (c.alarmOn && !cap.ready && cap.backend != AlarmBackend.none)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: s.platform.openAlarmSettings,
                child: Text('Open alarm settings', style: AqType.label(t, color: t.aqua)),
              ),
            ),
        ],
      ),
    );
  }
}

class _LastNightCard extends StatelessWidget {
  const _LastNightCard({required this.c});
  final SleepController c;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final night = c.lastNight;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Last night', style: AqType.title(t))),
              TextButton(
                onPressed: () => showLogNightSheet(context, c),
                child: Text(night == null ? 'Log it' : 'Log a night', style: AqType.label(t, color: t.aqua)),
              ),
            ],
          ),
          if (night == null)
            Text('Log when you went to bed and woke up to see your rhythm here.', style: AqType.body(t))
          else ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Bed', value: MinuteOfDay.of(night.bedtime).format12())),
                Expanded(child: _Stat(label: 'Up', value: MinuteOfDay.of(night.wokeAt).format12())),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FELT RESTED', style: AqType.eyebrow(t, size: 10)),
                      const SizedBox(height: 9),
                      _Dots(value: night.restfulness ?? 0),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Your own rating, not a medical score.', style: AqType.caption(t)),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AqType.eyebrow(t, size: 10)),
        const SizedBox(height: 4),
        Text(value, style: AqType.stat(t)),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return Semantics(
      label: '$value out of 5',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 1; i <= 5; i++)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= value ? t.lav : Colors.transparent,
                border: i <= value ? null : Border.all(color: t.lav, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showLogNightSheet(BuildContext context, SleepController c) {
  var bed = c.schedule.bedtime;
  var wake = c.schedule.wake;
  var rest = 3;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        final t = AqTokens.of(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.paddingOf(context).bottom),
          child: GlassSurface(
            weight: GlassWeight.strong,
            borderRadius: BorderRadius.circular(32),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log last night', style: AqType.display(t, size: 28)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TimeStepper(
                        label: 'Bed',
                        value: bed.format12(),
                        onMinus: () => setState(() => bed = bed - 15),
                        onPlus: () => setState(() => bed = bed + 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TimeStepper(
                        label: 'Up',
                        value: wake.format12(),
                        onMinus: () => setState(() => wake = wake - 15),
                        onPlus: () => setState(() => wake = wake + 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('How rested did you feel?', style: AqType.label(t)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Semantics(
                          button: true,
                          selected: rest == i,
                          label: '$i out of 5',
                          excludeSemantics: true,
                          child: InkResponse(
                            onTap: () => setState(() => rest = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: rest == i ? t.lav : t.glassThin,
                                border: Border.all(color: rest == i ? t.lav : t.edge),
                              ),
                              child: Text('$i', style: AqType.label(t, color: rest == i ? t.onAccent : t.ink)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                GlassButton(
                  label: 'Save',
                  weight: GlassWeight.strong,
                  expand: true,
                  height: 50,
                  onPressed: () {
                    final now = DateTime.now();
                    final wokeAt = wake.onDate(now);
                    c.logNight(SleepLog(
                      bedtime: wokeAt.subtract(Duration(minutes: bed.minutesUntil(wake))),
                      wokeAt: wokeAt,
                      restfulness: rest,
                    ));
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.c});
  final SleepController c;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final report = c.consistency;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bedtime consistency', style: AqType.title(t)),
          const SizedBox(height: 4),
          Text(
            report.nights == 0
                ? 'Log a few nights to see how close you stay to your plan.'
                : 'Within ${report.toleranceMinutes} min of your plan on ${report.withinTolerance} of the last ${report.nights} nights.',
            style: AqType.body(t).copyWith(fontSize: 13),
          ),
          if (report.nights > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 22,
                    height: 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: t.lavSoft, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final offset in report.offsets)
                        SizedBox(
                          width: 24,
                          height: 72,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 6,
                                top: (30 + offset.clamp(-80, 80) * 0.45).toDouble(),
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: offset.abs() <= report.toleranceMinutes ? t.lav : Colors.transparent,
                                    border: offset.abs() <= report.toleranceMinutes ? null : Border.all(color: t.lav, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Filled dots are inside the band. Measures only the times you logged.', style: AqType.caption(t)),
          ],
        ],
      ),
    );
  }
}
