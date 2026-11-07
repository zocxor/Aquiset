import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/time/minute_of_day.dart';
import '../../../platform/rhythm_platform.dart';
import '../domain/sleep_schedule.dart';

typedef WindDownStep = ({String id, String label, String meta});

class SleepController extends ChangeNotifier {
  SleepController({
    required SharedPreferences prefs,
    required this.platform,
    this.clock = systemClock,
  }) : _prefs = prefs {
    final raw = _prefs.getString(_kSchedule);
    if (raw != null)
      _schedule = SleepSchedule.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    _alarmOn = _prefs.getBool(_kAlarm) ?? true;
    final logs = _prefs.getString(_kLogs);
    if (logs != null) {
      _logs =
          (jsonDecode(logs) as List<dynamic>).map((e) {
            final m = e as Map<String, dynamic>;
            return SleepLog(
              bedtime: DateTime.fromMillisecondsSinceEpoch(
                (m['bed'] as num).toInt(),
              ),
              wokeAt: DateTime.fromMillisecondsSinceEpoch(
                (m['woke'] as num).toInt(),
              ),
              restfulness: (m['rest'] as num?)?.toInt(),
            );
          }).toList();
    }
  }

  static const _kSchedule = 'sleep.schedule.v1';
  static const _kAlarm = 'sleep.alarmOn';
  static const _kLogs = 'sleep.logs.v1';
  static const String wakeAlarmId = 'wake';

  final RhythmPlatform platform;
  final Clock clock;
  final SharedPreferences _prefs;

  SleepSchedule _schedule = SleepSchedule(
    bedtime: MinuteOfDay.hm(23, 0),
    wake: MinuteOfDay.hm(6, 45),
  );
  bool _alarmOn = true;
  AlarmCapability _capability = AlarmCapability.unavailable;
  List<SleepLog> _logs = <SleepLog>[];
  final Set<String> _stepsDone = <String>{};
  bool _windDownLive = false;

  SleepSchedule get schedule => _schedule;
  bool get alarmOn => _alarmOn;
  AlarmCapability get capability => _capability;
  bool get windDownLive => _windDownLive;
  SleepLog? get lastNight => _logs.isEmpty ? null : _logs.last;

  List<WindDownStep> get steps => <WindDownStep>[
    (
      id: 'lights',
      label: 'Dim the lights',
      meta: _schedule.windDownStart.format12(),
    ),
    (id: 'tomorrow', label: 'Set out tomorrow', meta: '2 min'),
    (id: 'read', label: 'Quiet reading', meta: '10 min'),
    (id: 'breathe', label: 'Slow breathing', meta: '3 min'),
  ];

  bool isDone(String id) => _stepsDone.contains(id);
  int get stepsDone => _stepsDone.length;

  ConsistencyReport get consistency => bedtimeConsistency(
    _logs.length > 7 ? _logs.sublist(_logs.length - 7) : _logs,
    _schedule.bedtime,
  );

  Future<void> load() async {
    _capability = await platform.alarmCapability();
    if (_alarmOn) await _syncAlarm();
    notifyListeners();
  }

  /// Re-read permission state when the app returns to the foreground, since
  /// the person may have changed it in system settings.
  Future<void> refreshCapability() async {
    _capability = await platform.alarmCapability();
    notifyListeners();
  }

  Future<void> shiftBedtime(int minutes) =>
      _setSchedule(_schedule.shifted(bedtimeBy: minutes));

  Future<void> shiftWake(int minutes) =>
      _setSchedule(_schedule.shifted(wakeBy: minutes));

  Future<void> setAlarmOn(bool on) async {
    if (on && !_capability.authorized && _capability.canRequest) {
      _capability = await platform.requestAlarmPermission();
    }
    _alarmOn = on;
    await _prefs.setBool(_kAlarm, on);
    await _syncAlarm();
    notifyListeners();
  }

  Future<bool> testAlarm() => platform.scheduleTestAlarm();

  Future<void> toggleStep(String id) async {
    if (!_stepsDone.remove(id)) _stepsDone.add(id);
    notifyListeners();
    if (_stepsDone.isNotEmpty && !_windDownLive) {
      await startWindDown();
    } else if (_windDownLive) {
      await platform.updateWindDown(_session());
    }
  }

  /// Starts the wind-down Live Activity / Live Update: a countdown to bedtime
  /// and wake that sits on the Lock Screen, Dynamic Island or status bar.
  Future<void> startWindDown() async {
    _windDownLive = await platform.startWindDown(_session());
    notifyListeners();
  }

  Future<void> endWindDown() async {
    await platform.endWindDown();
    _windDownLive = false;
    notifyListeners();
  }

  Future<void> logNight(SleepLog log) async {
    _logs = [..._logs, log];
    if (_logs.length > 60) _logs = _logs.sublist(_logs.length - 60);
    await _prefs.setString(
      _kLogs,
      jsonEncode(
        _logs
            .map(
              (l) => <String, Object?>{
                'bed': l.bedtime.millisecondsSinceEpoch,
                'woke': l.wokeAt.millisecondsSinceEpoch,
                'rest': l.restfulness,
              },
            )
            .toList(),
      ),
    );
    notifyListeners();
  }

  WindDownSession _session() {
    final now = clock();
    final bed = _schedule.bedtime.nextAfter(
      now.subtract(const Duration(hours: 2)),
    );
    return WindDownSession(
      bedtime: bed,
      wake: _schedule.wake.nextAfter(bed),
      stepsDone: _stepsDone.length,
      stepsTotal: steps.length,
    );
  }

  Future<void> _setSchedule(SleepSchedule next) async {
    if (identical(next, _schedule)) return;
    _schedule = next;
    await _prefs.setString(_kSchedule, jsonEncode(next.toJson()));
    notifyListeners();
    await _syncAlarm();
  }

  Future<void> _syncAlarm() async {
    if (!_alarmOn) {
      await platform.cancelAlarm(wakeAlarmId);
      return;
    }
    await platform.scheduleAlarm(
      AlarmSpec(
        id: wakeAlarmId,
        hour: _schedule.wake.hour,
        minute: _schedule.wake.minute,
        weekdays: _schedule.alarmWeekdays,
      ),
    );
  }
}
