import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/app_store.dart';
import '../../data/models/models.dart';
import '../../data/points_rules.dart';
import '../../data/seed/community_seed.dart';
import '../../services/app_services.dart';
import '../../widgets/common.dart';
import '../../widgets/composer.dart';
import '../../widgets/eco_map.dart';
import '../../widgets/motion.dart';
import '../../widgets/reservoir.dart';
import '../shared/place_sheet.dart';

/// The NGO this desk belongs to. Desks are always created with an NGO id;
/// the fallback only protects against a corrupted session.
Ngo _ngoOf(SessionUser u) => CommunitySeed.ngo(u.ngoId ?? '');

/// Audiences an NGO can reach: every partner school, or one school.
List<(String, String)> _audiences(AppStore store, {String? first}) {
  final all = <(String, String)>[
    ('ALL', 'All partner schools (${store.students.length} students)'),
    for (final c in store.classes) (c.code, '${c.school} (${c.code})'),
  ];
  if (first == null) return all;
  return [...all.where((a) => a.$1 == first), ...all.where((a) => a.$1 != first)];
}

Future<void> _broadcast(BuildContext context, SessionUser u, {String? audience}) async {
  final s = context.services;
  final r = await showComposer(
    context,
    title: 'Broadcast a task',
    hint: 'For example: Join the beach clean-up at Rock Beach on Saturday, 7 am.',
    submitLabel: 'Send broadcast',
    allowUrgent: true,
    audiences: _audiences(s.store, first: audience),
    note: 'Students who mark it done earn +10 points. You will see how many finish.',
  );
  if (r == null || !context.mounted) return;
  try {
    final a = await s.store.postAnnouncement(sender: u, message: r.text, audience: r.audience ?? 'ALL', urgent: r.urgent);
    if (context.mounted) {
      context.toast(a.audience == 'ALL'
          ? 'Broadcast sent to ${Fmt.plural(a.audienceSize, 'student')}'
          : 'Sent to ${a.audience} (${Fmt.plural(a.audienceSize, 'student')})');
    }
  } on ActionRefused catch (e) {
    if (context.mounted) context.toast(e.message, error: true);
  }
}

// ================================================================= BROADCASTS

class NgoBroadcastsScreen extends StatelessWidget {
  const NgoBroadcastsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final u = s.auth.user;
        if (u == null || u.ngoId == null) return const SizedBox.shrink();
        final store = s.store;
        final ngo = _ngoOf(u);
        final mine = store.sentBy(u.id)..sort((a, b) => b.sentAt.compareTo(a.sentAt));
        final reach = mine.fold<int>(0, (sum, a) => sum + a.audienceSize);
        final completed = mine.fold<int>(0, (sum, a) => sum + a.completedBy.length);
        final rate = reach == 0 ? 0 : (completed / reach * 100).round();
        final fromSchools = store.announcements.where((a) => a.senderRole == Role.educator).toList()
          ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
        final text = Theme.of(context).textTheme;

