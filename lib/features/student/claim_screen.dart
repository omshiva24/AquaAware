import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/platform/location_service.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../data/models/models.dart';
import '../../data/seed/community_seed.dart';
import '../../services/app_services.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class ClaimScreen extends StatefulWidget {
  const ClaimScreen({super.key, required this.claimId});
  final String claimId;

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  Timer? _clock;
  bool _locating = false;
  String? _locNote;
  Tone _locTone = Tone.neutral;
  int _burst = 0;
  ClaimStatus? _seenStatus;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _scan.stop();
    } else if (!_scan.isAnimating) {
      _scan.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scan.dispose();
    super.dispose();
  }

  /// Q8 — advisory geofence: within 100 m of the desk (plus GPS accuracy,
  /// capped). The desk's signed-QR scan remains the authoritative check.
  Future<void> _checkLocation(RewardClaim claim) async {
    setState(() {
      _locating = true;
      _locNote = null;
    });
    final r = await LocationService.current();
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _locating = false;
        _locNote = '${r.describeProblem()} The desk can still verify your ticket in person.';
        _locTone = Tone.warning;
      });
      return;
    }
    final d = Geo.distanceMeters(r.point!, CommunitySeed.rewardDesk);
    final slack = (r.accuracyMeters ?? 0).clamp(0.0, 50.0);
    final inside = d <= CommunitySeed.rewardDeskRadiusMeters + slack;
    if (r.mocked) {
      setState(() {
        _locating = false;
        _locNote = 'Your location looks simulated by another app, so it was not accepted. The desk will check your ticket in person.';
        _locTone = Tone.danger;
      });
      context.services.store.logEvent(claim.studentName, 'had a simulated location rejected');
      return;
    }
    if (inside) await context.services.store.markClaimLocation(claim.id);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locNote = inside
          ? 'You are at the desk. Show your ticket now.'
          : 'You are ${Geo.describeDistance(d)} from the desk. Come within ${CommunitySeed.rewardDeskRadiusMeters.round()} m to collect.';
      _locTone = inside ? Tone.success : Tone.warning;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Reward ticket'),
      ),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) {
          final claim = s.store.claimById(widget.claimId);
          final u = s.auth.user;
          if (claim == null || u == null || claim.studentId != u.id) {
            return const EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Ticket not found',
              message: 'It may have been cancelled. Open Rewards to see your claims.',
            );
          }
          if (_seenStatus == ClaimStatus.pending && claim.status == ClaimStatus.redeemed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _burst++);
            });
          }
          _seenStatus = claim.status;
          return DropletBurst(trigger: _burst, child: _body(context, claim));
        },
      ),
    );
  }

  Widget _body(BuildContext context, RewardClaim claim) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final expired = claim.isExpired();
    final (label, tone, icon) = switch (claim.status) {
      ClaimStatus.redeemed => ('Collected', Tone.success, Icons.verified),
      ClaimStatus.cancelled => ('Cancelled', Tone.neutral, Icons.cancel_outlined),
      ClaimStatus.pending => expired ? ('Expired', Tone.warning, Icons.timer_off_outlined) : ('Ready to show', Tone.info, Icons.qr_code_2),
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(children: [Pill(label, tone: tone, icon: icon)]),
            const SizedBox(height: 12),
            Text(claim.rewardName, style: text.headlineMedium),
            Text('${claim.points} points', style: text.titleMedium?.copyWith(color: scheme.onSecondaryContainer)),
            const SizedBox(height: 20),
            if (claim.isOpen) ...[
              _qrCard(context, claim),
              const SizedBox(height: 10),
              Text('Turn your screen brightness up and show this at the desk. It works once.',
                  style: text.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 20),
            ],
            if (claim.status == ClaimStatus.redeemed)
              Panel(
                color: scheme.tertiaryContainer,
                child: Row(
                  children: [
                    Icon(Icons.verified, color: scheme.onTertiaryContainer, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Collected ${Fmt.date(claim.redeemedAt ?? claim.createdAt)} at ${Fmt.time(claim.redeemedAt ?? claim.createdAt)}'
                        '${claim.redeemedBy == null ? '' : ' from ${claim.redeemedBy}'}. Enjoy it!',
                        style: text.bodyLarge?.copyWith(color: scheme.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.place_outlined),
                    title: Text('Where to collect'),
                    subtitle: Text(CommunitySeed.rewardDeskLabel),
                  ),
                  ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Valid until'),
                    subtitle: Text(expired
                        ? 'Expired on ${Fmt.date(claim.expiresAt)}'
                        : '${Fmt.date(claim.expiresAt)} (${Fmt.duration(claim.expiresAt.difference(DateTime.now()))} left)'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: const Text('Ticket'),
                    subtitle: Text(claim.id),
                  ),
                ],
              ),
            ),
            if (claim.isOpen) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _locating ? null : () => _checkLocation(claim),
                icon: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(claim.locationVerified ? Icons.where_to_vote : Icons.my_location),
                label: Text(claim.locationVerified ? 'Location confirmed at the desk' : 'Check I am at the desk'),
              ),
              if (_locNote != null) ...[
                const SizedBox(height: 10),
                Semantics(liveRegion: true, child: InfoNote(_locNote!, tone: _locTone)),
              ],
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: claim.token));
                  if (context.mounted) context.toast('Ticket code copied. Share it only with the NGO desk.');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy ticket code (if the desk cannot scan)'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: () async {
                  final ok = await confirmAction(context,
                      title: 'Cancel this claim?',
                      message: 'Your ${claim.points} points will be free to use again.',
                      confirmLabel: 'Cancel claim',
                      destructive: true);
                  if (!ok || !context.mounted) return;
                  await context.services.store.cancelClaim(claim.id);
                  if (context.mounted) context.toast('Claim cancelled. Your points are free again.');
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel claim'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _qrCard(BuildContext context, RewardClaim claim) {
    const size = 240.0;
    // The first version swept a scan line across a fake code. A real code
    // must stay clean to scan reliably, so the motion lives in the frame.
    return Center(
      child: AnimatedBuilder(
        animation: _scan,
        builder: (context, child) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AqRadius.hero),
            border: Border.all(color: Color.lerp(AqColors.line, AqColors.tide, _scan.value)!, width: 3),
            boxShadow: [
              BoxShadow(color: AqColors.shallows.withValues(alpha: 0.35 * _scan.value), blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: child,
        ),
        child: QrImageView(
          data: claim.token,
          size: size,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          semanticsLabel: 'QR ticket for ${claim.rewardName}',
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AqColors.ink),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AqColors.ink),
        ),
      ),
    );
  }
}
