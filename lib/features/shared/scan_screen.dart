// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/platform/capabilities.dart';
import '../../core/theme/tokens.dart';
import '../../data/app_store.dart';
import '../../data/models/models.dart';
import '../../services/app_services.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class ScanOutcome {
  const ScanOutcome.success(this.title, this.message) : ok = true;
  const ScanOutcome.failure(this.title, this.message) : ok = false;
  final bool ok;
  final String title;
  final String message;
}

/// Camera scanner with a manual "paste the code" path that works on every
/// platform (and for anyone who can't aim a camera).
class CodeScanner extends StatefulWidget {
  const CodeScanner({super.key, required this.onCode, required this.manualHint});
  final Future<ScanOutcome> Function(String raw) onCode;
  final String manualHint;

  @override
  State<CodeScanner> createState() => _CodeScannerState();
}

class _CodeScannerState extends State<CodeScanner> {
  MobileScannerController? _controller;
  late bool _manual = !Caps.canScanWithCamera;
  final _input = TextEditingController();
  bool _busy = false;
  ScanOutcome? _outcome;
  int _burst = 0;
  String? _lastRaw;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (Caps.canScanWithCamera) {
      _controller = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    _input.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _busy) return;
    final now = DateTime.now();
    if (code == _lastRaw && now.difference(_lastAt) < const Duration(seconds: 3)) return;
    _lastRaw = code;
    _lastAt = now;
    setState(() => _busy = true);
    _stopCamera();
    final outcome = await widget.onCode(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
      if (outcome.ok) _burst++;
    });
    if (outcome.ok) {
      unawaited(HapticFeedback.mediumImpact());
    } else {
      unawaited(HapticFeedback.heavyImpact());
    }
    context.announce('${outcome.title}. ${outcome.message}');
  }

  /// Pauses detection while a code is checked. The MobileScanner widget
  /// starts the camera again by itself (autoStart) when it is shown again,
  /// so the camera is never started twice from here.
  void _stopCamera() {
    final c = _controller;
    if (c == null) return;
    unawaited(c.stop().catchError((Object _) {}));
  }

  void _again() {
    setState(() {
      _outcome = null;
      _input.clear();
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t != null) setState(() => _input.text = t.trim());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final outcome = _outcome;
    return DropletBurst(
      trigger: _burst,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (Caps.canScanWithCamera)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.qr_code_scanner), label: Text('Camera')),
                  ButtonSegment(value: true, icon: Icon(Icons.keyboard_outlined), label: Text('Enter code')),
                ],
                selected: {_manual},
                // Showing or hiding the camera view starts or stops it.
                onSelectionChanged: (v) => setState(() => _manual = v.first),
              ),
            ),
          Expanded(
            child: outcome != null
                ? _result(context, outcome)
                : _manual
                    ? _manualEntry(context)
                    : _camera(context),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (!Caps.canScanWithCamera && outcome == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Camera scanning is not available on ${Caps.platformName}. Paste the code instead.', style: text.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _camera(BuildContext context) {
    final controller = _controller!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AqRadius.hero),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                for (final b in capture.barcodes) {
                  final v = b.rawValue;
                  if (v != null && v.isNotEmpty) {
                    unawaited(_handle(v));
                    break;
                  }
                }
              },
              errorBuilder: (context, error) => Container(
                color: AqColors.ink,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'The camera is not available. Allow camera access in system settings, or enter the code instead.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => setState(() => _manual = true), child: const Text('Enter code instead')),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(AqRadius.sheet),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(AqRadius.pill)),
                  child: const Text('Fit the QR code inside the frame', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                tooltip: 'Torch',
                onPressed: () => unawaited(controller.toggleTorch().catchError((Object _) {})),
                icon: const Icon(Icons.flashlight_on_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualEntry(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(widget.manualHint, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _input,
          minLines: 3,
          maxLines: 5,
          maxLength: 2048,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Code',
            hintText: 'AQ1.…',
            suffixIcon: IconButton(tooltip: 'Paste', icon: const Icon(Icons.content_paste), onPressed: _paste),
          ),
        ),
        const SizedBox(height: 8),
        BusyButton(label: 'Check code', icon: Icons.verified_user_outlined, onPressed: () => _handle(_input.text)),
      ],
    );
  }

  Widget _result(BuildContext context, ScanOutcome o) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Panel(
          color: o.ok ? scheme.tertiaryContainer : scheme.errorContainer,
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(o.ok ? Icons.verified : Icons.gpp_bad_outlined, size: 40,
                    color: o.ok ? scheme.onTertiaryContainer : scheme.onErrorContainer),
                const SizedBox(height: 10),
                Text(o.title, style: text.headlineSmall?.copyWith(color: o.ok ? scheme.onTertiaryContainer : scheme.onErrorContainer)),
                const SizedBox(height: 6),
                Text(o.message, style: text.bodyLarge?.copyWith(color: o.ok ? scheme.onTertiaryContainer : scheme.onErrorContainer)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _again, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan another')),
      ],
    );
  }
}

/// Students: check in to NGO events.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final u = s.auth.user;
    final isDesk = u?.role == Role.ngo;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(isDesk ? 'Redeem a reward' : 'Scan an event code'),
      ),
      body: SafeArea(
        child: CodeScanner(
          manualHint: isDesk
              ? 'Paste the ticket code the person copied from their reward ticket.'
              : 'Paste the event code shared by the NGO volunteer.',
          onCode: (raw) => isDesk ? redeemOutcome(context, raw) : checkInOutcome(context, raw),
        ),
      ),
    );
  }
}

Future<ScanOutcome> checkInOutcome(BuildContext context, String raw) async {
  final s = context.services;
  final u = s.auth.user;
  if (u == null || u.role != Role.student) {
    return const ScanOutcome.failure('Not signed in as a member', 'Sign in as a student or member to check in to events.');
  }
  try {
    final r = await s.store.checkIn(raw, student: u);
    return ScanOutcome.success('Checked in', 'Welcome to ${r.activityName}! +${r.points} points.');
  } on ActionRefused catch (e) {
    return ScanOutcome.failure('Check-in refused', e.message);
  }
}

Future<ScanOutcome> redeemOutcome(BuildContext context, String raw) async {
  final s = context.services;
  final u = s.auth.user;
  if (u == null || u.role != Role.ngo) {
    return const ScanOutcome.failure('Not a reward desk', 'Only NGO desks can redeem rewards.');
  }
  try {
    final r = await s.store.redeemClaim(raw, desk: u);
    final where = r.claim.locationVerified ? 'Their phone confirmed they are at the desk.' : 'Their phone did not confirm location — check in person.';
    return ScanOutcome.success(
      'Hand over: ${r.claim.rewardName}',
      'Signature valid and ticket unused. Give it to ${r.studentName}. ${r.claim.points} points were deducted. $where',
    );
  } on ActionRefused catch (e) {
    return ScanOutcome.failure('Do not hand over', e.message);
  }
}
