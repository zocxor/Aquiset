import 'package:aquiset/features/hydration/domain/drink_log.dart';
import 'package:aquiset/platform/rhythm_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a widget log action', () {
    final action = PlatformAction.parse({'type': 'logDrink', 'ml': 250, 'source': 'widget'});
    expect(action, isA<LogDrinkAction>());
    final log = action! as LogDrinkAction;
    expect(log.ml, 250);
    expect(log.source, LogSource.widget);
  });

  test('unknown actions are ignored', () {
    expect(PlatformAction.parse({'type': 'nope'}), isNull);
    expect(PlatformAction.parse('garbage'), isNull);
  });

  test('alarm status text is honest about limits', () {
    const off = AlarmCapability(backend: AlarmBackend.alarmManager, authorized: true, exactAllowed: false, canRequest: true);
    expect(off.statusText, contains('may ring late'));
    const legacy = AlarmCapability(backend: AlarmBackend.notifications, authorized: true, exactAllowed: true, canRequest: false);
    expect(legacy.statusText, contains('silent mode'));
    expect(AlarmCapability.unavailable.ready, isFalse);
  });

  test('drink log json round trip keeps the idempotency id', () {
    final log = DrinkLog.create(amountMl: 250, kind: DrinkKind.glass, at: DateTime(2026, 11, 6, 9));
    final back = DrinkLog.fromJson(log.toJson());
    expect(back.id, log.id);
    expect(back.amountMl, 250);
    expect(back.kind, DrinkKind.glass);
    expect(back.loggedAt, log.loggedAt);
  });
}
