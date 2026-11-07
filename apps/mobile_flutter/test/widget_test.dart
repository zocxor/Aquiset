import 'package:aquiset/app/app.dart';
import 'package:aquiset/app/app_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's real root widget, pumped with real services.
/// SharedPreferences is mocked in memory; the native platform bridge
/// (RhythmPlatform) degrades to no-op in tests by design, so no native
/// code is needed.
void main() {
  testWidgets('AQUISET app builds and shows the home shell', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final services = await AppServices.bootstrap();
    addTearDown(services.dispose);

    await tester.pumpWidget(AquisetApp(services: services));
    await tester.pump();

    expect(find.byType(AquisetApp), findsOneWidget);
    expect(find.text('Hydrate'), findsOneWidget);
  });
}