        return Scaffold(
          appBar: aqAppBar(context, 'Broadcasts'),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _broadcast(context, u),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Broadcast'),
          ),
          body: PageFrame(
            children: [
              RiseIn(child: _NgoHero(ngo: ngo)),
              const SizedBox(height: 14),
              StatStrip(items: [
                StatItem('Broadcasts', '${mine.length}', icon: Icons.campaign_outlined),
                StatItem('Students reached', '${store.studentsReachedBy(u.id)}', icon: Icons.groups_outlined),
                StatItem('Tasks done', '$completed', icon: Icons.task_alt),
                StatItem('Completion', '$rate%', icon: Icons.insights_outlined),
              ]),
              SectionHeader(
                'Your broadcasts',
                subtitle: mine.isEmpty ? null : 'Newest first · students earn +10 points for each task they finish',
              ),
              if (mine.isEmpty)
                EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No broadcasts yet',
                  message: 'Send a task to every partner school, or to one school. You will see how many students finish it.',
                  action: FilledButton.icon(
                    onPressed: () => _broadcast(context, u),
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('Send your first broadcast'),
                  ),
                )
              else
                for (final a in mine.take(8)) ...[
                  _BroadcastCard(announcement: a, store: store),
                  const SizedBox(height: 10),
                ],
              const SectionHeader('Partner schools', subtitle: 'Send a task to one school'),
              Card(
                child: Column(
                  children: [
                    for (final c in store.classes)
                      ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
                        title: Text(c.school),
                        subtitle: Text(
                          '${c.code} · ${Fmt.plural(store.studentsIn(c.code).length, 'student')}'
                          '${store.accountById(c.educatorId) == null ? '' : ' · ${store.accountById(c.educatorId)!.name}'}',
                        ),
                        trailing: TextButton(
                          onPressed: () => _broadcast(context, u, audience: c.code),
                          child: Text('Message', semanticsLabel: 'Message ${c.school}'),
                        ),
                      ),
                  ],
                ),
              ),
              SectionHeader('From schools', subtitle: fromSchools.isEmpty ? null : 'What educators asked their classes to do'),
              if (fromSchools.isEmpty)
                Text('Educators’ announcements to their classes will appear here.', style: text.bodyMedium)
              else
                Card(
                  child: Column(
                    children: [
                      for (final a in fromSchools.take(5))
                        ListTile(
                          leading: const Icon(Icons.co_present_outlined),
                          title: Text(a.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${a.senderName} · ${a.audience} · ${Fmt.relative(a.sentAt)}'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 72), // room for the floating button
            ],
          ),
        );
      },
    );
  }
}

