import 'package:flutter/foundation.dart';

import '../../../core/time/minute_of_day.dart';

/// The person's chosen bedtime and wake time. Routine support only: no
/// sleep stages, scores or clinical measures.
@immutable
class SleepSchedule {
  const SleepSchedule({
    required this.bedtime,
    required this.wake,
    this.windDown = const Duration(minutes: 30),
    this.alarmWeekdays = const {1, 2, 3, 4, 5},
  });

  factory SleepSchedule.fromJson(Map<String, dynamic> json) => SleepSchedule(
    bedtime: MinuteOfDay.wrap((json['bedtime'] as num).toInt()),
    wake: MinuteOfDay.wrap((json['wake'] as num).toInt()),
    windDown: Duration(minutes: (json['wind_down_min'] as num?)?.toInt() ?? 30),
    alarmWeekdays:
        ((json['alarm_weekdays'] as List<dynamic>?) ??
                const <dynamic>[1, 2, 3, 4, 5])
            .map((e) => (e as num).toInt())
            .toSet(),
  );

  static const Duration minRest = Duration(hours: 4);
  static const Duration maxRest = Duration(hours: 12);

  final MinuteOfDay bedtime;
  final MinuteOfDay wake;
  final Duration windDown;

  /// ISO weekdays (1 = Monday … 7 = Sunday) on which the wake alarm rings.
  final Set<int> alarmWeekdays;

  Duration get plannedRest => Duration(minutes: bedtime.minutesUntil(wake));

  MinuteOfDay get windDownStart => bedtime - windDown.inMinutes;

  /// Moves bedtime and/or wake. Ignores a change that would make planned rest
  /// shorter than 4 h or longer than 12 h.
  SleepSchedule shifted({int bedtimeBy = 0, int wakeBy = 0}) {
    final next = copyWith(bedtime: bedtime + bedtimeBy, wake: wake + wakeBy);
    final rest = next.plannedRest;
    return (rest < minRest || rest > maxRest) ? this : next;
  }

  SleepSchedule copyWith({
    MinuteOfDay? bedtime,
    MinuteOfDay? wake,
    Duration? windDown,
    Set<int>? alarmWeekdays,
  }) => SleepSchedule(
    bedtime: bedtime ?? this.bedtime,
    wake: wake ?? this.wake,
    windDown: windDown ?? this.windDown,
    alarmWeekdays: alarmWeekdays ?? this.alarmWeekdays,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'bedtime': bedtime.value,
    'wake': wake.value,
    'wind_down_min': windDown.inMinutes,
    'alarm_weekdays': alarmWeekdays.toList()..sort(),
  };
}

/// One night the person logged. [restfulness] is their own 1–5 rating.
@immutable
class SleepLog {
  const SleepLog({
    required this.bedtime,
    required this.wokeAt,
    this.restfulness,
  });

  final DateTime bedtime;
  final DateTime wokeAt;
  final int? restfulness;

  Duration get timeInBed => wokeAt.difference(bedtime);
}

@immutable
class ConsistencyReport {
  const ConsistencyReport({
    required this.offsets,
    required this.toleranceMinutes,
  });

  /// Signed minutes from the planned bedtime, one per logged night.
  final List<int> offsets;
  final int toleranceMinutes;

  int get nights => offsets.length;
  int get withinTolerance =>
      offsets.where((o) => o.abs() <= toleranceMinutes).length;
}

/// How many logged bedtimes fell within ±[toleranceMinutes] of the plan.
/// Measures only what was logged; it is not a sleep-quality score.
ConsistencyReport bedtimeConsistency(
  Iterable<SleepLog> logs,
  MinuteOfDay plannedBedtime, {
  int toleranceMinutes = 30,
}) => ConsistencyReport(
  offsets:
      logs
          .map((l) => plannedBedtime.signedOffsetTo(MinuteOfDay.of(l.bedtime)))
          .toList(),
  toleranceMinutes: toleranceMinutes,
);
