import 'dart:math';

import 'package:flutter/foundation.dart';

enum DrinkKind {
  sip(100, 'Sip'),
  cup(200, 'Cup'),
  glass(250, 'Glass'),
  bottle(500, 'Bottle'),
  custom(0, 'Drink');

  const DrinkKind(this.defaultMl, this.label);
  final int defaultMl;
  final String label;

  static DrinkKind parse(String? name) => DrinkKind.values.firstWhere(
    (k) => k.name == name,
    orElse: () => DrinkKind.custom,
  );
}

/// Where a log came from. Lets analytics see which platform surfaces help,
/// without collecting anything about the person.
enum LogSource { app, widget, control, siri, watch, shortcut }

/// One drink. [id] is generated on the device and doubles as the
/// idempotency key, so retries and offline sync never create duplicates.
@immutable
class DrinkLog {
  const DrinkLog({
    required this.id,
    required this.amountMl,
    required this.kind,
    required this.loggedAt,
    this.source = LogSource.app,
    this.synced = false,
    this.deletedAt,
  });

  factory DrinkLog.create({
    required int amountMl,
    required DrinkKind kind,
    required DateTime at,
    LogSource source = LogSource.app,
  }) => DrinkLog(
    id: newClientId(),
    amountMl: amountMl,
    kind: kind,
    loggedAt: at,
    source: source,
  );

  factory DrinkLog.fromJson(Map<String, dynamic> json) => DrinkLog(
    id: json['id'] as String,
    amountMl: (json['amount_ml'] as num).toInt(),
    kind: DrinkKind.parse(json['kind'] as String?),
    loggedAt: DateTime.parse(json['logged_at'] as String).toLocal(),
    source: LogSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => LogSource.app,
    ),
    synced: json['synced'] as bool? ?? false,
    deletedAt: json['deleted_at'] == null
        ? null
        : DateTime.parse(json['deleted_at'] as String).toLocal(),
  );

  final String id;
  final int amountMl;
  final DrinkKind kind;
  final DateTime loggedAt;
  final LogSource source;
  final bool synced;

  /// Set when the person deletes a log that was already synced; kept as a
  /// tombstone until the server confirms the delete.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  DrinkLog copyWith({bool? synced, DateTime? deletedAt}) => DrinkLog(
    id: id,
    amountMl: amountMl,
    kind: kind,
    loggedAt: loggedAt,
    source: source,
    synced: synced ?? this.synced,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'amount_ml': amountMl,
    'kind': kind.name,
    'logged_at': loggedAt.toUtc().toIso8601String(),
    'source': source.name,
    'synced': synced,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };
}

final Random _random = Random.secure();

/// 128-bit random hex id, safe to generate offline on any device.
String newClientId() {
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
