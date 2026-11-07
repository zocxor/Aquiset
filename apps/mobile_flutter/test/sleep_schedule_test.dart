import 'package:aquiset/core/time/minute_of_day.dart';
import 'package:aquiset/features/sleep/domain/sleep_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final schedule = SleepSchedule(bedtime: MinuteOfDay.hm(23, 0), wake: MinuteOfDay.hm(6, 45));

  test('planned rest crosses midnight', () {
    expect(schedule.plannedRest, const Duration(hours: 7, minutes: 45));
  });

  test('wind-down starts 30 minutes before bed', () {
    expect(schedule.windDownStart, MinuteOfDay.hm(22, 30));
  });

  test('shifting wraps around midnight', () {
    final later = schedule.shifted(bedtimeBy: 75);
    expect(later.bedtime, MinuteOfDay.hm(0, 15));
    expect(later.plannedRest, const Duration(hours: 6, minutes: 30));
  });

  test('shifts that would make rest under 4 h or over 12 h are ignored', () {
    final short = SleepSchedule(bedtime: MinuteOfDay.hm(2, 30), wake: MinuteOfDay.hm(6, 45));
    expect(identical(short.shifted(bedtimeBy: 30), short), isTrue);
    final long = SleepSchedule(bedtime: MinuteOfDay.hm(19, 0), wake: MinuteOfDay.hm(6, 45));
    expect(identical(long.shifted(bedtimeBy: -30), long), isTrue);
  });

  test('signed offsets take the short way round the clock', () {
    final plan = MinuteOfDay.hm(23, 0);
    expect(plan.signedOffsetTo(MinuteOfDay.hm(0, 20)), 80);
    expect(plan.signedOffsetTo(MinuteOfDay.hm(22, 50)), -10);
  });

  test('consistency counts only nights within the tolerance', () {
    DateTime bed(int day, int h, int m) => DateTime(2026, 11, day, h, m);
    final logs = [
      SleepLog(bedtime: bed(1, 22, 50), wokeAt: bed(2, 6, 40)),
      SleepLog(bedtime: bed(2, 23, 40), wokeAt: bed(3, 6, 50)),
      SleepLog(bedtime: bed(4, 0, 10), wokeAt: bed(4, 7, 0)),
      SleepLog(bedtime: bed(4, 23, 15), wokeAt: bed(5, 6, 45)),
    ];
    final report = bedtimeConsistency(logs, MinuteOfDay.hm(23, 0));
    expect(report.offsets, [-10, 40, 70, 15]);
    expect(report.withinTolerance, 2);
    expect(report.nights, 4);
  });

  test('quiet-hours window crossing midnight', () {
    final start = MinuteOfDay.hm(22, 0);
    final end = MinuteOfDay.hm(7, 0);
    expect(MinuteOfDay.hm(23, 30).isWithin(start, end), isTrue);
    expect(MinuteOfDay.hm(6, 59).isWithin(start, end), isTrue);
    expect(MinuteOfDay.hm(7, 0).isWithin(start, end), isFalse);
    expect(MinuteOfDay.hm(12, 0).isWithin(start, end), isFalse);
  });

  test('json round trip', () {
    final back = SleepSchedule.fromJson(schedule.toJson());
    expect(back.bedtime, schedule.bedtime);
    expect(back.wake, schedule.wake);
    expect(back.alarmWeekdays, schedule.alarmWeekdays);
  });
}