/// The NGO's identity card: mangrove green with the sea along its edge.
class _NgoHero extends StatelessWidget {
  const _NgoHero({required this.ngo});
  final Ngo ngo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final soft = Colors.white.withValues(alpha: 0.92); // 4.5:1+ on mangrove green
    return Semantics(
      container: true,
      label: '${ngo.name}, ${ngo.area}. Focus: ${ngo.focus}.',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AqRadius.hero),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF173F2E), AqColors.mangrove],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.volunteer_activism, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('NGO desk', style: text.labelLarge?.copyWith(color: soft)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(ngo.name, style: text.headlineSmall?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('${ngo.area} · ${ngo.focus}', style: text.bodyMedium?.copyWith(color: soft)),
                    ],
                  ),
                ),
                WaveHorizon(
                  color: Colors.white.withValues(alpha: 0.16),
                  backColor: Colors.white.withValues(alpha: 0.07),
                  height: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.announcement, required this.store});
  final Announcement announcement;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final total = math.max(1, a.audienceSize);
    final done = a.completedBy.length;
    // Pills don't wrap, so they carry the short class code; the full school
    // name goes to screen readers and the line below the message.
    final school = a.audience == 'ALL' ? null : store.classByCode(a.audience)?.school;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: a.audience == 'ALL' ? 'Sent to all schools' : 'Sent to ${school ?? a.audience}',
                child: ExcludeSemantics(
                  child: Pill(a.audience == 'ALL' ? 'All schools' : a.audience, tone: Tone.success, icon: Icons.groups_outlined),
                ),
              ),
              if (a.urgent) ...[const SizedBox(width: 6), const Pill('Urgent', tone: Tone.danger, icon: Icons.priority_high)],
              const Spacer(),
              Text(Fmt.relative(a.sentAt), style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(a.message, style: text.bodyLarge),
          if (school != null) ...[
            const SizedBox(height: 4),
            ExcludeSemantics(child: Text(school, style: text.bodySmall)),
          ],
          const SizedBox(height: 10),
          Semantics(
            label: '$done of ${a.audienceSize} students completed this task',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (done / total).clamp(0.0, 1.0)),
                        duration: context.motion(AqMotion.slow),
                        curve: AqMotion.emphasized,
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          color: scheme.tertiary,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$done/${a.audienceSize} done', style: text.labelMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================= ACTIVITIES

class NgoActivitiesScreen extends StatelessWidget {
  const NgoActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final u = s.auth.user;
        final ngoId = u?.ngoId;
        if (u == null || ngoId == null) return const SizedBox.shrink();
        final all = s.store.activitiesFor(ngoId);
        final upcoming = all.where((a) => !a.isPast()).toList();
        final past = all.where((a) => a.isPast()).toList().reversed.toList();
        return Scaffold(
          appBar: aqAppBar(context, 'Activities'),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _scheduleActivity(context, u),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Schedule'),
          ),
          body: PageFrame(
            children: [
              const InfoNote(
                'At the event, open its check-in code. Students scan it in AquaAware for '
                '+${PointRules.activityCheckIn} points. The code changes every 15 minutes, so a photo shared '
                'later stops working, and each student can check in only once.',
                icon: Icons.qr_code_2,
              ),
              SectionHeader('Upcoming', subtitle: upcoming.isEmpty ? 'Nothing scheduled' : Fmt.plural(upcoming.length, 'event')),
              if (upcoming.isEmpty)
                EmptyState(
                  icon: Icons.event_outlined,
                  title: 'No upcoming events',
                  message: 'Schedule a clean-up, talk or drive so students can check in.',
                  action: FilledButton.icon(
                    onPressed: () => _scheduleActivity(context, u),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Schedule an event'),
                  ),
                )
              else
                for (final a in upcoming) ...[
                  _ActivityCard(activity: a, desk: u, ngoId: ngoId),
                  const SizedBox(height: 10),
                ],
              if (past.isNotEmpty) ...[
                const SectionHeader('Past events'),
                for (final a in past) ...[
                  _ActivityCard(activity: a, desk: u, ngoId: ngoId),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 72),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.desk, required this.ngoId});
  final NgoActivity activity;
  final SessionUser desk;
  final String ngoId;

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final s = context.services;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final checkIns = s.store.checkInsFor(ngoId, a.id);
    final past = a.isPast();
    final now = DateTime.now();
    final isToday = a.date.year == now.year && a.date.month == now.month && a.date.day == now.day;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar tile.
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: past ? scheme.surfaceContainerHigh : scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(AqRadius.control),
                  ),
                  child: Column(
                    children: [
                      Text(_months[a.date.month - 1],
                          style: text.labelSmall?.copyWith(
                              color: past ? scheme.onSurfaceVariant : scheme.onTertiaryContainer, fontWeight: FontWeight.w800)),
                      Text('${a.date.day}',
                          style: text.headlineSmall?.copyWith(color: past ? scheme.onSurface : scheme.onTertiaryContainer)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.weekday(a.date)} ${Fmt.date(a.date)}${a.place == null ? '' : ' · ${a.place}'}',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isToday) const Pill('Today', tone: Tone.success, icon: Icons.today),
                        if (a.participants > 0) Pill('${a.participants} registered', icon: Icons.how_to_reg_outlined),
                        Pill('$checkIns checked in', tone: checkIns > 0 ? Tone.info : Tone.neutral, icon: Icons.qr_code_scanner),
                        if (a.ngoId != null) const Pill('Added in app', icon: Icons.edit_calendar_outlined),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!past) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => showCheckinCode(context, desk: desk, activity: a, ngoId: ngoId),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Show check-in code'),
                  ),
                ),
                if (a.ngoId != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cancel ${a.name}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await confirmAction(
                        context,
                        title: 'Cancel this event?',
                        message: '"${a.name}" will be removed. Students who already checked in keep their points.',
                        confirmLabel: 'Cancel event',
                        destructive: true,
                      );
                      if (!ok || !context.mounted) return;
                      await s.store.removeActivity(a.id, desk: desk);
                      if (context.mounted) context.toast('Event cancelled');
                    },
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _scheduleActivity(BuildContext context, SessionUser desk) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ScheduleSheet(desk: desk),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.desk});
  final SessionUser desk;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _place = TextEditingController();
  late DateTime _date = DateTime.now().add(const Duration(days: 7));
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Event date',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = context.services;
    try {
      await s.store.addActivity(desk: widget.desk, name: _name.text, date: _date, place: _place.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.toast('Scheduled "${_name.text.trim()}" for ${Fmt.date(_date)}');
    } on ActionRefused catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text('Schedule an event', style: text.titleLarge)),
              const SizedBox(height: 6),
              Text('Students will be able to check in on the day with a rotating QR code.', style: text.bodySmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Event name', hintText: 'Beach clean-up', prefixIcon: Icon(Icons.event_outlined)),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a name of at least 3 letters.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _place,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Place (optional)', hintText: 'Rock Beach, near the Gandhi statue', prefixIcon: Icon(Icons.place_outlined)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Date: ${Fmt.weekday(_date)} ${Fmt.date(_date)}'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: InfoNote(_error!, tone: Tone.danger)),
              ],
              const SizedBox(height: 16),
              BusyButton(label: 'Schedule event', icon: Icons.event_available_outlined, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-height sheet with a rotating, signed check-in QR (Q9 anti-replay).
Future<void> showCheckinCode(
  BuildContext context, {
  required SessionUser desk,
  required NgoActivity activity,
  required String ngoId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: _CheckinCodeSheet(desk: desk, activity: activity, ngoId: ngoId),
    ),
  );
}

