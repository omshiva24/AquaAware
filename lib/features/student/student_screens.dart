// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/platform/device_context.dart';
import '../../core/platform/location_service.dart';
import '../../core/security/input_rules.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/geo.dart';
import '../../data/app_store.dart';
import '../../data/models/models.dart';
import '../../data/points_rules.dart';
import '../../data/seed/community_seed.dart';
import '../../data/seed/content_seed.dart';
import '../../services/app_services.dart';
import '../../widgets/common.dart';
import '../../widgets/eco_map.dart';
import '../../widgets/motion.dart';
import '../../widgets/reservoir.dart';
import 'learn_screens.dart';

// ======================================================================= HOME

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  /// Q7 — the 4W context model: Who (name), When (time of day),
  /// Where (the group's day: at school, at college, at work), What (the next
  /// useful action).
  static String greeting(DateTime now) {
    final part = now.hour < 12 ? 'morning' : now.hour < 17 ? 'afternoon' : 'evening';
    return 'Good $part';
  }

  static String whereLine(DateTime now, [InstitutionKind kind = InstitutionKind.school]) {
    if (kind == InstitutionKind.community) return 'Every small action counts';
    final start = kind.holdsNoticesDuringDay ? 8 : 9;
    final duringDay = now.weekday <= DateTime.friday && now.hour >= start && now.hour < kind.dayEndHour;
    if (duringDay) return 'You are probably ${kind.atPlace}';
    return kind.holdsNoticesDuringDay ? 'Learning from home' : 'Away from work';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([s.store, s.device, s.settings]),
      builder: (context, _) {
        final u = s.auth.user;
        if (u == null) return const SizedBox.shrink();
        final now = DateTime.now();
        final store = s.store;
        final points = store.balanceOf(u.id);
        final level = EcoLevels.of(points);
        final next = EcoLevels.next(points);
        final progress = EcoLevels.progress(points);
        final streak = store.streakOf(u.id);
        final tasks = store.openTasksFor(u);
        final pickup = store.activePickupFor(u.id);
        final done = store.progressOf(u.id).modulesDone;
        final nextModule = ContentSeed.modules.where((m) => !done.contains(m.id)).firstOrNull;
        final text = Theme.of(context).textTheme;
        final kind = store.kindOf(u.classCode);

        return Scaffold(
          appBar: aqAppBar(context, '${greeting(now)}, ${u.firstName}'),
          body: PageFrame(
            children: [
              Text(
                '${Fmt.weekday(now)} · ${whereLine(now, kind)} · ${u.classCode ?? ''}',
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              RiseIn(
                child: Reservoir(
                  level: next == null ? 1 : (EcoLevels.all.indexOf(level) + progress) / (EcoLevels.all.length - 1),
                  marks: [for (var i = 1; i < EcoLevels.all.length - 1; i++) i / (EcoLevels.all.length - 1)],
                  semanticLabel:
                      'Your reservoir. $points points, ${level.name} level. ${next == null ? 'Top level reached.' : '${next.minPoints - points} points to ${next.name}.'} $streak day streak.',
                  child: _ReservoirContent(points: points, level: level, next: next, streak: streak),
                ),
              ),
              if (pickup != null) ...[
                const SizedBox(height: 12),
                _PickupBanner(pickup: pickup),
              ],
              _TaskSection(user: u, tasks: tasks),
              const SectionHeader('Quick actions'),
              _QuickActions(user: u, nextModule: nextModule),
              SectionHeader('${kind.label} water meter',
                  subtitle: 'Live from the ${kind.noun} tank (simulated until the meter is fitted)'),
              _WaterMeterCard(user: u),
              const SizedBox(height: 16),
              InfoNote(ContentSeed.tipFor(now), tone: Tone.neutral, icon: Icons.lightbulb_outline),
              _EducatorReplies(user: u),
            ],
          ),
        );
      },
    );
  }
}

class _ReservoirContent extends StatelessWidget {
  const _ReservoirContent({required this.points, required this.level, required this.next, required this.streak});
  final int points;
  final EcoLevel level;
  final EcoLevel? next;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const white = Colors.white;
    final soft = Colors.white.withValues(alpha: 0.92); // 4.5:1+ over the water
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your reservoir', style: text.labelLarge?.copyWith(color: soft))),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AqRadius.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_outlined, size: 16, color: AqColors.ochre),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('$streak-day streak',
                            style: text.labelMedium?.copyWith(color: white), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          AnimatedCount(value: points, style: text.displayMedium?.copyWith(color: white)),
          Text('points · ${level.name}', style: text.titleMedium?.copyWith(color: white)),
          const SizedBox(height: 4),
          Text(
            next == null ? level.meaning : '${next!.minPoints - points} more to reach ${next!.name}',
            style: text.bodyMedium?.copyWith(color: soft),
          ),
        ],
      ),
    );
  }
}

