import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/drink_log.dart';

/// Offline-first store for drink logs. The device is the write path; a sync
/// worker later pushes [pendingSync] to `POST /v1/hydration/logs` using each
/// log's id as the idempotency key, then calls [markSynced].
abstract interface class HydrationRepository {
  Future<List<DrinkLog>> logsOn(DateTime day);
  Future<List<DrinkLog>> logsBetween(DateTime start, DateTime end);
  Future<void> add(DrinkLog log);
  Future<void> remove(String id);
  Future<List<DrinkLog>> pendingSync();
  Future<void> markSynced(Iterable<String> ids);
}

/// SharedPreferences-backed implementation for the MVP. Small, synchronous
/// reads and no native database setup. ADR-0004 moves this to SQLite (drift)
/// once multi-month history screens land.
class PrefsHydrationRepository implements HydrationRepository {
  PrefsHydrationRepository(
    this._prefs, {
    this.retention = const Duration(days: 400),
  });

  static const String _key = 'hydration.logs.v1';

  final SharedPreferences _prefs;
  final Duration retention;

  List<DrinkLog> _all() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <DrinkLog>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => DrinkLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<DrinkLog> logs) {
    final cutoff = DateTime.now().subtract(retention);
    final kept =
        logs.where((l) => l.loggedAt.isAfter(cutoff) || !l.synced).toList()
          ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return _prefs.setString(
      _key,
      jsonEncode(kept.map((l) => l.toJson()).toList()),
    );
  }

  @override
  Future<List<DrinkLog>> logsOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return logsBetween(start, DateTime(day.year, day.month, day.day + 1));
  }

  @override
  Future<List<DrinkLog>> logsBetween(DateTime start, DateTime end) async =>
      _all()
          .where(
            (l) =>
                !l.isDeleted &&
                !l.loggedAt.isBefore(start) &&
                l.loggedAt.isBefore(end),
          )
          .toList();

  @override
  Future<void> add(DrinkLog log) async {
    final all = _all();
    if (all.any((l) => l.id == log.id)) return; // idempotent
    await _save(all..add(log));
  }

  @override
  Future<void> remove(String id) async {
    final all = _all();
    final index = all.indexWhere((l) => l.id == id);
    if (index < 0) return;
    final log = all[index];
    if (log.synced) {
      all[index] = log.copyWith(synced: false, deletedAt: DateTime.now());
    } else {
      all.removeAt(index);
    }
    await _save(all);
  }

  @override
  Future<List<DrinkLog>> pendingSync() async =>
      _all().where((l) => !l.synced).toList();

  @override
  Future<void> markSynced(Iterable<String> ids) async {
    final set = ids.toSet();
    final all =
        _all()
            .where((l) => !(set.contains(l.id) && l.isDeleted))
            .map((l) => set.contains(l.id) ? l.copyWith(synced: true) : l)
            .toList();
    await _save(all);
  }
}
