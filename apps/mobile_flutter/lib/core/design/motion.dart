import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Motion language: springs for anything the user moves, short eased
/// curves for state changes, nothing that loops except the water surface.
abstract final class AqMotion {
  /// Leading edge of the nav lens: quick and firm.
  static const SpringDescription lensLead = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 30,
  );

  /// Trailing edge of the nav lens: softer, so the lens stretches like a
  /// droplet and then settles.
  static const SpringDescription lensTrail = SpringDescription(
    mass: 1,
    stiffness: 240,
    damping: 24,
  );

  /// Cards rising in on first show.
  static const Curve rise = Cubic(0.2, 0.9, 0.25, 1.12);
  static const Duration riseDuration = Duration(milliseconds: 620);
  static const Duration stagger = Duration(milliseconds: 40);

  /// Water level after a log: overshoots slightly, like liquid settling.
  static const Curve fill = Cubic(0.3, 1.35, 0.45, 1);
  static const Duration fillDuration = Duration(milliseconds: 1050);

  /// Press feedback on glass controls.
  static const Curve press = Cubic(0.3, 1.6, 0.5, 1);
  static const Duration pressDuration = Duration(milliseconds: 380);

  /// Day/Night cross-fade of every token.
  static const Duration modeDuration = Duration(milliseconds: 650);

  /// One full loop of the water surface wave.
  static const Duration wavePeriod = Duration(seconds: 7);
}