class _PickupBanner extends StatelessWidget {
  const _PickupBanner({required this.pickup});
  final PickupRequest pickup;

  @override
  Widget build(BuildContext context) {
    final c = CommunitySeed.collector(pickup.collectorId);
    return Panel(
      onTap: () => context.push('/pickup/${pickup.id}'),
      semanticLabel: '${c.name} is on the way. Open pickup details.',
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text('${c.name} is on the way for your ${c.wasteType.toLowerCase()} waste')),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _TaskSection extends StatefulWidget {
  const _TaskSection({required this.user, required this.tasks});
  final SessionUser user;
  final List<Announcement> tasks;

  @override
  State<_TaskSection> createState() => _TaskSectionState();
}

class _TaskSectionState extends State<_TaskSection> {
  bool _showHeld = false;
  int _burst = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final now = DateTime.now();
    // Q2 — at schools and colleges, non-urgent notices that arrive during
    // class wait until 3 pm. Offices and communities get them straight away.
    final holds = s.store.kindOf(widget.user.classCode).holdsNoticesDuringDay;
    final classTime = holds && s.settings.quietHours && AppStore.isQuietHours(now);
    final held = classTime && !_showHeld
        ? widget.tasks.where((a) => !a.urgent && Fmt.dayKey(a.sentAt) == Fmt.dayKey(now) && a.sentAt.hour >= 8).toList()
        : <Announcement>[];
    final visible = widget.tasks.where((a) => !held.contains(a)).toList();

    return DropletBurst(
      trigger: _burst,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Tasks for you',
            subtitle: widget.tasks.isEmpty ? null : '${Fmt.plural(widget.tasks.length, 'task')} waiting',
          ),
          if (widget.tasks.isEmpty)
            Panel(
              child: Row(
                children: [
                  const Icon(Icons.task_alt),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are all caught up. New tasks from your '
                      '${context.services.store.kindOf(widget.user.classCode).leaderNoun} and NGOs appear here.',
                    ),
                  ),
                ],
              ),
            ),
          if (held.isNotEmpty) ...[
            InfoNote(
              '${Fmt.plural(held.length, 'notice')} arrived during class and will show after 3 pm.',
              tone: Tone.neutral,
              icon: Icons.notifications_paused_outlined,
              action: TextButton(onPressed: () => setState(() => _showHeld = true), child: const Text('Show now')),
            ),
            const SizedBox(height: 10),
          ],
          for (final a in visible.take(3)) ...[
            _TaskCard(
              announcement: a,
              onDone: () async {
                try {
                  final pts = await s.store.completeAnnouncement(a.id, widget.user.id);
                  if (!context.mounted) return;
                  setState(() => _burst++);
                  context.toast(pts > 0 ? 'Done! +$pts points' : 'Marked as done');
                } on ActionRefused catch (e) {
                  if (context.mounted) context.toast(e.message, error: true);
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.announcement, required this.onDone});
  final Announcement announcement;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final text = Theme.of(context).textTheme;
    final fromNgo = a.senderRole == Role.ngo;
    return Panel(
      color: fromNgo ? Theme.of(context).colorScheme.tertiaryContainer : Theme.of(context).colorScheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(fromNgo ? Icons.volunteer_activism_outlined : Icons.co_present_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${fromNgo ? 'From NGO' : 'From your ${context.services.store.kindOf(a.audience).leaderNoun}'} · ${a.senderName}',
                  style: text.labelLarge,
                ),
              ),
              if (a.urgent) const Pill('Urgent', tone: Tone.danger, icon: Icons.priority_high),
            ],
          ),
          const SizedBox(height: 8),
          Text(a.message, style: text.bodyLarge),
          const SizedBox(height: 6),
          Text(Fmt.relative(a.sentAt), style: text.bodySmall),
          const SizedBox(height: 12),
          BusyButton(label: 'Mark as done  (+${a.points} points)', icon: Icons.check, onPressed: onDone),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.user, required this.nextModule});
  final SessionUser user;
  final LearningModule? nextModule;

  Future<void> _messageEducator(BuildContext context) async {
    final s = context.services;
    final edu = s.store.educatorFor(user.classCode ?? '');
    if (edu == null) {
      final k = s.store.kindOf(user.classCode);
      context.toast('Your ${k.groupNoun} has no ${k.leaderNoun} yet.', error: true);
      return;
    }
    await context.push('/thread/${edu.id}');
  }

  @override
  Widget build(BuildContext context) {
    final leader = context.services.store.kindOf(user.classCode).leaderNoun;
    final items = <(IconData, String, String, VoidCallback)>[
      (
        moduleIcon(nextModule?.id ?? 'MOD_A'),
        nextModule == null ? 'Review lessons' : 'Continue learning',
        nextModule?.title ?? 'All modules done',
        () {
          final m = nextModule;
          if (m == null) {
            context.go('/student/learn');
          } else {
            context.push('/learn/${m.id}');
          }
        },
      ),
      (Icons.qr_code_scanner, 'Scan event code', 'Check in to NGO events', () => context.push('/scan')),
      (Icons.local_shipping_outlined, 'Request pickup', 'Nearest collectors', () => context.go('/student/map')),
      (Icons.forum_outlined, 'Message $leader', 'Ask a question', () => _messageEducator(context)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 640 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final it in items)
            SizedBox(
              width: w,
              child: Panel(
                onTap: it.$4,
                semanticLabel: '${it.$2}. ${it.$3}',
                padding: const EdgeInsets.all(14),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(it.$1, color: scheme.primary),
                      const SizedBox(height: 10),
                      Text(it.$2, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(it.$3, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _WaterMeterCard extends StatelessWidget {
  const _WaterMeterCard({required this.user});
  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final now = DateTime.now();
    final r = WaterMeter.read(now);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final kind = s.store.kindOf(user.classCode);
    final dayOver = now.hour >= kind.dayEndHour || now.weekday > DateTime.friday;
    final ref = 'water:${Fmt.dayKey(now)}';
    final claimed = s.store.hasEarned(user.id, ref);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${r.usedLitres} L', style: text.headlineMedium),
                    TextSpan(text: '  of ${r.targetLitres} L target', style: text.bodyMedium),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Pill(r.underTarget ? 'On track' : 'Over target',
                  tone: r.underTarget ? Tone.success : Tone.warning,
                  icon: r.underTarget ? Icons.check : Icons.warning_amber_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Water used today: ${r.usedLitres} of ${r.targetLitres} litres',
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (r.usedLitres / r.targetLitres).clamp(0.0, 1.0),
                  minHeight: 12,
                  color: r.underTarget ? scheme.primary : scheme.secondary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!r.underTarget)
            Text('The tank is over target today. Report any running taps to your ${kind.leaderNoun}.', style: text.bodySmall)
          else if (claimed)
            Text('Bonus collected for today. Thanks for saving water!', style: text.bodySmall)
          else if (!dayOver)
            Text('If your ${kind.noun} stays under ${r.targetLitres} L, everyone can collect '
                '+${PointRules.waterTargetBonus} points after ${kind.dayEndLabel}.',
                style: text.bodySmall)
          else
            BusyButton(
              label: 'Collect +${PointRules.waterTargetBonus} water bonus',
              icon: Icons.water_drop_outlined,
              tonal: true,
              onPressed: () async {
                try {
                  final pts = await s.store.claimWaterBonus(user.id);
                  if (context.mounted) context.toast('+$pts points for a water-wise day');
                } on ActionRefused catch (e) {
                  if (context.mounted) context.toast(e.message, error: true);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _EducatorReplies extends StatelessWidget {
  const _EducatorReplies({required this.user});
  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final edu = s.store.educatorFor(user.classCode ?? '');
    if (edu == null) return const SizedBox.shrink();
    final thread = s.store.thread(user.id, edu.id);
    if (thread.isEmpty) return const SizedBox.shrink();
    final last = thread.last;
    final unread = s.store.unreadFor(user.id, fromId: edu.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Messages', action: 'Open', onAction: () => context.push('/thread/${edu.id}')),
        Panel(
          onTap: () => context.push('/thread/${edu.id}'),
          semanticLabel: 'Conversation with ${edu.name}. ${unread > 0 ? '$unread unread.' : ''}',
          child: Row(
            children: [
              CircleAvatar(child: Text(edu.name.split(' ').where((p) => !p.endsWith('.')).first[0])),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(edu.name, style: Theme.of(context).textTheme.titleSmall),
                    Text(last.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (unread > 0) Badge(label: Text('$unread')),
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================================== MAP

class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  GeoPoint? _me;
  bool _locating = false;

  Future<void> _locate() async {
    setState(() => _locating = true);
    final r = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (r.ok) _me = r.point;
    });
    if (!r.ok) context.toast(r.describeProblem(), error: true);
  }

  GeoPoint get _origin => _me ?? CommunitySeed.schools.first.location;

  List<MapPlace> _places(AppStore store) => [
        for (final c in CommunitySeed.collectors)
          MapPlace(
            id: c.id,
            name: c.name,
            subtitle: '${c.wasteType} collector · ${c.area}',
            point: c.location,
            kind: PlaceKind.collector,
            status: store.collectorBusy(c) ? 'Busy' : 'Available',
            statusTone: store.collectorBusy(c) ? Tone.danger : Tone.success,
          ),
        for (final sc in CommunitySeed.schools)
          MapPlace(id: sc.id, name: sc.name, subtitle: sc.type, point: sc.location, kind: PlaceKind.school),
        for (final n in CommunitySeed.ngos)
          MapPlace(id: n.id, name: n.name, subtitle: 'NGO partner · ${n.area}', point: n.location, kind: PlaceKind.ngo),
      ];

  Future<void> _openPlace(MapPlace p) async {
    if (p.kind != PlaceKind.collector) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(p.subtitle),
              const SizedBox(height: 8),
              Text('${Geo.describeDistance(Geo.distanceMeters(_origin, p.point))} away'),
            ],
          ),
        ),
      );
      return;
    }
    await showCollectorSheet(context, CommunitySeed.collector(p.id), origin: _origin);
  }

  Future<void> _nearest() async {
    final s = context.services;
    final list = s.store.nearestFree(_origin);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nearest free collectors', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Only these ${list.length} are alerted, so others are not disturbed.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (list.isEmpty) const Text('Everyone is busy right now. Try again in a little while.'),
            for (final (c, d) in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.recycling),
                title: Text(c.name),
                subtitle: Text('${c.wasteType} · ${Geo.describeDistance(d)} · about ${Geo.etaMinutes(d)} min'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(showCollectorSheet(this.context, c, origin: _origin));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      appBar: aqAppBar(context, 'Eco-map', actions: [
        IconButton(
          tooltip: 'Use my location',
          onPressed: _locating ? null : _locate,
          icon: _locating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nearest,
        icon: const Icon(Icons.near_me_outlined),
        label: const Text('Nearest collectors'),
      ),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) => EcoMap(places: _places(s.store), me: _me, onSelect: _openPlace),
      ),
    );
  }
}

/// Collector details with call, SMS (Q9 fallback when offline) and pickup.
Future<void> showCollectorSheet(BuildContext context, Collector c, {required GeoPoint origin}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      final s = context.services;
      final busy = s.store.collectorBusy(c);
      final d = Geo.distanceMeters(origin, c.location);
      final text = Theme.of(sheet).textTheme;
      final phone = InputRules.normalizePhone(c.phone);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(c.name, style: text.titleLarge)),
                Pill(busy ? 'Busy' : 'Available', tone: busy ? Tone.danger : Tone.success),
              ],
            ),
            const SizedBox(height: 4),
            Text('${c.wasteType} specialist · ${c.area}'),
            Text('${Geo.describeDistance(d)} away · about ${Geo.etaMinutes(d)} min'),
            const SizedBox(height: 16),
            BusyButton(
              label: busy ? 'Busy right now' : 'Request a pickup',
              icon: Icons.local_shipping_outlined,
              onPressed: busy
                  ? null
                  : () async {
                      final u = s.auth.user;
                      if (u == null) return;
                      try {
                        final p = await s.store.requestPickup(student: u, collector: c, from: origin);
                        if (!sheet.mounted) return;
                        Navigator.of(sheet).pop();
                        if (context.mounted) await context.push('/pickup/${p.id}');
                      } on ActionRefused catch (e) {
                        if (sheet.mounted) Navigator.of(sheet).pop();
                        if (context.mounted) context.toast(e.message, error: true);
                      }
                    },
            ),
            const SizedBox(height: 8),
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
                    onPressed: phone == null
                        ? null
                        : () => launchUrl(Uri(
                              scheme: 'sms',
                              path: phone,
                              queryParameters: {'body': 'AquaAware pickup request: ${c.wasteType} waste, please.'},
                            )),
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('SMS'),
                  ),
                ),
              ],
            ),
            if (s.device.isOffline)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: InfoNote('You are offline. SMS still works without internet.', tone: Tone.warning, icon: Icons.cloud_off_outlined),
              ),
          ],
        ),
      );
    },
  );
}

