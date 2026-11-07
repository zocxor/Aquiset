import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../environment.dart';
import '../tokens.dart';

/// Glass weights, from lightest to heaviest.
/// - thin: chips, steppers, small buttons
/// - regular: cards
/// - strong: nav bar, toasts, anything floating over scrolling content
/// - lens: the bright droplet that marks a selection
enum GlassWeight { thin, regular, strong, lens }

/// The single liquid glass primitive every surface in AQUISET is built from.
///
/// Layers, back to front:
/// 1. soft drop shadow (outside the clip)
/// 2. backdrop blur + 175% saturation, so colour behind the glass glows
///    through instead of turning grey
/// 3. tinted fill with a diagonal specular sheen
/// 4. rim light: a gradient hairline brightest at the top-left, a lit top
///    lip and a faint shaded bottom edge
///
/// With Reduce transparency (in-app or high contrast) the same tokens render
/// as a solid surface and no backdrop filter runs at all.
///
/// Top-level surfaces share one backdrop snapshot through [BackdropGroup]
/// (see AppShell), which keeps a screen full of cards cheap on Impeller.
/// Surfaces nested inside another glass surface should pass
/// `shareBackdrop: false` so they blur the card they sit on.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.weight = GlassWeight.regular,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.padding,
    this.tint,
    this.shareBackdrop = true,
    this.shadow = true,
  });

  final Widget child;
  final GlassWeight weight;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool shareBackdrop;
  final bool shadow;

  static final Map<double, ui.ImageFilter> _filters = <double, ui.ImageFilter>{};

  /// Cached blur + saturation filter for a blur sigma.
  static ui.ImageFilter filterFor(double sigma) => _filters.putIfAbsent(
        sigma,
        () => ui.ImageFilter.compose(
          outer: ui.ColorFilter.matrix(_saturationMatrix(1.75)),
          inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: ui.TileMode.clamp),
        ),
      );

  static double sigmaFor(GlassWeight weight) => switch (weight) {
        GlassWeight.thin => 12.0,
        GlassWeight.regular => 20.0,
        GlassWeight.strong => 28.0,
        GlassWeight.lens => 8.0,
      };

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final solid = AqEnvironment.transparencyReduced(context);
    final fill = tint ??
        switch (weight) {
          GlassWeight.thin => t.glassThin,
          GlassWeight.regular => t.glassRegular,
          GlassWeight.strong => t.glassStrong,
          GlassWeight.lens => t.glassLens,
        };

    Widget body = padding == null ? child : Padding(padding: padding!, child: child);

    if (solid) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: weight == GlassWeight.lens ? t.aquaSoft : t.solidSurface,
          borderRadius: borderRadius,
          border: Border.all(color: t.track),
        ),
        child: body,
      );
    } else {
      body = CustomPaint(
        foregroundPainter: GlassRimPainter(
          borderRadius: borderRadius,
          highlight: t.rimHighlight,
          edge: t.edge,
          shade: t.rimShade,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0, 0.34, 0.72, 1],
              colors: [
                Color.alphaBlend(t.sheen, fill),
                fill,
                fill,
                Color.lerp(fill, Color.alphaBlend(t.sheen, fill), 0.5)!,
              ],
            ),
          ),
          child: body,
        ),
      );
      final filter = filterFor(sigmaFor(weight));
      body = shareBackdrop
          ? BackdropFilter.grouped(filter: filter, child: body)
          : BackdropFilter(filter: filter, child: body);
    }

    body = ClipRRect(borderRadius: borderRadius, child: body);
    if (!shadow) return body;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(color: t.shadow, blurRadius: 36, spreadRadius: -18, offset: const Offset(0, 16)),
          BoxShadow(color: t.shadow, blurRadius: 8, spreadRadius: -4, offset: const Offset(0, 2)),
        ],
      ),
      child: body,
    );
  }
}

/// Paints the rim light that makes a blurred panel read as glass.
class GlassRimPainter extends CustomPainter {
  const GlassRimPainter({
    required this.borderRadius,
    required this.highlight,
    required this.edge,
    required this.shade,
  });

  final BorderRadius borderRadius;
  final Color highlight;
  final Color edge;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    // 1. Gradient hairline around the whole shape.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, 0.4, 0.62, 1],
        colors: [highlight, edge, edge.withValues(alpha: 0), Color.lerp(edge, highlight, 0.4)!],
      ).createShader(rect);
    canvas.drawRRect(borderRadius.toRRect(rect).deflate(0.5), rim);

    // 2. Lit top lip, fading out before the corners.
    final r = math.min(borderRadius.topLeft.x, size.width / 2);
    final lipRect = Rect.fromLTWH(r * 0.6, 0, math.max(1, size.width - r * 1.2), 2);
    final lip = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        colors: [highlight.withValues(alpha: 0), highlight, highlight.withValues(alpha: 0)],
      ).createShader(lipRect);
    canvas.drawLine(Offset(lipRect.left, 1.5), Offset(lipRect.right, 1.5), lip);

    // 3. Faint shade along the bottom edge.
    final br = math.min(borderRadius.bottomLeft.x, size.width / 2);
    canvas.drawLine(
      Offset(br, size.height - 1),
      Offset(size.width - br, size.height - 1),
      Paint()
        ..strokeWidth = 1
        ..color = shade,
    );
  }

  @override
  bool shouldRepaint(GlassRimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.highlight != highlight ||
      oldDelegate.edge != edge ||
      oldDelegate.shade != shade;
}

/// Luminance-preserving saturation matrix (Rec. 709 weights).
List<double> _saturationMatrix(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final i = 1 - s;
  return <double>[
    r * i + s, g * i, b * i, 0, 0, //
    r * i, g * i + s, b * i, 0, 0, //
    r * i, g * i, b * i + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
