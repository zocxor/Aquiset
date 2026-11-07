import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/hydration/domain/drink_log.dart';

/// Which native alarm engine is active on this device.
enum AlarmBackend {
  /// iOS 26+: real alarms that break through silent mode and Focus.
  alarmKit,

  /// Older iOS: time-sensitive local notifications (can be silenced).
  notifications,

  /// Android: AlarmManager.setAlarmClock with an alarm-usage channel.
  alarmManager,

  /// Unsupported platform or no native bridge (tests, desktop).
  none,
}

@immutable
class AlarmCapability {
  const AlarmCapability({
    required this.backend,
    required this.authorized,
    required this.exactAllowed,
    required this.canRequest,
  });

  factory AlarmCapability.fromMap(Map<Object?, Object?>? m) {
    if (m == null) return unavailable;
    return AlarmCapability(
      backend: AlarmBackend.values.firstWhere((b) => b.name == m['backend'], orElse: () => AlarmBackend.none),
      authorized: m['authorized'] == true,
      exactAllowed: m['exactAllowed'] == true,
      canRequest: m['canRequest'] == true,
    );
  }

  static const AlarmCapability unavailable =
      AlarmCapability(backend: AlarmBackend.none, authorized: false, exactAllowed: false, canRequest: false);

  final AlarmBackend backend;
  final bool authorized;
  final bool exactAllowed;
  final bool canRequest;

  bool get ready => authorized && exactAllowed && backend != AlarmBackend.none;

  /// Honest one-line status for the alarm card (blueprint section 06).
  String get statusText => switch (backend) {
        AlarmBackend.none => 'Alarms aren\'t available on this device',
        _ when !authorized => 'Alarm permission is off · tap to allow',
        AlarmBackend.alarmManager when !exactAllowed => 'Exact alarms are off · may ring late',
        AlarmBackend.notifications => 'Rings as a notification · silent mode can mute it',
        _ => 'Alarm allowed · rings without internet',
      };
}

@immutable
class AlarmSpec {
  const AlarmSpec({
    required this.id,
    required this.hour,
    required this.minute,
    required this.weekdays,
    this.label = 'Good morning',
    this.snoozeMinutes = 9,
    this.vibrate = true,
    this.sound = 'gentle_rise',
  });

  final String id;
  final int hour;
  final int minute;

  /// ISO weekdays, 1 = Monday. Empty means one-time.
  final Set<int> weekdays;
  final String label;
  final int snoozeMinutes;
  final bool vibrate;
  final String sound;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays.toList()..sort(),
        'label': label,
        'snoozeMinutes': snoozeMinutes,
        'vibrate': vibrate,
        'sound': sound,
      };
}

/// What the home and lock screen widgets, the watch and Control Center show.
/// Written to the App Group (iOS) or widget SharedPreferences (Android).
@immutable
class RhythmSnapshot {
  const RhythmSnapshot({
    required this.totalMl,
    required this.goalMl,
    required this.drinksToday,
    required this.nextNudge,
    required this.bedtimeLabel,
    required this.wakeLabel,
    required this.windDownLabel,
    required this.alarmOn,
    required this.night,
    required this.updatedAt,
  });

  final int totalMl;
  final int goalMl;
  final int drinksToday;
  final DateTime? nextNudge;
  final String bedtimeLabel;
  final String wakeLabel;
  final String windDownLabel;
  final bool alarmOn;
  final bool night;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => <String, Object?>{
        'totalMl': totalMl,
        'goalMl': goalMl,
        'drinksToday': drinksToday,
        'nextNudgeEpochMs': nextNudge?.millisecondsSinceEpoch,
        'bedtimeLabel': bedtimeLabel,
        'wakeLabel': wakeLabel,
        'windDownLabel': windDownLabel,
        'alarmOn': alarmOn,
        'night': night,
        'updatedEpochMs': updatedAt.millisecondsSinceEpoch,
      };
}

/// Inputs for the wind-down Live Activity (iOS) / Live Update (Android).
@immutable
class WindDownSession {
  const WindDownSession({required this.bedtime, required this.wake, required this.stepsDone, required this.stepsTotal});

  final DateTime bedtime;
  final DateTime wake;
  final int stepsDone;
  final int stepsTotal;

  Map<String, Object?> toMap() => <String, Object?>{
        'bedtimeEpochMs': bedtime.millisecondsSinceEpoch,
        'wakeEpochMs': wake.millisecondsSinceEpoch,
        'stepsDone': stepsDone,
        'stepsTotal': stepsTotal,
      };
}

/// Something the person started outside the app: a widget button, Control
/// Center, Siri, an app shortcut or the watch.
sealed class PlatformAction {
  const PlatformAction();

  static PlatformAction? parse(Object? raw) {
    if (raw is! Map) return null;
    return switch (raw['type']) {
      'logDrink' => LogDrinkAction(
          (raw['ml'] as num?)?.toInt() ?? DrinkKind.glass.defaultMl,
          LogSource.values.firstWhere((s) => s.name == raw['source'], orElse: () => LogSource.shortcut),
        ),
      'startWindDown' => const StartWindDownAction(),
      'open' => OpenTabAction(raw['tab'] as String? ?? 'hydrate'),
      _ => null,
    };
  }
}