// ==================================================================== REWARDS

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final u = s.auth.user;
        if (u == null) return const SizedBox.shrink();
        final balance = s.store.balanceOf(u.id);
        final reserved = s.store.reservedPoints(u.id);
        final available = balance - reserved;
        final myClaims = s.store.claimsOf(u.id);
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: aqAppBar(context, 'Rewards'),
          body: PageFrame(
            children: [
              StatStrip(items: [
                StatItem('Available', Fmt.number(available), icon: Icons.water_drop_outlined),
                StatItem('Reserved', Fmt.number(reserved), icon: Icons.hourglass_top),
                StatItem('Total earned', Fmt.number(balance), icon: Icons.savings_outlined),
              ]),
              const SizedBox(height: 10),
              Text(
                'Claim a reward to get a QR ticket. Show it at the NGO desk (${CommunitySeed.rewardDeskLabel}); '
                'points are taken only when the desk scans it.',
                style: text.bodySmall,
              ),
              const SectionHeader('Choose a reward'),
              for (final r in ContentSeed.rewards) ...[
                _RewardTile(reward: r, available: available, user: u),
                const SizedBox(height: 10),
              ],
              if (myClaims.isNotEmpty) ...[
                const SectionHeader('My claims'),
                Card(
                  child: Column(
                    children: [
                      for (final c in myClaims.take(8))
                        ListTile(
                          leading: Icon(_claimIcon(c)),
                          title: Text(c.rewardName),
                          subtitle: Text(_claimLine(c)),
                          trailing: c.isOpen ? const Icon(Icons.qr_code_2) : null,
                          onTap: () => context.push('/claim/${c.id}'),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static IconData _claimIcon(RewardClaim c) => switch (c.status) {
        ClaimStatus.redeemed => Icons.verified_outlined,
        ClaimStatus.cancelled => Icons.cancel_outlined,
        ClaimStatus.pending => c.isExpired() ? Icons.timer_off_outlined : Icons.qr_code_2,
      };

  static String _claimLine(RewardClaim c) => switch (c.status) {
        ClaimStatus.redeemed => 'Collected ${Fmt.date(c.redeemedAt ?? c.createdAt)}',
        ClaimStatus.cancelled => 'Cancelled',
        ClaimStatus.pending => c.isExpired() ? 'Expired' : 'Ready to show · expires ${Fmt.shortDate(c.expiresAt)}',
      };
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.reward, required this.available, required this.user});
  final Reward reward;
  final int available;
  final SessionUser user;

  static IconData icon(String id) => switch (id) {
        'R1' => Icons.shopping_bag_outlined,
        'R2' => Icons.grass,
        'R3' => Icons.local_florist_outlined,
        'R4' => Icons.local_drink_outlined,
        'R5' => Icons.workspace_premium_outlined,
        _ => Icons.park_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final can = available >= reward.points;
    final frac = (available / reward.points).clamp(0.0, 1.0);
    // The button sits under the text, not beside it, so names, the progress
    // bar and the points never get squeezed on narrow phones or large text.
    final Widget action = can
        ? BusyButton(
            // BusyButton ignores repeat taps, so a double tap can't
            // create two claims and reserve the points twice.
            label: 'Claim',
            busyLabel: 'Signing…',
            expand: false,
            onPressed: () async {
              try {
                final c = await context.services.store.createClaim(student: user, reward: reward);
                if (context.mounted) await context.push('/claim/${c.id}');
              } on ActionRefused catch (e) {
                if (context.mounted) context.toast(e.message, error: true);
              }
            },
          )
        : Tooltip(
            message: '${reward.points - available} more points needed',
            child: const OutlinedButton(onPressed: null, child: Text('Claim')),
          );
    return Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(AqRadius.control)),
            child: Icon(icon(reward.id), color: scheme.onSecondaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.name, style: text.titleMedium),
                Text(reward.blurb, style: text.bodySmall),
                const SizedBox(height: 8),
                Semantics(
                  label: can ? 'You can claim this' : '${reward.points - available} more points needed',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: scheme.surfaceContainerHighest),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${reward.points} pts',
                            style: text.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================== PROFILE

class _Badge {
  const _Badge(this.icon, this.name, this.earned, this.how);
  final IconData icon;
  final String name;
  final bool earned;
  final String how;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  List<_Badge> _badges(AppStore store, SessionUser u) {
    final p = store.progressOf(u.id);
    final history = store.historyOf(u.id);
    final perfect = p.quizBest.entries.any((e) => e.value == ContentSeed.quizFor(e.key).length);
    return [
      _Badge(Icons.menu_book, 'First lesson', p.modulesDone.isNotEmpty, 'Finish any module'),
      _Badge(Icons.water, 'Water scholar', p.modulesDone.length >= ContentSeed.modules.length, 'Finish all six modules'),
      _Badge(Icons.star_rounded, 'Full marks', perfect, 'Score 100% on a quiz'),
      _Badge(Icons.recycling, 'Sorting pro', store.hasEarned(u.id, 'sort_game'), 'Complete the sorting challenge'),
      _Badge(Icons.local_shipping_outlined, 'Waste hero', history.any((e) => e.refKey.startsWith('pickup:')), 'Hand waste to a collector'),
      _Badge(Icons.event_available, 'Volunteer', history.any((e) => e.refKey.startsWith('checkin:')), 'Check in to an NGO event'),
      _Badge(Icons.local_fire_department_outlined, 'Steady stream', store.streakOf(u.id) >= 3, 'Learn 3 days in a row'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final u = s.auth.user;
        if (u == null) return const SizedBox.shrink();
        final store = s.store;
        final profile = store.studentById(u.id);
        final summary = profile == null ? null : store.summaryOf(profile);
        final points = store.balanceOf(u.id);
        final history = store.historyOf(u.id);
        final badges = _badges(store, u);
        final text = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: aqAppBar(context, 'Me'),
          body: PageFrame(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase(), style: text.headlineSmall?.copyWith(color: scheme.onPrimary)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.name, style: text.headlineSmall),
                        Text('${EcoLevels.of(points).name} · ${u.school ?? u.classCode ?? ''}', style: text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StatStrip(items: [
                StatItem('Modules', '${summary?.modulesDone ?? 0}/6', icon: Icons.menu_book_outlined),
                StatItem('Quiz average', '${summary?.avgScorePct ?? 0}%', icon: Icons.quiz_outlined),
                StatItem('Points', Fmt.number(points), icon: Icons.water_drop_outlined),
                StatItem('Streak', Fmt.plural(store.streakOf(u.id), 'day'), icon: Icons.local_fire_department_outlined),
              ]),
              SectionHeader('Badges',
                  subtitle: 'Badges and points stay with you if you move to another ${store.kindOf(u.classCode).groupNoun}'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final b in badges)
                    Tooltip(
                      message: b.earned ? '${b.name} — earned' : '${b.name} — ${b.how}',
                      child: Semantics(
                        label: '${b.name}, ${b.earned ? 'earned' : 'not yet earned. ${b.how}'}',
                        child: ExcludeSemantics(
                          child: Container(
                            width: 104,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: b.earned ? scheme.secondaryContainer : scheme.surface,
                              borderRadius: BorderRadius.circular(AqRadius.card),
                              border: Border.all(color: b.earned ? AqColors.ochre : scheme.outlineVariant),
                            ),
                            child: Column(
                              children: [
                                Icon(b.icon, color: b.earned ? scheme.onSecondaryContainer : scheme.outline),
                                const SizedBox(height: 6),
                                Text(b.name, textAlign: TextAlign.center, style: text.labelMedium),
                                if (!b.earned) Text('Locked', style: text.labelSmall),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SectionHeader('Points history', subtitle: 'Every entry is sealed in a tamper-evident ledger'),
              if (history.isEmpty)
                const EmptyState(icon: Icons.water_drop_outlined, title: 'No points yet', message: 'Finish a lesson or a task to start filling your reservoir.')
              else
                Card(
                  child: Column(
                    children: [
                      for (final e in history.take(20))
                        ListTile(
                          dense: true,
                          title: Text(e.reason),
                          subtitle: Text(Fmt.relative(e.at)),
                          trailing: Text(
                            e.delta > 0 ? '+${e.delta}' : '${e.delta}',
                            style: text.titleSmall?.copyWith(color: e.delta > 0 ? scheme.tertiary : scheme.error),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.tune),
                label: const Text('Settings and accessibility'),
              ),
            ],
          ),
        );
      },
    );
  }
}
