import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Semantic colour tokens for AQUISET's liquid glass system.
///
/// Day and Night are two value sets of the same tokens: layout, widgets and
/// hierarchy never change between them. Because this is a [ThemeExtension]
/// with a real [lerp], switching modes animates every surface, the nature
/// backdrop and the glass tint together.
@immutable
class AqTokens extends ThemeExtension<AqTokens> {
  const AqTokens({
    required this.nightness,
    required this.skyTop,
    required this.skyBottom,
    required this.hill1,
    required this.hill2,
    required this.hill3,
    required this.lake,
    required this.lakeLine,
    required this.glow,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.aqua,
    required this.aqua2,
    required this.leaf,
    required this.lav,
    required this.lav2,
    required this.gold,
    required this.gold2,
    required this.danger,
    required this.aquaSoft,
    required this.leafSoft,
    required this.lavSoft,
    required this.onAccent,
    required this.glassThin,
    required this.glassRegular,
    required this.glassStrong,
    required this.glassLens,
    required this.solidSurface,
    required this.knob,
    required this.edge,
    required this.rimHighlight,
    required this.rimShade,
    required this.shadow,
    required this.sheen,
    required this.waterTop,
    required this.waterBottom,
    required this.track,
  });

  /// 0 in Day, 1 in Night. Interpolates during the mode transition so the
  /// sun can set while the moon and stars fade in.
  final double nightness;

  // Nature backdrop.
  final Color skyTop, skyBottom, hill1, hill2, hill3, lake, lakeLine, glow;

  // Text. All three pass WCAG 2.2 AA (4.5:1) on glass over the backdrop.
  final Color ink, ink2, ink3;

  // Accents. `aqua`, `leaf`, `lav`, `gold` and `danger` are text-safe;
  // `aqua2`, `lav2`, `gold2` are for fills and decoration only.
  final Color aqua, aqua2, leaf, lav, lav2, gold, gold2, danger;
  final Color aquaSoft, leafSoft, lavSoft, onAccent;

  // Glass material.
  final Color glassThin, glassRegular, glassStrong, glassLens;
  final Color solidSurface, knob, edge, rimHighlight, rimShade, shadow, sheen;

  // Water and tracks.
  final Color waterTop, waterBottom, track;

  bool get isNight => nightness >= 0.5;

  static const AqTokens day = AqTokens(
    nightness: 0,
    skyTop: Color(0xFFD6EBEA),
    skyBottom: Color(0xFFF4EFE6),
    hill1: Color(0xFFCFE0CF),
    hill2: Color(0xFFBBD6C4),
    hill3: Color(0xFFA6C9B3),
    lake: Color(0xFFBFE3E1),
    lakeLine: Color(0xBFFFFFFF),
    glow: Color(0xFFF6D99A),
    ink: Color(0xFF10222B),
    ink2: Color(0xFF3B4E57),
    ink3: Color(0xFF4A5D66),
    aqua: Color(0xFF06666D),
    aqua2: Color(0xFF36BFC3),
    leaf: Color(0xFF2A6445),
    lav: Color(0xFF5D4F9E),
    lav2: Color(0xFFA99BE0),
    gold: Color(0xFF705316),
    gold2: Color(0xFFE2BE6A),
    danger: Color(0xFF962F28),
    aquaSoft: Color(0x1F06666D),
    leafSoft: Color(0x1F2A6445),
    lavSoft: Color(0x215D4F9E),
    onAccent: Color(0xFFFFFFFF),
    glassThin: Color(0x85FFFFFF),
    glassRegular: Color(0x99FFFFFF),
    glassStrong: Color(0xB8FFFFFF),
    glassLens: Color(0xC7FFFFFF),
    solidSurface: Color(0xFFF3F6F4),
    knob: Color(0xFFFFFFFF),
    edge: Color(0xB3FFFFFF),
    rimHighlight: Color(0xF2FFFFFF),
    rimShade: Color(0x0F10222B),
    shadow: Color(0x331E404A),
    sheen: Color(0x99FFFFFF),
    waterTop: Color(0xFF8FE1E3),
    waterBottom: Color(0xFF1595A0),
    track: Color(0x1A10222B),
  );