final class LogDrinkAction extends PlatformAction {
  const LogDrinkAction(this.ml, this.source);
  final int ml;
  final LogSource source;
}

final class StartWindDownAction extends PlatformAction {
  const StartWindDownAction();
}

final class OpenTabAction extends PlatformAction {
  const OpenTabAction(this.tab);
  final String tab;
}

/// The one typed bridge between Dart and AQUISET's native code
/// (channel `aquiset/platform`). Every call degrades safely when the native
/// side is missing, so tests and unsupported platforms keep working, and
/// alarms never depend on the backend or AI services.
class RhythmPlatform {
  RhythmPlatform({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('aquiset/platform') {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  final MethodChannel _channel;
  final StreamController<PlatformAction> _actions = StreamController<PlatformAction>.broadcast();
  final StreamController<void> _externalLogs = StreamController<void>.broadcast();

  /// Actions delivered while the app is running.
  Stream<PlatformAction> get actions => _actions.stream;

  /// Fires when a widget, Control Center, Siri or the watch logged a drink
  /// while the app is open, so the dashboard updates without a restart.
  Stream<void> get externalLogsAvailable => _externalLogs.stream;

  // ── Alarms ────────────────────────────────────────────────────────────

  Future<AlarmCapability> alarmCapability() async =>
      AlarmCapability.fromMap(await _call<Map<Object?, Object?>>('alarm.capability'));

  Future<AlarmCapability> requestAlarmPermission() async =>
      AlarmCapability.fromMap(await _call<Map<Object?, Object?>>('alarm.requestPermission'));

  Future<bool> scheduleAlarm(AlarmSpec spec) async => await _call<bool>('alarm.schedule', spec.toMap()) ?? false;

  Future<void> cancelAlarm(String id) => _call<void>('alarm.cancel', <String, Object?>{'id': id});

  /// Rings once after [delay] so the person can hear and check the alarm.
  Future<bool> scheduleTestAlarm({Duration delay = const Duration(seconds: 10)}) async =>
      await _call<bool>('alarm.test', <String, Object?>{'seconds': delay.inSeconds}) ?? false;

  /// Opens the system screen for exact alarms (Android) or app settings (iOS).
  Future<void> openAlarmSettings() => _call<void>('alarm.openSettings');

  // ── Hydration nudges (local notifications, never remote) ─────────────

  Future<void> scheduleNudge(DateTime at, {required String body}) => _call<void>(
        'nudge.schedule',
        <String, Object?>{'epochMs': at.millisecondsSinceEpoch, 'title': 'A gentle nudge', 'body': body},
      );

  Future<void> cancelNudges() => _call<void>('nudge.cancelAll');

  // ── Widgets, Control Center, watch ───────────────────────────────────

  Future<void> publishSnapshot(RhythmSnapshot snapshot) => _call<void>('widgets.publish', snapshot.toMap());

  /// Logs made from widgets, Control Center, Siri or the watch while the app
  /// was closed. Each is returned once and then cleared natively.
  Future<List<DrinkLog>> drainExternalLogs() async {
    final raw = await _call<List<Object?>>('widgets.drainLogs') ?? const <Object?>[];
    return raw.whereType<Map<Object?, Object?>>().map((m) {
      return DrinkLog(
        id: m['id'] as String? ?? newClientId(),
        amountMl: (m['ml'] as num?)?.toInt() ?? DrinkKind.glass.defaultMl,
        kind: DrinkKind.parse(m['kind'] as String?),
        loggedAt: DateTime.fromMillisecondsSinceEpoch((m['epochMs'] as num?)?.toInt() ?? 0),
        source: LogSource.values.firstWhere((s) => s.name == m['source'], orElse: () => LogSource.widget),
      );
    }).toList();
  }

  // ── Live Activity / Live Update ──────────────────────────────────────

  Future<bool> startWindDown(WindDownSession session) async =>
      await _call<bool>('live.start', session.toMap()) ?? false;

  Future<void> updateWindDown(WindDownSession session) => _call<void>('live.update', session.toMap());

  Future<void> endWindDown() => _call<void>('live.end');

  // ── Launch ────────────────────────────────────────────────────────────

  /// The action that cold-started the app (shortcut, widget tap), if any.
  Future<PlatformAction?> takeLaunchAction() async => PlatformAction.parse(await _call<Object?>('launch.take'));

  Future<Object?> _onNativeCall(MethodCall call) async {
    if (call.method == 'action') {
      final action = PlatformAction.parse(call.arguments);
      if (action != null) _actions.add(action);
    } else if (call.method == 'externalLogsAvailable') {
      _externalLogs.add(null);
    }
    return null;
  }

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('aquiset/platform $method failed: ${e.code} ${e.message}');
      return null;
    }
  }

  void dispose() {
    _actions.close();
    _externalLogs.close();
  }
}
