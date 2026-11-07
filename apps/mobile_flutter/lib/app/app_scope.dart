import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/hydration/application/hydration_controller.dart';
import '../features/hydration/data/hydration_repository.dart';
import '../features/hydration/domain/drink_log.dart';
import '../features/settings/settings_controller.dart';
import '../features/sleep/application/sleep_controller.dart';
import '../platform/rhythm_platform.dart';

enum AppTab { hydrate, sleep, rituals, you }

@immutable
class ToastData {
  const ToastData(this.message, {this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Everything the UI needs, created once at launch.
class AppServices {
  AppServices._({
    required this.prefs,
    required this.platform,
    required this.settings,
    required this.hydration,
    required this.sleep,
  });

  final SharedPreferences prefs;
  final RhythmPlatform platform;
  final SettingsController settings;
  final HydrationController hydration;
  final SleepController sleep;

  final ValueNotifier<AppTab> tab = ValueNotifier<AppTab>(AppTab.hydrate);
  final ValueNotifier<ToastData?> toast = ValueNotifier<ToastData?>(null);

  Timer? _toastTimer;
  Timer? _snapshotDebounce;
  StreamSubscription<PlatformAction>? _actionSub;
  StreamSubscription<void>? _externalSub;
  AppLifecycleListener? _lifecycle;

  static Future<AppServices> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final platform = RhythmPlatform();
    final settings = SettingsController(prefs);
    final services = AppServices._(
      prefs: prefs,
      platform: platform,
      settings: settings,
      hydration: HydrationController(
        repository: PrefsHydrationRepository(prefs),
        settings: settings,
        platform: platform,
        prefs: prefs,
      ),
      sleep: SleepController(prefs: prefs, platform: platform),
    );
    await services._start();
    return services;
  }

  Future<void> _start() async {
    await hydration.load();
    await hydration.absorbExternalLogs();
    await sleep.load();

    for (final source in <Listenable>[hydration, sleep, settings]) {
      source.addListener(_scheduleSnapshot);
    }
    _scheduleSnapshot();

    _actionSub = platform.actions.listen(handleAction);
    _externalSub = platform.externalLogsAvailable.listen(
      (_) => hydration.absorbExternalLogs(),
    );
    final launch = await platform.takeLaunchAction();
    if (launch != null) await handleAction(launch);

    _lifecycle = AppLifecycleListener(
      onResume: () async {
        final added = await hydration.absorbExternalLogs();
        if (added > 0)
          showToast(
            'Added $added ${added == 1 ? 'drink' : 'drinks'} from your widget',
          );
        await sleep.refreshCapability();
      },
    );
  }

  /// Logs a drink from anywhere in the app and offers Undo.
  Future<void> quickLog(
    DrinkKind kind, {
    int? amountMl,
    LogSource source = LogSource.app,
  }) async {
    final entry = await hydration.log(kind, amountMl: amountMl, source: source);
    showToast(
      'Logged ${entry.amountMl} ml · ${kind == DrinkKind.custom ? 'drink' : kind.label.toLowerCase()}',
      actionLabel: 'Undo',
      onAction: () {
        hydration.undo(entry.id);
        toast.value = null;
      },
    );
  }

  Future<void> handleAction(PlatformAction action) async {
    switch (action) {
      case LogDrinkAction(:final ml, :final source):
        final kind = DrinkKind.values.firstWhere(
          (k) => k.defaultMl == ml,
          orElse: () => DrinkKind.custom,
        );
        await quickLog(kind, amountMl: ml, source: source);
      case StartWindDownAction():
        tab.value = AppTab.sleep;
        await sleep.startWindDown();
      case OpenTabAction(:final tab):
        this.tab.value = AppTab.values.firstWhere(
          (t) => t.name == tab,
          orElse: () => AppTab.hydrate,
        );
    }
  }

  void showToast(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _toastTimer?.cancel();
    toast.value = ToastData(
      message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    _toastTimer = Timer(
      const Duration(milliseconds: 3600),
      () => toast.value = null,
    );
  }

  void _scheduleSnapshot() {
    _snapshotDebounce?.cancel();
    _snapshotDebounce = Timer(
      const Duration(milliseconds: 300),
      _publishSnapshot,
    );
  }

  Future<void> _publishSnapshot() {
    final s = sleep.schedule;
    final systemNight =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    return platform.publishSnapshot(
      RhythmSnapshot(
        totalMl: hydration.totalMl,
        goalMl: hydration.goalMl,
        drinksToday: hydration.today.length,
        nextNudge: hydration.nextNudge,
        bedtimeLabel: s.bedtime.format12(),
        wakeLabel: s.wake.format12(),
        windDownLabel: s.windDownStart.format12(),
        alarmOn: sleep.alarmOn,
        night: switch (settings.theme) {
          ThemePref.night => true,
          ThemePref.day => false,
          ThemePref.system => systemNight,
        },
        updatedAt: DateTime.now(),
      ),
    );
  }

  void dispose() {
    _toastTimer?.cancel();
    _snapshotDebounce?.cancel();
    _actionSub?.cancel();
    _externalSub?.cancel();
    _lifecycle?.dispose();
    platform.dispose();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      !identical(oldWidget.services, services);
}