  static const AqTokens night = AqTokens(
    nightness: 1,
    skyTop: Color(0xFF08101C),
    skyBottom: Color(0xFF15213A),
    hill1: Color(0xFF192A3D),
    hill2: Color(0xFF1E3449),
    hill3: Color(0xFF152B3B),
    lake: Color(0xFF16364A),
    lakeLine: Color(0x59BBADF4),
    glow: Color(0xFF3E3A78),
    ink: Color(0xFFEEF2F6),
    ink2: Color(0xFFB3BFCE),
    ink3: Color(0xFF98A6B8),
    aqua: Color(0xFF62D6D9),
    aqua2: Color(0xFF2BA9AF),
    leaf: Color(0xFF7FCB9F),
    lav: Color(0xFFBBADF4),
    lav2: Color(0xFF7C6CC4),
    gold: Color(0xFFE2C37A),
    gold2: Color(0xFFC79E45),
    danger: Color(0xFFF2A49B),
    aquaSoft: Color(0x2462D6D9),
    leafSoft: Color(0x247FCB9F),
    lavSoft: Color(0x29BBADF4),
    onAccent: Color(0xFF0C1A24),
    glassThin: Color(0x801A283C),
    glassRegular: Color(0x941A283C),
    glassStrong: Color(0xB31C2C42),
    glassLens: Color(0x24FFFFFF),
    solidSurface: Color(0xFF1A2738),
    knob: Color(0xFF2C3D57),
    edge: Color(0x24FFFFFF),
    rimHighlight: Color(0x42FFFFFF),
    rimShade: Color(0x4D000000),
    shadow: Color(0x80000000),
    sheen: Color(0x1FFFFFFF),
    waterTop: Color(0xFF53CDD3),
    waterBottom: Color(0xFF12597A),
    track: Color(0x1AFFFFFF),
  );

  static AqTokens of(BuildContext context) =>
      Theme.of(context).extension<AqTokens>() ?? day;

  @override
  AqTokens copyWith() => this;

  @override
  AqTokens lerp(covariant ThemeExtension<AqTokens>? other, double t) {
    if (other is! AqTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AqTokens(
      nightness: lerpDouble(nightness, other.nightness, t)!,
      skyTop: c(skyTop, other.skyTop),
      skyBottom: c(skyBottom, other.skyBottom),
      hill1: c(hill1, other.hill1),
      hill2: c(hill2, other.hill2),
      hill3: c(hill3, other.hill3),
      lake: c(lake, other.lake),
      lakeLine: c(lakeLine, other.lakeLine),
      glow: c(glow, other.glow),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      aqua: c(aqua, other.aqua),
      aqua2: c(aqua2, other.aqua2),
      leaf: c(leaf, other.leaf),
      lav: c(lav, other.lav),
      lav2: c(lav2, other.lav2),
      gold: c(gold, other.gold),
      gold2: c(gold2, other.gold2),
      danger: c(danger, other.danger),
      aquaSoft: c(aquaSoft, other.aquaSoft),
      leafSoft: c(leafSoft, other.leafSoft),
      lavSoft: c(lavSoft, other.lavSoft),
      onAccent: c(onAccent, other.onAccent),
      glassThin: c(glassThin, other.glassThin),
      glassRegular: c(glassRegular, other.glassRegular),
      glassStrong: c(glassStrong, other.glassStrong),
      glassLens: c(glassLens, other.glassLens),
      solidSurface: c(solidSurface, other.solidSurface),
      knob: c(knob, other.knob),
      edge: c(edge, other.edge),
      rimHighlight: c(rimHighlight, other.rimHighlight),
      rimShade: c(rimShade, other.rimShade),
      shadow: c(shadow, other.shadow),
      sheen: c(sheen, other.sheen),
      waterTop: c(waterTop, other.waterTop),
      waterBottom: c(waterBottom, other.waterBottom),
      track: c(track, other.track),
    );
  }
}
