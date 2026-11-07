import 'package:flutter/foundation.dart';

import '../../../core/time/minute_of_day.dart';

/// The person's reminder choices. Defaults are deliberately conservative.
@immutable
class ReminderPolicy {
  const ReminderPolicy({
    this.enabled = true,
    this.wakeStart = const MinuteOfDay(7 * 60),
    this.wakeEnd = const MinuteOfDay(23 * 60),
    this.quietStart = const MinuteOfDay(22 * 60),
    this.quietEnd = const MinuteOfDay(7 * 60),
    this.interval = const Duration(minutes: 90),
    this.cooldownAfterDrink = const Duration(minutes: 45),
    this.dailyCap = 8,
    this.followsClinicianPlan = false,
  }) : assert(dailyCap >= 0);

  final bool enabled;

  /// Nudges only ever land inside [wakeStart, wakeEnd).
  final MinuteOfDay wakeStart;
  final MinuteOfDay wakeEnd;

  /// No routine nudges inside [quietStart, quietEnd). May cross midnight.
  final MinuteOfDay quietStart;
  final MinuteOfDay quietEnd;

  /// Fixed spacing between nudges. Never shortened when nudges are ignored.
  final Duration interval;

  /// After any drink, wait at least this long before the next nudge.
  final Duration cooldownAfterDrink;

  /// Maximum nudges per calendar day.
  final int dailyCap;

  /// The person told us a clinician manages their fluids. Generic nudges
  /// are switched off entirely; logging still works.
  final bool followsClinicianPlan;

  ReminderPolicy copyWith({
    bool? enabled,
    MinuteOfDay? quietStart,
    MinuteOfDay? quietEnd,
    Duration? interval,
    Duration? cooldownAfterDrink,
    int? dailyCap,
    bool? followsClinicianPlan,
  }) => ReminderPolicy(
    enabled: enabled ?? this.enabled,
    wakeStart: wakeStart,
    wakeEnd: wakeEnd,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    interval: interval ?? this.interval,
    cooldownAfterDrink: cooldownAfterDrink ?? this.cooldownAfterDrink,
    dailyCap: dailyCap ?? this.dailyCap,
    followsClinicianPlan: followsClinicianPlan ?? this.followsClinicianPlan,
  );
}

/// Pure scheduling rules from the blueprint (section 05, "Reminder logic"):
/// waking window only, cooldown after a drink, respect snooze and quiet
/// hours, a daily cap, and no escalation when the person doesn't respond.
class ReminderPlanner {
  const ReminderPlanner(this.policy);

  final ReminderPolicy policy;

  static const Duration _horizon = Duration(days: 2);

  /// The next moment a gentle nudge may be shown, or null if none should be.
  ///
  /// [sentToday] counts nudges already shown on [now]'s calendar day.
  DateTime? next({
    required DateTime now,
    required int sentToday,
    DateTime? lastReminderAt,
    DateTime? lastDrinkAt,
    DateTime? snoozedUntil,
  }) {
    if (!policy.enabled || policy.followsClinicianPlan) return null;

    var candidate = _ceilToMinute(now);
    if (lastReminderAt != null)
      candidate = _later(candidate, lastReminderAt.add(policy.interval));
    if (lastDrinkAt != null)
      candidate = _later(candidate, lastDrinkAt.add(policy.cooldownAfterDrink));
    if (snoozedUntil != null) candidate = _later(candidate, snoozedUntil);
    candidate = _ceilToMinute(candidate);

    final limit = now.add(_horizon);
    while (!candidate.isAfter(limit)) {
      if (!_allowed(candidate)) {
        candidate = _advance(candidate);
        continue;
      }
      if (_sameDate(candidate, now) && sentToday >= policy.dailyCap) {
        // Today's cap is used up: nothing more today.
        candidate = DateTime(now.year, now.month, now.day + 1);
        continue;
      }
      return candidate;
    }
    return null;
  }

  bool _allowed(DateTime t) {
    final m = MinuteOfDay.of(t);
    return m.isWithin(policy.wakeStart, policy.wakeEnd) &&
        !m.isWithin(policy.quietStart, policy.quietEnd);
  }

  /// Jumps to the next boundary that could be allowed, in wall-clock time so
  /// daylight-saving changes don't shift the target.
  DateTime _advance(DateTime t) {
    final m = MinuteOfDay.of(t);
    final target =
        m.isWithin(policy.wakeStart, policy.wakeEnd)
            ? policy.quietEnd
            : policy.wakeStart;
    final minutes = m.minutesUntil(target);
    return DateTime(
      t.year,
      t.month,
      t.day,
      t.hour,
      t.minute + (minutes == 0 ? 1 : minutes),
    );
  }

  static DateTime _later(DateTime a, DateTime b) => b.isAfter(a) ? b : a;

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _ceilToMinute(DateTime t) {
    if (t.second == 0 && t.millisecond == 0 && t.microsecond == 0) return t;
    return DateTime(t.year, t.month, t.day, t.hour, t.minute + 1);
  }
}
