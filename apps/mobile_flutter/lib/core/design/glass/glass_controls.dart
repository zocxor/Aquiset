import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../environment.dart';
import '../motion.dart';
import '../tokens.dart';
import '../typography.dart';
import 'glass_surface.dart';

/// Springy press feedback: scales to 94% while a finger is down.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AqEnvironment.motionReduced(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: reduced ? Duration.zero : AqMotion.pressDuration,
        curve: AqMotion.press,
        child: widget.child,
      ),
    );
  }
}

/// Card: regular glass, 28 radius, 16 padding.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => GlassSurface(
    borderRadius: BorderRadius.circular(radius),
    padding: padding,
    child: child,
  );
}

/// Pill button made of glass. Minimum 44 pt tall.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.weight = GlassWeight.thin,
    this.height = 44,
    this.foreground,
    this.semanticLabel,
    this.expand = false,
    this.tint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GlassWeight weight;
  final double height;
  final Color? foreground;
  final String? semanticLabel;
  final bool expand;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final fg = foreground ?? t.ink;
    final radius = BorderRadius.circular(height * 0.42);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: PressScale(
        enabled: onPressed != null,
        child: GlassSurface(
          weight: weight,
          tint: tint,
          shareBackdrop: false,
          shadow: weight != GlassWeight.thin,
          borderRadius: radius,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    },
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: height,
                  minWidth: height,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          style: AqType.label(t, color: fg),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round glass icon button (header actions, the quick-log orb).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
    this.weight = GlassWeight.thin,
    this.color,
    this.child,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;
  final double size;
  final GlassWeight weight;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final radius = BorderRadius.circular(size / 2);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: PressScale(
        child: GlassSurface(
          weight: weight,
          borderRadius: radius,
          shareBackdrop: weight != GlassWeight.thin,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: () {
                HapticFeedback.lightImpact();
                onPressed();
              },
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child:
                      child ??
                      Icon(icon, size: size * 0.42, color: color ?? t.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// On/off switch with a springy thumb. Position is the primary signal, so
/// state never relies on colour alone.
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final reduced = AqEnvironment.motionReduced(context);
    final d = reduced ? Duration.zero : AqMotion.pressDuration;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        radius: 30,
        child: SizedBox(
          width: 60,
          height: 44,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: d,
                height: 32,
                decoration: BoxDecoration(
                  color: value ? t.aqua : t.track,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.edge),
                ),
              ),
              AnimatedPositioned(
                duration: d,
                curve: AqMotion.press,
                left: value ? 31 : 3,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x47000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented control with the same sliding lens as the nav bar.
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    final reduced = AqEnvironment.motionReduced(context);
    final index = options
        .indexWhere((o) => o.$1 == selected)
        .clamp(0, options.length - 1);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: GlassSurface(
        weight: GlassWeight.thin,
        shareBackdrop: false,
        shadow: false,
        borderRadius: BorderRadius.circular(25),
        child: SizedBox(
          height: 50,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 8) / options.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 550),
                    curve: AqMotion.fill,
                    left: 4 + index * w,
                    top: 4,
                    bottom: 4,
                    width: w,
                    child: GlassSurface(
                      weight: GlassWeight.lens,
                      shareBackdrop: false,
                      shadow: false,
                      borderRadius: BorderRadius.circular(21),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (value, label) in options)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: value == selected,
                            child: InkResponse(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onChanged(value);
                              },
                              highlightShape: BoxShape.rectangle,
                              containedInkWell: true,
                              splashColor: Colors.transparent,
                              child: Center(
                                child: Text(
                                  label,
                                  style: AqType.label(
                                    t,
                                    color: value == selected ? t.ink : t.ink3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Floating confirmation with an optional action, used for "Logged 250 ml · Undo".
class GlassToast extends StatelessWidget {
  const GlassToast({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.water_drop_outlined,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return Semantics(
      liveRegion: true,
      child: GlassSurface(
        weight: GlassWeight.strong,
        borderRadius: BorderRadius.circular(26),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16),
              Icon(icon, size: 18, color: t.aqua),
              const SizedBox(width: 10),
              Text(message, style: AqType.label(t, size: 13.5)),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: t.aqua,
                  ),
                  child: Text(
                    actionLabel!,
                    style: AqType.label(t, size: 13.5, color: t.aqua),
                  ),
                )
              else
                const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