class _CheckinCodeSheet extends StatefulWidget {
  const _CheckinCodeSheet({required this.desk, required this.activity, required this.ngoId});
  final SessionUser desk;
  final NgoActivity activity;
  final String ngoId;

  @override
  State<_CheckinCodeSheet> createState() => _CheckinCodeSheetState();
}

class _CheckinCodeSheetState extends State<_CheckinCodeSheet> {
  /// Tokens live 15 minutes; a fresh one is shown with a minute to spare so
  /// a student scanning at the last second still gets a valid code.
  static const _life = Duration(minutes: 15);
  static const _refreshBefore = Duration(minutes: 1);

  String? _code;
  DateTime? _issuedAt;
  Timer? _tick;
  bool _issuing = false;
  int _burst = 0;
  int _lastCount = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_issue());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= Duration.zero && !_issuing) unawaited(_issue());
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final at = _issuedAt;
    if (at == null) return Duration.zero;
    return at.add(_life - _refreshBefore).difference(DateTime.now());
  }

  Future<void> _issue() async {
    setState(() => _issuing = true);
    final code = await context.services.store.issueCheckinCode(desk: widget.desk, activity: widget.activity);
    if (!mounted) return;
    setState(() {
      _code = code;
      _issuedAt = DateTime.now();
      _issuing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final code = _code;
    final left = _remaining;
    final total = (_life - _refreshBefore).inSeconds;
    final mm = left.inMinutes.clamp(0, 99).toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');

    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final count = s.store.checkInsFor(widget.ngoId, widget.activity.id);
        if (_lastCount >= 0 && count > _lastCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _burst++);
          });
        }
        _lastCount = count;
        return DropletBurst(
          trigger: _burst,
          child: LayoutBuilder(builder: (context, c) {
            final qrSize = math.min(320.0, math.min(c.maxWidth - 64, c.maxHeight * 0.5));
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Semantics(header: true, child: Text(widget.activity.name, style: text.headlineSmall, textAlign: TextAlign.center)),
                const SizedBox(height: 4),
                Text('Students: open AquaAware → Home → Scan event code',
                    style: text.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AqRadius.hero),
                      border: Border.all(color: AqColors.line),
                    ),
                    child: SizedBox.square(
                      dimension: qrSize,
                      child: code == null
                          ? const Center(child: CircularProgressIndicator())
                          : AnimatedSwitcher(
                              duration: context.motion(AqMotion.medium),
                              child: QrImageView(
                                key: ValueKey(code),
                                data: code,
                                size: qrSize,
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.white,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                                semanticsLabel: 'Check-in QR code for ${widget.activity.name}',
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AqColors.ink),
                                dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square, color: AqColors.ink),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : (left.inSeconds / total).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _issuing ? 'Making a new code…' : 'New code in $mm:$ss',
                  style: text.labelLarge,
                  textAlign: TextAlign.center,
                  semanticsLabel: _issuing ? 'Making a new code' : 'New code in ${left.inMinutes} minutes',
                ),
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  label: '${Fmt.plural(count, 'student')} checked in',
                  child: ExcludeSemantics(
                    child: Panel(
                      color: scheme.tertiaryContainer,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.how_to_reg, color: scheme.onTertiaryContainer),
                          const SizedBox(width: 10),
                          AnimatedCount(value: count, style: text.headlineMedium?.copyWith(color: scheme.onTertiaryContainer)),
                          const SizedBox(width: 8),
                          Text(count == 1 ? 'student checked in' : 'students checked in',
                              style: text.titleMedium?.copyWith(color: scheme.onTertiaryContainer)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: code == null
                            ? null
                            : () async {
                                await Clipboard.setData(ClipboardData(text: code));
                                if (context.mounted) context.toast('Code copied. It works for 15 minutes.');
                              },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy code'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _issuing ? null : () => unawaited(_issue()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('New code now'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Each code is signed (HMAC-SHA256), names this event, and expires after 15 minutes. '
                  'A student can earn check-in points for an event only once.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }),
        );
      },
    );
  }
}

