import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/time/minute_of_day.dart';
import '../../../platform/rhythm_platform.dart';
import '../../settings/settings_controller.dart';
import '../data/hydration_repository.dart';
import '../domain/drink_log.dart';
import '../domain/reminder_planner.dart';

enum RhythmDayState { kept, rest, today }

@immutable
class RhythmDay {
  const RhythmDay({required this.date, required this.state, required this.logs, required this.progress});
  final DateTime date;
  final RhythmDayState state;
  final int logs;

  /// 0–1 towards the routine target; used for today's fill only.
  final double progress;
}

class HydrationController extends ChangeNotifier {
  HydrationController({
    required this.repository,
    required this.settings,
    required this.platform,
    required SharedPreferences prefs,
    this.clock = systemClock,
  }) : _prefs = prefs {
    settings.addListener(_onSettingsChanged);
  }

  static const _kDay = 'nudges.day';
  static const _kSent = 'nudges.sentToday';
  static const _kLast = 'nudges.lastShownEpochMs';
  static const _kScheduled = 'nudges.scheduledEpochMs';

  final HydrationRepository repository;
  final SettingsController settings;
  final RhythmPlatform platform;
  final Clock clock;
  final SharedPreferences _prefs;

  List<DrinkLog> _today = const <DrinkLog>[];
  List<RhythmDay> _week = const <RhythmDay>[];
  DateTime? _snoozedUntil;

  List<DrinkLog> get today => _today;
  List<RhythmDay> get week => _week;
  int get goalMl => settings.goalMl;
  int get totalMl => _today.fold(0, (sum, l) => sum + l.amountMl);
  double get progress => goalMl <= 0 ? 0 : totalMl / goalMl;
  int get percent => (progress * 100).round();
  DrinkLog? get lastLog => _today.isEmpty ? null : _today.last;
  ReminderPolicy get policy => settings.policy;

  bool get snoozed {
    final until = _snoozedUntil;
    return until != null && until.isAfter(clock());
  }

  DateTime? get nextNudge {
    final now = clock();
    final last = _prefs.getInt(_kLast);
    return ReminderPlanner(settings.policy).next(
      now: now,
      sentToday: _prefs.getInt(_kSent) ?? 0,
      lastReminderAt: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
      lastDrinkAt: lastLog?.loggedAt,
      snoozedUntil: snoozed ? _snoozedUntil : null,
    );
  }

  /// Short reason shown under the next-nudge time.
  String get nextNudgeReason {
    if (settings.policy.followsClinicianPlan) return 'Following your clinician\'s plan';
    if (!settings.policy.enabled) return 'Nudges are off';
    if (snoozed) return 'Snoozed for 30 min';
    final last = lastLog;
    if (last != null && clock().difference(last.loggedAt) < settings.policy.cooldownAfterDrink) {
      return 'Moved back after your drink';
    }
    return 'Inside your waking hours';
  }

  Future<void> load() => _refresh();

  Future<DrinkLog> log(DrinkKind kind, {int? amountMl, LogSource source = LogSource.app}) async {
    final entry = DrinkLog.create(amountMl: amountMl ?? kind.defaultMl, kind: kind, at: clock(), source: source);
    await repository.add(entry);
    await _refresh();
    return entry;
  }

  Future<void> undo(String id) async {
    await repository.remove(id);
    await _refresh();
  }

  Future<void> toggleSnooze() async {
    _snoozedUntil = snoozed ? null : clock().add(const Duration(minutes: 30));
    notifyListeners();
    await _reschedule();
  }

  /// Pulls in drinks logged from widgets, Control Center, Siri or the watch.
  Future<int> absorbExternalLogs() async {
    final external = await platform.drainExternalLogs();
    for (final log in external) {
      await repository.add(log);
    }
    if (external.isNotEmpty) await _refresh();
    return external.length;
  }

  Future<void> _refresh() async {
    final now = clock();
    _today = (await repository.logsOn(now))..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

    final start = DateTime(now.year, now.month, now.day - 6);
    final range = await repository.logsBetween(start, DateTime(now.year, now.month, now.day + 1));
    final target = settings.routineLogsPerDay;
    _week = List<RhythmDay>.generate(7, (i) {
      final date = DateTime(start.year, start.month, start.day + i);
      final count = range.where((l) => _sameDate(l.loggedAt, date)).length;
      final isToday = i == 6;
      return RhythmDay(
        date: date,
        logs: count,
        progress: target == 0 ? 1 : (count / target).clamp(0.0, 1.0),
        state: count >= target ? RhythmDayState.kept : (isToday ? RhythmDayState.today : RhythmDayState.rest),
      );
    });

    _rollReminderState(now);
    notifyListeners();
    await _reschedule();
  }

  /// A nudge scheduled in the past has been shown: count it for today's cap
  /// and use it as the anchor for the next interval.
  void _rollReminderState(DateTime now) {
    final dayKey = '${now.year}-${now.month}-${now.day}';
    if (_prefs.getString(_kDay) != dayKey) {
      _prefs
        ..setString(_kDay, dayKey)
        ..setInt(_kSent, 0);
    }
    final scheduled = _prefs.getInt(_kScheduled);
    if (scheduled == null) return;
    final at = DateTime.fromMillisecondsSinceEpoch(scheduled);
    if (at.isAfter(now)) return;
    if (_sameDate(at, now)) _prefs.setInt(_kSent, (_prefs.getInt(_kSent) ?? 0) + 1);
    _prefs
      ..setInt(_kLast, scheduled)
      ..remove(_kScheduled);
  }

  Future<void> _reschedule() async {
    await platform.cancelNudges();
    final at = nextNudge;
    if (at == null) {
      await _prefs.remove(_kScheduled);
      return;
    }
    await platform.scheduleNudge(at, body: 'A few sips whenever it suits you.');
    await _prefs.setInt(_kScheduled, at.millisecondsSinceEpoch);
  }

  void _onSettingsChanged() {
    notifyListeners();
    _reschedule();
  }

  static bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
