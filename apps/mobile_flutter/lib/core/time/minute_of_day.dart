import 'package:flutter/foundation.dart';

/// A wall-clock time inside one day, 0 (midnight) to 1439 (23:59).
///
/// All schedule maths (waking windows, quiet hours, bedtime) runs on this type
/// so it can wrap around midnight without date arithmetic.
@immutable
class MinuteOfDay implements Comparable<MinuteOfDay> {
  const MinuteOfDay(this.value) : assert(value >= 0 && value < minutesPerDay);

  factory MinuteOfDay.hm(int hour, int minute) => MinuteOfDay.wrap(hour * 60 + minute);

  /// Normalises any integer (negative or above a day) into 0..1439.
  factory MinuteOfDay.wrap(int minutes) =>
      MinuteOfDay(((minutes % minutesPerDay) + minutesPerDay) % minutesPerDay);

  factory MinuteOfDay.of(DateTime t) => MinuteOfDay(t.hour * 60 + t.minute);

  static const int minutesPerDay = 1440;

  final int value;

  int get hour => value ~/ 60;
  int get minute => value % 60;

  MinuteOfDay operator +(int minutes) => MinuteOfDay.wrap(value + minutes);
  MinuteOfDay operator -(int minutes) => MinuteOfDay.wrap(value - minutes);

  /// Minutes going forward from this time until [other], 0..1439.
  int minutesUntil(MinuteOfDay other) =>
      (other.value - value + minutesPerDay) % minutesPerDay;

  /// Signed shortest distance from this time to [other], in (-720, 720].
  int signedOffsetTo(MinuteOfDay other) {
    final forward = minutesUntil(other);
    return forward > minutesPerDay ~/ 2 ? forward - minutesPerDay : forward;
  }

  /// True when this time falls inside [start, end). Handles windows that
  /// cross midnight, such as quiet hours 22:00–07:00. An empty window
  /// (start == end) contains nothing.
  bool isWithin(MinuteOfDay start, MinuteOfDay end) {
    if (start.value == end.value) return false;
    if (start.value < end.value) return value >= start.value && value < end.value;
    return value >= start.value || value < end.value;
  }

  /// The [DateTime] on the same local date as [day] at this time.
  DateTime onDate(DateTime day) => DateTime(day.year, day.month, day.day, hour, minute);

  /// The next wall-clock occurrence of this time strictly after [now].
  DateTime nextAfter(DateTime now) {
    final today = onDate(now);
    return today.isAfter(now) ? today : DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  /// 12-hour label such as "6:45 am".
  String format12() {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final mm = minute.toString().padLeft(2, '0');
    return '$h:$mm ${hour < 12 ? 'am' : 'pm'}';
  }

  @override
  int compareTo(MinuteOfDay other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is MinuteOfDay && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MinuteOfDay(${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')})';
}

/// Injectable clock so reminder and sleep logic is testable.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();
