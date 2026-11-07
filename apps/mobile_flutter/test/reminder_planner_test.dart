import 'package:aquiset/features/hydration/domain/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rules from blueprint section 05: waking window only, cooldown after a
/// drink, respect snooze and quiet hours, daily cap, no escalation.
void main() {
  // Waking 07:00–23:00, quiet 22:00–07:00, every 90 min, 45 min after a drink, cap 8.
  const planner = ReminderPlanner(ReminderPolicy());
  DateTime at(int h, int m, {int day = 6}) => DateTime(2026, 11, day, h, m);

  test('next nudge is one interval after the last one', () {
    expect(
      planner.next(now: at(10, 0), sentToday: 2, lastReminderAt: at(9, 30)),
      at(11, 0),
    );
  });

  test('a drink pushes the next nudge back by the cooldown', () {
    final next = planner.next(
      now: at(10, 40),
      sentToday: 2,
      lastReminderAt: at(9, 30),
      lastDrinkAt: at(10, 30),
    );
    expect(next, at(11, 15));
  });

  test('snooze is respected', () {
    final next = planner.next(
      now: at(10, 0),
      sentToday: 1,
      lastReminderAt: at(8, 0),
      snoozedUntil: at(10, 30),
    );
    expect(next, at(10, 30));
  });

  test('never lands in quiet hours; moves to when they end', () {
    final next = planner.next(
      now: at(21, 30),
      sentToday: 3,
      lastReminderAt: at(21, 0),
    );
    expect(next, at(7, 0, day: 7));
  });

  test('before the waking window, waits for it to open', () {
    expect(planner.next(now: at(5, 0), sentToday: 0), at(7, 0));
  });

  test('daily cap stops nudges until tomorrow', () {
    expect(planner.next(now: at(12, 0), sentToday: 8), at(7, 0, day: 7));
  });

  test('ignored nudges never escalate: spacing stays one interval', () {
    final first = planner.next(
      now: at(13, 0),
      sentToday: 3,
      lastReminderAt: at(12, 0),
    )!;
    final second = planner.next(
      now: first,
      sentToday: 4,
      lastReminderAt: first,
    )!;
    expect(first, at(13, 30));
    expect(second.difference(first), const ReminderPolicy().interval);
  });

  test('clinician-managed fluids switch generic nudges off', () {
    const managed = ReminderPlanner(ReminderPolicy(followsClinicianPlan: true));
    expect(managed.next(now: at(10, 0), sentToday: 0), isNull);
  });

  test('disabled nudges return null', () {
    const off = ReminderPlanner(ReminderPolicy(enabled: false));
    expect(off.next(now: at(10, 0), sentToday: 0), isNull);
  });

  test('rounds up to the next whole minute', () {
    expect(
      planner.next(now: DateTime(2026, 11, 6, 10, 0, 30), sentToday: 0),
      at(10, 1),
    );
  });
}
