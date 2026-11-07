import 'package:flutter/material.dart';

import '../core/design/environment.dart';
import '../core/design/motion.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import 'app_scope.dart';
import 'app_shell.dart';

class AquisetApp extends StatelessWidget {
  const AquisetApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) {
          final s = services.settings;
          return MaterialApp(
            title: 'AQUISET',
            debugShowCheckedModeBanner: false,
            themeMode: s.themeMode,
            theme: buildAquisetTheme(AqTokens.day, Brightness.light),
            darkTheme: buildAquisetTheme(AqTokens.night, Brightness.dark),
            themeAnimationDuration: s.reduceMotion ? Duration.zero : AqMotion.modeDuration,
            themeAnimationCurve: Curves.easeInOutCubic,
            builder: (context, child) => AqEnvironment(
              reduceMotion: s.reduceMotion,
              reduceTransparency: s.reduceTransparency,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const AppShell(),
          );
        },
      ),
    );
  }
}

ThemeData buildAquisetTheme(AqTokens t, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: t.aqua, brightness: brightness).copyWith(
    primary: t.aqua,
    onPrimary: t.onAccent,
    surface: t.solidSurface,
    onSurface: t.ink,
    error: t.danger,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: AqType.sansFamily,
    scaffoldBackgroundColor: t.skyBottom,
    splashFactory: InkSparkle.splashFactory,
    extensions: <ThemeExtension<dynamic>>[t],
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0),
  );
}
