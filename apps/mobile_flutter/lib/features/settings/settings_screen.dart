import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/design/glass/glass_controls.dart';
import '../../core/design/rise_in.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../hydration/presentation/hydration_dashboard.dart' show formatMl;
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.settings,
      builder: (context, _) {
        final t = AqTokens.of(context);
        final set = s.settings;
        final policy = set.policy;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            150 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            RiseIn(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance', style: AqType.title(t)),
                    const SizedBox(height: 12),
                    GlassSegmented<ThemePref>(
                      semanticLabel: 'Appearance',
                      options: const [
                        (ThemePref.system, 'System'),
                        (ThemePref.day, 'Day'),
                        (ThemePref.night, 'Night'),
                      ],
                      selected: set.theme,
                      onChanged: set.setTheme,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Day and Night change colours only. Layout, widgets and controls stay the same.',
                      style: AqType.caption(t),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            RiseIn(
              index: 1,
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    _SwitchRow(
                      title: 'Reduce transparency',
                      subtitle: 'Solid surfaces instead of glass',
                      value: set.reduceTransparency,
                      onChanged: set.setReduceTransparency,
                    ),
                    _SwitchRow(
                      title: 'Reduce motion',
                      subtitle: 'Stops waves, springs and stretch',
                      value: set.reduceMotion,
                      onChanged: set.setReduceMotion,
                      divider: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            RiseIn(
              index: 2,
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text('Hydration', style: AqType.title(t)),
                    ),
                    _StepRow(
                      title: 'Daily goal',
                      value: '${formatMl(set.goalMl)} ml',
                      subtitle: 'Your own choice, not a medical target',
                      onMinus: () => set.setGoalMl(set.goalMl - 250),
                      onPlus: () => set.setGoalMl(set.goalMl + 250),
                    ),
                    _SwitchRow(
                      title: 'Gentle nudges',
                      subtitle: 'Only inside your waking hours',
                      value: policy.enabled,
                      onChanged:
                          (v) => set.setPolicy(policy.copyWith(enabled: v)),
                      divider: true,
                    ),
                    _StepRow(
                      title: 'Daily nudge limit',
                      value: '${policy.dailyCap} a day',
                      onMinus:
                          () => set.setPolicy(
                            policy.copyWith(
                              dailyCap: (policy.dailyCap - 1).clamp(0, 12),
                            ),
                          ),
                      onPlus:
                          () => set.setPolicy(
                            policy.copyWith(
                              dailyCap: (policy.dailyCap + 1).clamp(0, 12),
                            ),
                          ),
                    ),
                    _InfoRow(
                      title: 'Quiet hours',
                      value:
                          '${policy.quietStart.format12()} – ${policy.quietEnd.format12()}',
                    ),
                    _InfoRow(
                      title: 'Pause after a drink',
                      value: '${policy.cooldownAfterDrink.inMinutes} min',
                    ),
                    _SwitchRow(
                      title: 'A clinician manages my fluids',
                      subtitle:
                          'Turns off generic nudges. Follow your clinician\'s plan.',
                      value: policy.followsClinicianPlan,
                      onChanged:
                          (v) => set.setPolicy(
                            policy.copyWith(followsClinicianPlan: v),
                          ),
                      divider: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            RiseIn(
              index: 3,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Beyond the app', style: AqType.title(t)),
                    const SizedBox(height: 10),
                    const _Feature(
                      icon: Icons.widgets_outlined,
                      text: 'Home and Lock Screen widgets with one-tap logging',
                    ),
                    const _Feature(
                      icon: Icons.toggle_on_outlined,
                      text: 'Control Center and Action button: log a glass',
                    ),
                    const _Feature(
                      icon: Icons.record_voice_over_outlined,
                      text: 'Siri and Shortcuts: "Log a glass in AQUISET"',
                    ),
                    const _Feature(
                      icon: Icons.timelapse_rounded,
                      text:
                          'Wind-down countdown on the Lock Screen and Dynamic Island',
                    ),
                    const _Feature(
                      icon: Icons.watch_outlined,
                      text: 'Apple Watch: today\'s water and quick log',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            RiseIn(
              index: 4,
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.file_download_outlined,
                        color: t.aqua,
                      ),
                      title: Text(
                        'Export my data',
                        style: AqType.label(t, size: 14),
                      ),
                      subtitle: Text(
                        'Copies your logs as JSON',
                        style: AqType.caption(t),
                      ),
                      onTap: () async {
                        final logs = await s.hydration.repository.logsBetween(
                          DateTime(2000),
                          DateTime(2100),
                        );
                        final json = const JsonEncoder.withIndent(
                          '  ',
                        ).convert(<String, Object?>{
                          'exported_at':
                              DateTime.now().toUtc().toIso8601String(),
                          'drink_logs': logs.map((l) => l.toJson()).toList(),
                          'sleep_schedule': s.sleep.schedule.toJson(),
                        });
                        await Clipboard.setData(ClipboardData(text: json));
                        s.showToast(
                          'Copied ${logs.length} logs to the clipboard',
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: t.danger,
                      ),
                      title: Text(
                        'Delete my data on this phone',
                        style: AqType.label(t, size: 14, color: t.danger),
                      ),
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final s = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete everything on this phone?'),
            content: const Text(
              'Your drinks, sleep logs, alarms and settings are removed from this device. This can\'t be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await s.platform.cancelAlarm('wake');
    await s.platform.cancelNudges();
    await s.platform.endWindDown();
    await s.prefs.clear();
    await s.hydration.load();
    s.showToast('Deleted. Reopen AQUISET to start fresh.');
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.divider = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: t.track)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AqType.label(t, size: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: AqType.caption(t)),
              ],
            ),
          ),
          GlassSwitch(value: value, onChanged: onChanged, semanticLabel: title),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    Widget btn(IconData icon, String label, VoidCallback onTap) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox.square(
          dimension: 44,
          child: Icon(icon, size: 18, color: t.ink),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.track)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AqType.label(t, size: 14)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AqType.caption(t)),
                ],
              ],
            ),
          ),
          btn(Icons.remove_rounded, 'Decrease $title', onMinus),
          Text(value, style: AqType.label(t, size: 13.5)),
          btn(Icons.add_rounded, 'Increase $title', onPlus),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.track)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AqType.label(t, size: 14))),
          Text(value, style: AqType.caption(t).copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AqTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: t.aqua),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AqType.body(t).copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