// ================================================================ REWARD DESK

class NgoVerifyScreen extends StatelessWidget {
  const NgoVerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final u = s.auth.user;
        if (u == null) return const SizedBox.shrink();
        final done = s.store.redemptionsBy(u.name);
        final now = DateTime.now();
        final today = done.where((c) {
          final t = c.redeemedAt;
          return t != null && t.year == now.year && t.month == now.month && t.day == now.day;
        }).length;
        final pts = done.fold<int>(0, (sum, c) => sum + c.points);
        final text = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: aqAppBar(context, 'Reward desk'),
          body: PageFrame(
            children: [
              Panel(
                color: scheme.primaryContainer,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 40, color: scheme.onPrimaryContainer),
                    const SizedBox(height: 10),
                    Text('Scan a student’s reward ticket',
                        style: text.titleLarge?.copyWith(color: scheme.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text(
                      'Hand over the reward only when the scan says so. Points are taken from the student at that moment.',
                      style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/scan'),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan ticket'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              StatStrip(items: [
                StatItem('Today', '$today', icon: Icons.today_outlined),
                StatItem('All time', '${done.length}', icon: Icons.redeem_outlined),
                StatItem('Points redeemed', Fmt.number(pts), icon: Icons.water_drop_outlined),
              ]),
              const SectionHeader('What every scan checks'),
              const Card(
                child: Column(
                  children: [
                    _CheckRow(Icons.verified_user_outlined, 'Signature',
                        'The ticket was issued by AquaAware and not edited (HMAC-SHA256, checked in constant time).'),
                    _CheckRow(Icons.timer_outlined, 'Expiry', 'Tickets last 7 days. Expired tickets are refused.'),
                    _CheckRow(Icons.block, 'Single use',
                        'Each ticket works once. A copied or replayed ticket is refused and logged for the manager.'),
                    _CheckRow(Icons.account_balance_wallet_outlined, 'Balance',
                        'The student must still have enough points; the ledger records the deduction.'),
                    _CheckRow(Icons.where_to_vote_outlined, 'Location (advisory)',
                        'Shows whether the student’s phone confirmed it was within 100 m of the desk. Simulated GPS is rejected.'),
                  ],
                ),
              ),
              const SectionHeader('Recently handed over'),
              if (done.isEmpty)
                const EmptyState(
                  icon: Icons.redeem_outlined,
                  title: 'Nothing handed over yet',
                  message: 'Redeemed tickets appear here with the time and the reward.',
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final c in done.take(12))
                        ListTile(
                          leading: Icon(Icons.verified, color: scheme.tertiary),
                          title: Text('${c.rewardName} → ${c.studentName}'),
                          subtitle: Text(
                            '${Fmt.relative(c.redeemedAt ?? c.createdAt)} · ${c.points} points'
                            '${c.locationVerified ? ' · location confirmed' : ''}',
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.icon, this.title, this.detail);
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(detail));
}

// ======================================================================== MAP

class NgoMapScreen extends StatelessWidget {
  const NgoMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final u = s.auth.user;
    return Scaffold(
      appBar: aqAppBar(context, 'Map'),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) => EcoMap(
          places: communityPlaces(s.store, ownNgoId: u?.ngoId),
          onSelect: (p) => unawaited(showPlaceSheet(context, p)),
        ),
      ),
    );
  }
}
