import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/capabilities.dart';
import '../../core/security/secure_vault.dart';
import '../../core/utils/format.dart';
import '../../data/models/models.dart';
import '../../services/app_services.dart';
import '../../widgets/common.dart';

/// The first version listed "AES-256 · Active", "TLS 1.3 · Active" as fixed
/// labels. Here every claim is a live check you can re-run.
class SecurityCenterScreen extends StatefulWidget {
  const SecurityCenterScreen({super.key});

  @override
  State<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends State<SecurityCenterScreen> {
  bool? _cryptoOk;
  bool _running = false;
  DateTime? _ranAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runChecks());
  }

  Future<void> _runChecks() async {
    final s = context.services;
    setState(() => _running = true);
    final ok = await s.vault.selfTest();
    await s.store.reverifyLedger();
    if (!mounted) return;
    setState(() {
      _cryptoOk = ok;
      _running = false;
      _ranAt = DateTime.now();
    });
    context.announce(ok && s.store.ledgerIntact ? 'All security checks passed' : 'A security check failed');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Privacy and security'),
        actions: [
          IconButton(
            tooltip: 'Run checks again',
            onPressed: _running ? null : _runChecks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.store, s.sync, s.auth]),
        builder: (context, _) {
          final u = s.auth.user;
          final staff = u != null && u.role != Role.student;
          final exp = s.auth.expiresAt;
          return PageFrame(
            maxWidth: 760,
            children: [
              if (_running) const LinearProgressIndicator(),
              if (_ranAt != null)
                Text('Checked at ${Fmt.time(_ranAt!)} on ${Caps.platformName}', style: text.bodySmall),
              const SectionHeader('Live checks'),
              Card(
                child: Column(
                  children: [
                    _Check(
                      title: 'Encryption at rest',
                      detail: 'AES-256-GCM round trip, and a flipped bit is rejected',
                      state: _cryptoOk,
                    ),
                    _Check(
                      title: 'Points ledger',
                      detail: s.store.ledgerIntact
                          ? '${s.store.ledger.length} entries, hash chain verified'
                          : 'Chain broken at entry ${s.store.ledgerBrokenAt + 1} — awards are paused',
                      state: s.store.ledgerIntact,
                    ),
                    _Check(
                      title: 'Stored data integrity',
                      detail: s.vault.tamperEvents == 0
                          ? 'No modified data found since the app started'
                          : '${s.vault.tamperEvents} modified blob(s) were rejected',
                      state: s.vault.tamperEvents == 0,
                    ),
                    _Check(
                      title: 'Key storage',
                      detail: s.vault.health == VaultHealth.secure
                          ? 'Keys in the ${_keystoreName()} · fingerprint ${s.vault.keyFingerprint}'
                          : 'Platform keystore unavailable — data is kept in memory only this session',
                      state: s.vault.health == VaultHealth.secure,
                    ),
                    _Check(
                      title: 'Server sync',
                      detail: s.sync.describe(),
                      state: !s.sync.isConfigured
                          ? null
                          : s.sync.hasServerSession && s.sync.pendingCount == 0
                              ? true
                              : null,
                      neutralLabel: !s.sync.isConfigured
                          ? 'Offline'
                          : s.sync.hasServerSession
                              ? 'Sending'
                              : 'Waiting',
                      trailing: s.sync.hasServerSession && s.sync.pendingCount > 0
                          ? TextButton(onPressed: s.sync.isFlushing ? null : () => unawaited(s.sync.syncNow()), child: const Text('Send now'))
                          : null,
                    ),
                    if (staff)
                      _Check(
                        title: 'Sign-in protection',
                        detail: s.store.activeLockouts == 0
                            ? 'No accounts are locked out'
                            : '${s.store.activeLockouts} sign-in(s) locked after repeated failures',
                        state: s.store.activeLockouts == 0 ? true : null,
                        neutralLabel: 'Lockout active',
                      ),
                  ],
                ),
              ),
              const SectionHeader('Your session'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(u?.name ?? 'Not signed in'),
                      subtitle: Text(u?.role.label ?? ''),
                    ),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Session ends'),
                      subtitle: Text(exp == null
                          ? '—'
                          : 'At ${Fmt.time(exp)}, or after 15 minutes without activity'),
                    ),
                  ],
                ),
              ),
              const SectionHeader('How your data is protected'),
              const _Explainer(),
              if (u?.role == Role.manager) ...[
                const SectionHeader('Demo data'),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Erase everything on this device and restore the pilot data. Everyone is signed out.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                        onPressed: () async {
                          final ok = await confirmAction(context,
                              title: 'Reset all data?',
                              message: 'Claims, messages, points and registrations made on this device will be deleted.',
                              confirmLabel: 'Reset',
                              destructive: true);
                          if (!ok || !context.mounted) return;
                          await s.store.resetDemoData();
                          await s.auth.forgetQuickUnlock();
                          await s.auth.signOut(reason: 'Demo data was reset.');
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset demo data'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _keystoreName() {
    if (Caps.isWeb) return 'browser (WebCrypto)';
    if (Caps.isAndroid) return 'Android Keystore';
    if (Caps.isIOS) return 'iOS Keychain';
    return switch (Caps.platformName) {
      'macOS' => 'macOS Keychain',
      'Windows' => 'Windows DPAPI store',
      'Linux' => 'Secret Service keyring',
      _ => 'platform keystore',
    };
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.title, required this.detail, required this.state, this.neutralLabel = 'Checking', this.trailing});
  final String title;
  final String detail;

  /// true = pass, false = fail, null = neutral / pending.
  final bool? state;
  final String neutralLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = switch (state) {
      true => ('Pass', Tone.success, Icons.check_circle),
      false => ('Fail', Tone.danger, Icons.error),
      null => (neutralLabel, Tone.neutral, Icons.pending_outlined),
    };
    final c = toneColors(context, tone);
    return ListTile(
      leading: Icon(icon, color: tone == Tone.neutral ? null : c.fg),
      title: Text(title),
      subtitle: Text(detail),
      trailing: trailing ?? Pill(label, tone: tone),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  static const _rows = <(IconData, String, String)>[
    (Icons.lock_outline, 'Confidentiality',
        'Everything saved on this device is encrypted with AES-256-GCM. The keys live in the platform keystore, never in plain storage.'),
    (Icons.fact_check_outlined, 'Integrity',
        'Points are kept in a hash-chained ledger signed with HMAC-SHA256, so editing any past entry is detected. Quiz results sent to a server are signed too.'),
    (Icons.qr_code_2, 'Reward codes',
        'Each reward ticket is signed, expires after 7 days and works once. Copies and edited codes are refused at the desk.'),
    (Icons.password, 'Sign-in',
        'Passwords and PINs are stored only as salted PBKDF2 hashes (100,000 rounds). Five wrong tries lock that sign-in for a while.'),
    (Icons.https_outlined, 'In transit',
        'The app only talks to HTTPS servers (TLS 1.2 or 1.3 through the platform). Each request has an idempotency key so retries never double-count.'),
    (Icons.privacy_tip_outlined, 'Privacy',
        'Phone numbers are masked until an educator chooses to reveal one. Location and camera are used only when you tap a button that needs them.'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Column(
        children: [
          for (final r in _rows)
            ListTile(
              leading: Icon(r.$1),
              title: Text(r.$2, style: text.titleSmall),
              subtitle: Text(r.$3, style: text.bodyMedium),
            ),
        ],
      ),
    );
  }
}
