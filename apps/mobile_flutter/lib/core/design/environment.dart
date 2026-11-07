import 'package:flutter/widgets.dart';

/// User comfort settings that every glass and motion widget reads.
///
/// Both flags combine the in-app setting with the operating system:
/// - motion is reduced when the user turns it on here OR the OS asks
///   (iOS Reduce Motion / Android "Remove animations").
/// - transparency is reduced when the user turns it on here OR the OS
///   reports high contrast. Flutter does not expose iOS "Reduce
///   Transparency" directly, so the in-app switch is the reliable path.
class AqEnvironment extends InheritedWidget {
  const AqEnvironment({
    super.key,
    required this.reduceMotion,
    required this.reduceTransparency,
    required super.child,
  });

  final bool reduceMotion;
  final bool reduceTransparency;

  static bool motionReduced(BuildContext context) {
    final env = context.dependOnInheritedWidgetOfExactType<AqEnvironment>();
    return MediaQuery.disableAnimationsOf(context) || (env?.reduceMotion ?? false);
  }

  static bool transparencyReduced(BuildContext context) {
    final env = context.dependOnInheritedWidgetOfExactType<AqEnvironment>();
    return MediaQuery.highContrastOf(context) || (env?.reduceTransparency ?? false);
  }

  @override
  bool updateShouldNotify(AqEnvironment oldWidget) =>
      oldWidget.reduceMotion != reduceMotion ||
      oldWidget.reduceTransparency != reduceTransparency;
}
