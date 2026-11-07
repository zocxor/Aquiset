import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design/environment.dart';
import '../core/design/glass/glass_controls.dart';
import '../core/design/glass/glass_surface.dart';
import '../core/design/glass/liquid_nav_bar.dart';
import '../core/design/motion.dart';
import '../core/design/nature_backdrop.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../features/hydration/domain/drink_log.dart';
import '../features/hydration/presentation/hydration_dashboard.dart';
import '../features/rituals/presentation/rituals_screen.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/settings_screen.dart';
import '../features/sleep/presentation/sleep_dashboard.dart';
import 'app_scope.dart';

/// One shell for the whole app: nature backdrop, header, the current tab,
/// the floating liquid glass nav bar, the quick-log orb and toasts.
///
/// Wrapped in a [BackdropGroup] so every top-level glass surface shares one
/// backdrop read, which keeps blur cost flat as cards are added.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const List<LiquidNavItem> _items = [
    LiquidNavItem(icon: Icons.water_drop_outlined, label: 'Hydrate'),
    LiquidNavItem(icon: Icons.bedtime_outlined, label: 'Sleep'),
    LiquidNavItem(icon: Icons.eco_outlined, label: 'Rituals'),
    LiquidNavItem(icon: Icons.person_outline_rounded, label: 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = AqTokens.of(context);
    final reduced = AqEnvironment.motionReduced(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.isNight ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: t.skyBottom,
        body: BackdropGroup(
          child: Stack(
            children: [
              const Positioned.fill(child: NatureBackdrop()),
              Positioned.fill(
                child: ValueListenableBuilder<AppTab>(
                  valueListenable: s.tab,
                  builder: (context, tab, _) => Column(
                    children: [
                      _Header(tab: tab),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 320),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: KeyedSubtree(
                            key: ValueKey<AppTab>(tab),
                            child: switch (tab) {
                              AppTab.hydrate => const HydrationDashboard(),
                              AppTab.sleep => const SleepDashboard(),
                              AppTab.rituals => const RitualsScreen(),
                              AppTab.you => const SettingsScreen(),
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 104 + bottomInset,
                child: const _ToastLayer(),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16 + bottomInset,
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<AppTab>(
                        valueListenable: s.tab,
                        builder: (context, tab, _) => LiquidGlassNavBar(
                          items: _items,
                          index: tab.index,
                          onChanged: (i) => s.tab.value = AppTab.values[i],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GlassIconButton(
                      icon: Icons.add_rounded,
                      size: 66,
                      weight: GlassWeight.strong,
                      color: t.aqua,
                      semanticLabel: 'Log a glass of water, 250 millilitres',
                      onPressed: () => s.quickLog(DrinkKind.glass),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _Header extends StatelessWidget {
  const _Header({required this.tab});
  final AppTab tab;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = AqTokens.of(context);
    final now = DateTime.now();
    final title = switch (tab) {
      AppTab.hydrate =>
        now.hour < 12
            ? 'Good morning'
            : (now.hour < 18 ? 'Good afternoon' : 'Good evening'),
      AppTab.sleep => 'Tonight',
      AppTab.rituals => 'Rituals',
      AppTab.you => 'You',
    };
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_weekdays[now.weekday - 1]} · ${now.day} ${_months[now.month - 1]}'
                        .toUpperCase(),
                    style: AqType.eyebrow(t),
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    header: true,
                    child: Text(title, style: AqType.display(t, size: 36)),
                  ),
                ],
              ),
            ),
            const _ModeToggle(),
            const SizedBox(width: 8),
            GlassIconButton(
              icon: Icons.person_outline_rounded,
              semanticLabel: 'Your settings',
              onPressed: () => s.tab.value = AppTab.you,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sun/moon pill. Flips Day ↔ Night; System stays available under You.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = AqTokens.of(context);
    final night = t.isNight;
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      label: night ? 'Switch to Day mode' : 'Switch to Night mode',
      excludeSemantics: true,
      child: PressScale(
        child: GlassSurface(
          weight: GlassWeight.thin,
          borderRadius: radius,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: () {
                HapticFeedback.lightImpact();
                s.settings.setTheme(night ? ThemePref.day : ThemePref.night);
              },
              child: SizedBox(
                width: 84,
                height: 44,
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: AqEnvironment.motionReduced(context)
                          ? Duration.zero
                          : AqMotion.pressDuration * 1.4,
                      curve: AqMotion.press,
                      alignment: night
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: t.knob,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: t.shadow,
                                blurRadius: 12,
                                spreadRadius: -4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 13,
                      top: 13,
                      child: Icon(
                        Icons.wb_sunny_outlined,
                        size: 18,
                        color: t.gold,
                      ),
                    ),
                    Positioned(
                      right: 13,
                      top: 13,
                      child: Icon(
                        Icons.nightlight_outlined,
                        size: 18,
                        color: t.lav,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastLayer extends StatelessWidget {
  const _ToastLayer();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final reduced = AqEnvironment.motionReduced(context);
    return ValueListenableBuilder<ToastData?>(
      valueListenable: s.toast,
      builder: (context, toast, _) => AnimatedSwitcher(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 420),
        switchInCurve: AqMotion.press,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: toast == null
            ? const SizedBox.shrink()
            : Center(
                key: ObjectKey(toast),
                child: GlassToast(
                  message: toast.message,
                  actionLabel: toast.actionLabel,
                  onAction: toast.onAction,
                ),
              ),
      ),
    );
  }
}
