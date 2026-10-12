import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/security/input_rules.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../data/app_store.dart';
import '../../data/models/models.dart';
import '../../data/points_rules.dart';
import '../../data/seed/community_seed.dart';
import '../../services/app_services.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key, required this.pickupId});
  final String pickupId;

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  Timer? _clock;
  int _burst = 0;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Waste pickup'),
      ),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) {
          final p = s.store.pickupById(widget.pickupId);
          final u = s.auth.user;
          if (p == null || u == null || p.studentId != u.id) {
            return const EmptyState(icon: Icons.local_shipping_outlined, title: 'Pickup not found', message: 'Open the eco-map to request one.');
          }
          return DropletBurst(trigger: _burst, child: _body(context, p));
        },
      ),
    );
  }

  Widget _body(BuildContext context, PickupRequest p) {
    final s = context.services;
    final c = CommunitySeed.collector(p.collectorId);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final arrival = p.requestedAt.add(Duration(minutes: p.etaMinutes));
    final left = arrival.difference(DateTime.now());
    final elapsed = DateTime.now().difference(p.requestedAt).inSeconds / (p.etaMinutes * 60);
    final phone = InputRules.normalizePhone(c.phone);

    final headline = switch (p.status) {
      PickupStatus.onTheWay => left.isNegative ? '${c.name} should be with you now' : '${c.name} is on the way',
      PickupStatus.handedOver => 'Handed over — thank you!',
      PickupStatus.cancelled => 'Pickup cancelled',
    };

    final steps = <(String, String, bool)>[
      ('Requested', Fmt.time(p.requestedAt), true),
      ('On the way', p.status == PickupStatus.cancelled ? 'Cancelled' : 'About ${p.etaMinutes} min, ${Geo.describeDistance(p.distanceMeters)}', p.status != PickupStatus.cancelled),
      ('Handed over', p.status == PickupStatus.handedOver ? Fmt.time(p.closedAt ?? DateTime.now()) : '+${PointRules.pickupHandedOver} points', p.status == PickupStatus.handedOver),
    ];

    return PageFrame(
      maxWidth: 620,
      children: [
        Semantics(header: true, child: Text(headline, style: text.headlineMedium)),
        const SizedBox(height: 4),
        Text('${c.wasteType} waste · ${c.area}', style: text.bodyMedium),
        if (p.status == PickupStatus.onTheWay) ...[
          const SizedBox(height: 18),
          Semantics(
            label: left.isNegative ? 'Arriving now' : 'Arriving in about ${left.inMinutes + 1} minutes',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(left.isNegative ? 'Arriving now' : 'About ${left.inMinutes + 1} min away', style: text.titleLarge),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: elapsed.clamp(0.0, 1.0), minHeight: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++)
                ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: steps[i].$3 ? scheme.primary : scheme.surfaceContainerHighest,
                    foregroundColor: steps[i].$3 ? scheme.onPrimary : scheme.onSurfaceVariant,
                    child: steps[i].$3 ? const Icon(Icons.check, size: 18) : Text('${i + 1}'),
                  ),
                  title: Text(steps[i].$1),
                  subtitle: Text(steps[i].$2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (p.status == PickupStatus.onTheWay) ...[
          if (!s.store.canConfirmPickup(p)) ...[
            Text('You can confirm the handover once ${c.name} has arrived.', style: text.bodySmall),
            const SizedBox(height: 8),
          ],
          BusyButton(
            label: s.store.canConfirmPickup(p) ? 'I handed over my waste' : 'Waiting for ${c.name}…',
            icon: Icons.handshake_outlined,
            onPressed: !s.store.canConfirmPickup(p) ? null : () async {
              try {
                final pts = await s.store.completePickup(p.id);
                if (!context.mounted) return;
                setState(() => _burst++);
                context.toast(pts > 0 ? 'Thank you! +$pts points' : 'Pickup complete');
              } on ActionRefused catch (e) {
                if (context.mounted) context.toast(e.message, error: true);
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: phone == null ? null : () => launchUrl(Uri(scheme: 'tel', path: phone)),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: phone == null ? null : () => launchUrl(Uri(scheme: 'sms', path: phone)),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('SMS'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () async {
              final ok = await confirmAction(context,
                  title: 'Cancel this pickup?', message: '${c.name} will be told not to come.', confirmLabel: 'Cancel pickup', destructive: true);
              if (ok) await s.store.cancelPickup(p.id);
            },
            child: const Text('Cancel pickup'),
          ),
          const SizedBox(height: 10),
          const InfoNote('Keep your waste bagged by type. Collectors only take segregated waste.', tone: Tone.neutral, icon: Icons.recycling),
        ] else
          FilledButton(onPressed: () => context.go('/student'), child: const Text('Back to home')),
      ],
    );
  }
}
