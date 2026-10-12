import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/biometric_service.dart';
import '../../data/models/models.dart';
import '../../services/app_services.dart';
import '../../services/settings_controller.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _quickEnabled;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuick());
  }

  Future<void> _loadQuick() async {
    final s = context.services;
    final info = await s.auth.quickUnlockInfo();
    final available = await BiometricService.isAvailable();
    if (!mounted) return;
    setState(() {
      _quickEnabled = info != null && info.userId == s.auth.user?.id;
      _bioAvailable = available;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final st = s.settings;
    final u = s.auth.user;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Settings and accessibility'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([st, s.device]),
        builder: (context, _) => PageFrame(
          maxWidth: 720,
          children: [
            const SectionHeader('Appearance'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Theme', style: text.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                    ],
                    selected: {st.themeMode},
                    onSelectionChanged: (v) => st.setThemeMode(v.first),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: st.highContrast,
                    onChanged: st.setHighContrast,
                    secondary: const Icon(Icons.contrast),
                    title: const Text('High contrast'),
                    subtitle: const Text('Darker text and stronger outlines'),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.format_size),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Text size', style: text.titleSmall)),
                      Text('${(st.textScale * 100).round()}%', style: text.labelLarge),
                    ],
                  ),
                  Slider(
                    value: st.textScale,
                    min: 0.85,
                    max: 1.6,
                    divisions: 15,
                    label: '${(st.textScale * 100).round()}%',
                    semanticFormatterCallback: (v) => '${(v * 100).round()} percent',
                    onChanged: st.setTextScale,
                  ),
                  Text(
                    'Preview: Rainwater from one school roof can fill several classroom tanks.',
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('Applied on top of your device text size.', style: text.bodySmall),
                ],
              ),
            ),
            const SectionHeader('Motion and reading'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: st.reduceMotion,
                    onChanged: st.setReduceMotion,
                    secondary: const Icon(Icons.motion_photos_off_outlined),
                    title: const Text('Reduce motion'),
                    subtitle: Text(s.device.shouldConserveEnergy
                        ? 'Motion is already paused to save battery.'
                        : 'Stops the waves and celebrations. Follows your device setting too.'),
                  ),
                  if (s.speech.available) ...[
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.record_voice_over_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Read-aloud speed', style: text.titleSmall)),
                        TextButton(
                          onPressed: () => s.speech.speak(
                            'This is how lessons will sound when read aloud.',
                            id: 'settings-test',
                            rate: st.speechRate,
                          ),
                          child: const Text('Test'),
                        ),
                      ],
                    ),
                    Slider(
                      value: st.speechRate,
                      min: 0.3,
                      max: 0.7,
                      divisions: 8,
                      label: st.speechRate < 0.45 ? 'Slow' : st.speechRate > 0.55 ? 'Fast' : 'Normal',
                      semanticFormatterCallback: (v) => v < 0.45 ? 'Slow' : v > 0.55 ? 'Fast' : 'Normal',
                      onChanged: st.setSpeechRate,
                    ),
                  ],
                ],
              ),
            ),
            if (u?.role == Role.student) ...[
              const SectionHeader('Quizzes'),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Time per question', style: text.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<QuizTimerMode>(
                      segments: [
                        for (final m in QuizTimerMode.values) ButtonSegment(value: m, label: Text(m.label)),
                      ],
                      selected: {st.quizTimer},
                      onSelectionChanged: (v) => st.setQuizTimer(v.first),
                    ),
                    const SizedBox(height: 6),
                    Text('Extended time and no timer help students who read slowly or use a screen reader.',
                        style: text.bodySmall),
                  ],
                ),
              ),
            ],
            const SectionHeader('Data and notifications'),
            Panel(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: st.dataSaver,
                    onChanged: st.setDataSaver,
                    secondary: const Icon(Icons.data_saver_on_outlined),
                    title: const Text('Data saver'),
                    subtitle: Text(s.device.isCellular
                        ? 'On mobile data, images already load in lower quality.'
                        : 'Always load smaller images.'),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: st.quietHours,
                    onChanged: st.setQuietHours,
                    secondary: const Icon(Icons.notifications_paused_outlined),
                    title: const Text('Quiet during class'),
                    subtitle: const Text('Hold non-urgent notices from 8 am to 3 pm on school days.'),
                  ),
                ],
              ),
            ),
            if (u != null && u.role != Role.student) ...[
              const SectionHeader('Sign-in'),
              Panel(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _quickEnabled ?? false,
                  onChanged: !_bioAvailable || _quickEnabled == null
                      ? null
                      : (on) async {
                          if (on) {
                            final ok = await s.auth.enableQuickUnlock();
                            if (!context.mounted) return;
                            context.toast(ok ? 'Quick unlock is on for this device.' : 'Quick unlock was not turned on.', error: !ok);
                          } else {
                            await s.auth.forgetQuickUnlock();
                          }
                          unawaited(_loadQuick());
                        },
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Quick unlock with biometrics'),
                  subtitle: Text(_bioAvailable
                      ? 'Use your fingerprint, face or device PIN to sign in on this device.'
                      : 'Not available on this device.'),
                ),
              ),
            ],
            const SectionHeader('About'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Privacy and security'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/security'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Open-source licences'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLicensePage(context: context, applicationName: 'AquaAware', applicationVersion: '2.0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await confirmAction(context,
                    title: 'Sign out?', message: 'You will need your details to sign in again.', confirmLabel: 'Sign out');
                if (ok && context.mounted) await s.auth.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
