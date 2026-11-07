import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Type scale: Instrument Serif for display numbers and titles, Manrope for
/// everything you read or tap. Both are OFL fonts served by google_fonts;
/// bundle them under assets/google_fonts/ for fully offline launches.
abstract final class AqType {
  static String get sansFamily => GoogleFonts.getFont('Manrope').fontFamily ?? 'Manrope';

  static TextStyle display(AqTokens t, {double size = 36}) => GoogleFonts.getFont(
        'Instrument Serif',
        fontSize: size,
        height: 1.02,
        letterSpacing: -0.2,
        color: t.ink,
      );

  static TextStyle eyebrow(AqTokens t, {double size = 11}) => GoogleFonts.getFont(
        'Manrope',
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: size * 0.14,
        color: t.ink3,
      );

  static TextStyle title(AqTokens t) =>
      GoogleFonts.getFont('Manrope', fontSize: 15, fontWeight: FontWeight.w800, color: t.ink);

  static TextStyle label(AqTokens t, {double size = 13, Color? color}) =>
      GoogleFonts.getFont('Manrope', fontSize: size, fontWeight: FontWeight.w800, color: color ?? t.ink);

  static TextStyle body(AqTokens t) =>
      GoogleFonts.getFont('Manrope', fontSize: 13.5, height: 1.5, color: t.ink2);

  static TextStyle caption(AqTokens t) =>
      GoogleFonts.getFont('Manrope', fontSize: 12, height: 1.45, color: t.ink3);

  static TextStyle stat(AqTokens t, {double size = 17}) =>
      GoogleFonts.getFont('Manrope', fontSize: size, fontWeight: FontWeight.w800, color: t.ink);
}
