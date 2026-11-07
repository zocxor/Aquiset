import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/time/minute_of_day.dart';
import '../hydration/domain/reminder_planner.dart';

/// System / Day / Night. Day and Night change colour tokens only.
enum ThemePref { system, day, night }

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    _theme = ThemePref.values.firstWhere((p) => p.name == _prefs.getString(_kTheme), orElse: () => ThemePref.system);
    _reduceMotion = _prefs.getBool(_kMotion) ?? false;
    _reduceTransparency = _prefs.getBool(_kTransparency) ?? false;
    _goalMl = _prefs.getInt(_kGoal) ?? 2000;
    _routineLogsPerDay = _prefs.getInt(_kRoutine) ?? 4;
    _policy = ReminderPolicy(
      enabled: _prefs.getBool(_kNudges) ?? true,
      quietStart: MinuteOfDay.wrap(_prefs.getInt(_kQuietStart) ?? 22 * 60),
      quietEnd: MinuteOfDay.wrap(_prefs.getInt(_kQuietEnd) ?? 7 * 60),
      interval: Duration(minutes: _prefs.getInt(_kInterval) ?? 90),
      cooldownAfterDrink: Duration(minutes: _prefs.getInt(_kCooldown) ?? 45),
      dailyCap: _prefs.getInt(_kCap) ?? 8,
      followsClinicianPlan: _prefs.getBool(_kClinician) ?? false,
    );
  }

  static const _kTheme = 'settings.theme';
  static const _kMotion = 'settings.reduceMotion';
  static const _kTransparency = 'settings.reduceTransparency';
  static const _kGoal = 'hydration.goalMl';
  static const _kRoutine = 'hydration.routineLogsPerDay';
  static const _kNudges = 'nudges.enabled';
  static const _kQuietStart = 'nudges.quietStart';
  static const _kQuietEnd = 'nudges.quietEnd';
  static const _kInterval = 'nudges.intervalMin';
  static const _kCooldown = 'nudges.cooldownMin';
  static const _kCap = 'nudges.dailyCap';
  static const _kClinician = 'nudges.clinicianPlan';

  final SharedPreferences _prefs;

  late ThemePref _theme;
  late bool _reduceMotion;
  late bool _reduceTransparency;
  late int _goalMl;
  late int _routineLogsPerDay;
  late ReminderPolicy _policy;

  ThemePref get theme => _theme;
  bool get reduceMotion => _reduceMotion;
  bool get reduceTransparency => _reduceTransparency;

  /// Set by the person. Never inferred, never a medical target.
  int get goalMl => _goalMl;

  /// Drinks logged at self-chosen moments that count as "routine kept".
  int get routineLogsPerDay => _routineLogsPerDay;
  ReminderPolicy get policy => _policy;

  ThemeMode get themeMode => switch (_theme) {
        ThemePref.system => ThemeMode.system,
        ThemePref.day => ThemeMode.light,
        ThemePref.night => ThemeMode.dark,
      };

  void setTheme(ThemePref value) {
    _theme = value;
    _prefs.setString(_kTheme, value.name);
    notifyListeners();
  }

  void setReduceMotion(bool value) {
    _reduceMotion = value;
    _prefs.setBool(_kMotion, value);
    notifyListeners();
  }

  void setReduceTransparency(bool value) {
    _reduceTransparency = value;
    _prefs.setBool(_kTransparency, value);
    notifyListeners();
  }

  void setGoalMl(int value) {
    _goalMl = value.clamp(250, 6000);
    _prefs.setInt(_kGoal, _goalMl);
    notifyListeners();
  }

  void setPolicy(ReminderPolicy value) {
    _policy = value;
    _prefs
      ..setBool(_kNudges, value.enabled)
      ..setInt(_kQuietStart, value.quietStart.value)
      ..setInt(_kQuietEnd, value.quietEnd.value)
      ..setInt(_kInterval, value.interval.inMinutes)
      ..setInt(_kCooldown, value.cooldownAfterDrink.inMinutes)
      ..setInt(_kCap, value.dailyCap)
      ..setBool(_kClinician, value.followsClinicianPlan);
    notifyListeners();
  }
}
