// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/net/sync_service.dart';
import '../../core/security/input_rules.dart';
import '../../core/utils/format.dart';
import '../../data/app_store.dart';
import '../../data/models/models.dart';
import '../../data/seed/community_seed.dart';
import '../../data/seed/content_seed.dart';
import '../../services/app_services.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/eco_map.dart';
import '../../widgets/motion.dart';
import '../../widgets/reservoir.dart';
import '../shared/place_sheet.dart';

String _initials(String name) => name
    .split(' ')
    .where((p) => p.isNotEmpty && !p.endsWith('.'))
    .take(2)
    .map((p) => p[0].toUpperCase())
    .join();

class _Alert {
  const _Alert(this.tone, this.icon, this.text, {this.action, this.onAction});
  final Tone tone;
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
}

// =================================================================== OVERVIEW

class ManagerOverviewScreen extends StatelessWidget {
  const ManagerOverviewScreen({super.key});

  List<_Alert> _alerts(BuildContext context, AppServices s, List<StudentSummary> all) {
    final store = s.store;
    final out = <_Alert>[];
    if (!store.ledgerIntact) {
      out.add(_Alert(Tone.danger, Icons.gpp_bad_outlined,
          'The points ledger failed its integrity check at entry ${store.ledgerBrokenAt + 1}. Awards and claims are paused.',
          action: 'Review', onAction: () => context.push('/security')));
    }
    if (s.vault.tamperEvents > 0) {
      out.add(_Alert(Tone.danger, Icons.report_outlined,
          '${Fmt.plural(s.vault.tamperEvents, 'stored record')} failed decryption and were ignored. Someone may have edited app storage.',
          action: 'Review', onAction: () => context.push('/security')));
    }
    if (!s.vault.isSecure) {
      out.add(const _Alert(Tone.warning, Icons.key_off_outlined,
          'The platform keystore is unavailable, so data is kept in memory only and will be lost when the app closes.'));
    }
    if (store.activeLockouts > 0) {
      out.add(_Alert(Tone.warning, Icons.lock_clock_outlined,
          '${Fmt.plural(store.activeLockouts, 'sign-in')} locked after repeated wrong passwords or PINs.',
          action: 'Details', onAction: () => context.push('/security')));
    }
    final rejected = s.sync.items.where((i) => i.status == OutboxStatus.rejected).length;
    if (rejected > 0) {
      out.add(_Alert(Tone.warning, Icons.sync_problem_outlined, '${Fmt.plural(rejected, 'update')} were refused by the server.'));
    }
    final atRisk = all.where((e) => e.profile.isClaimed && e.atRisk).length;
    if (atRisk > 0) {
      out.add(_Alert(Tone.info, Icons.trending_down, '${Fmt.plural(atRisk, 'student')} may need support (few modules or low quiz scores).',
          action: 'Directory', onAction: () => context.go('/manager/directory')));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([s.store, s.sync]),
      builder: (context, _) {
        final u = s.auth.user;
        if (u == null) return const SizedBox.shrink();
        final store = s.store;
        final summaries = store.students.map(store.summaryOf).toList();
        final moduleSlots = store.students.length * ContentSeed.modules.length;
        final modulesDone = summaries.fold<int>(0, (sum, e) => sum + e.modulesDone);
        final share = moduleSlots == 0 ? 0.0 : modulesDone / moduleSlots;
        final totals = store.pointTotals();
        final week = store.weeklyEngagement(null);
        final today = DateTime.now();
        final weekData = [
          for (var i = 0; i < 7; i++)
            ChartDatum(Fmt.weekday(today.subtract(Duration(days: 6 - i))).substring(0, 2), week[i].toDouble(),
                longLabel: Fmt.date(today.subtract(Duration(days: 6 - i)))),
        ];
        final alerts = _alerts(context, s, summaries);
        final log = store.activity.take(8).toList();
        final text = Theme.of(context).textTheme;

        return Scaffold(
          appBar: aqAppBar(context, 'Overview', actions: [
            IconButton(
              tooltip: 'Privacy and security',
              icon: const Icon(Icons.shield_outlined),
              onPressed: () => context.push('/security'),
            ),
          ]),
          body: PageFrame(
            children: [
              RiseIn(
                child: Reservoir(
                  level: share,
                  height: 200,
                  marks: const [0.25, 0.5, 0.75],
                  semanticLabel: 'Programme progress: ${(share * 100).round()} percent of all modules completed. '
                      '${store.joinedStudents} of ${store.students.length} members have joined.',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pondicherry pilot', style: text.labelLarge?.copyWith(color: Colors.white.withValues(alpha: 0.92))),
                        const Spacer(),
                        AnimatedCount(value: (share * 100).round(), suffix: '%', style: text.displaySmall?.copyWith(color: Colors.white)),
                        Text('of all modules completed', style: text.titleMedium?.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          '${store.joinedStudents} of ${store.students.length} members joined · ${Fmt.plural(store.classes.length, 'group')}',
                          style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              StatStrip(items: [
                StatItem('Members', '${store.students.length}', icon: Icons.groups_outlined),
                StatItem('Leaders', '${store.educatorAccounts.length}', icon: Icons.co_present_outlined),
                StatItem('NGO partners', '${CommunitySeed.ngos.length}', icon: Icons.volunteer_activism_outlined),
                StatItem('Open claims', '${store.openClaims}', icon: Icons.confirmation_number_outlined),
              ]),
              SectionHeader('Needs attention', subtitle: alerts.isEmpty ? null : Fmt.plural(alerts.length, 'item')),
              if (alerts.isEmpty)
                const InfoNote('All checks passed: the ledger is intact, storage is encrypted and nobody is locked out.',
                    tone: Tone.success, icon: Icons.verified_outlined)
              else
                for (final a in alerts) ...[
                  InfoNote(
                    a.text,
                    tone: a.tone,
                    icon: a.icon,
                    action: a.action == null ? null : TextButton(onPressed: a.onAction, child: Text(a.action!)),
                  ),
                  const SizedBox(height: 8),
                ],
              const SectionHeader('Groups',
                  subtitle: 'Schools, colleges, offices and communities. Data is kept separate by group: each leader sees only their own'),
              Card(
                child: Column(
                  children: [
                    for (final c in store.classes) _SchoolRow(room: c, store: store),
                  ],
                ),
              ),
              const SectionHeader('Activity this week', subtitle: 'Actions that earned points, all groups'),
              Panel(
                child: AqChart(
                  data: weekData,
                  line: true,
                  summary: 'Line chart of activity across all groups over the last 7 days: '
                      '${weekData.map((d) => '${d.longLabel}: ${d.value!.round()}').join(', ')}.',
                ),
              ),
              const SectionHeader('Points economy', subtitle: 'From the tamper-evident ledger'),
              StatStrip(items: [
                StatItem('Earned', Fmt.number(totals.issued), icon: Icons.add_circle_outline),
                StatItem('Redeemed', Fmt.number(totals.redeemed), icon: Icons.redeem_outlined),
                StatItem('Held by members', Fmt.number(totals.issued - totals.redeemed), icon: Icons.savings_outlined),
              ]),
              SectionHeader('Audit log', subtitle: 'Sign-ins, lockouts, broadcasts and changes',
                  action: 'View all', onAction: () => showAuditLog(context)),
              if (log.isEmpty)
                Text('Nothing recorded yet.', style: text.bodyMedium)
              else
                Card(child: Column(children: [for (final e in log) _LogRow(entry: e)])),
            ],
          ),
        );
      },
    );
  }
}

class _SchoolRow extends StatelessWidget {
  const _SchoolRow({required this.room, required this.store});
  final ClassRoom room;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final roster = store.studentsIn(room.code).map(store.summaryOf).toList();
    final avg = roster.isEmpty ? 0 : (roster.map((e) => e.avgScorePct).reduce((a, b) => a + b) / roster.length).round();
    final risk = roster.where((e) => e.profile.isClaimed && e.atRisk).length;
    final edu = store.accountById(room.educatorId);
    return ListTile(
      leading: CircleAvatar(
        child: Icon(kindIcon(room.kind)),
      ),
      title: Text(room.school),
      subtitle: Text(
        '${room.kind.label} · ${room.code} · ${edu?.name ?? 'No ${room.kind.leaderNoun} yet'} · '
        '${Fmt.plural(roster.length, room.kind.memberNoun)} · $avg% quiz average',
      ),
      trailing: risk > 0 ? Pill('$risk at risk', tone: Tone.warning) : null,
      onTap: () => context.go('/manager/directory'),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});
  final ActivityLogEntry entry;

  static IconData _icon(String action) {
    final a = action.toLowerCase();
    if (a.contains('locked') || a.contains('blocked') || a.contains('rejected') || a.contains('fraud')) return Icons.gpp_maybe_outlined;
    if (a.contains('signed in')) return Icons.login;
    if (a.contains('broadcast') || a.contains('announcement')) return Icons.campaign_outlined;
    if (a.contains('handed') || a.contains('claim')) return Icons.redeem_outlined;
    if (a.contains('moved') || a.contains('pin')) return Icons.manage_accounts_outlined;
    if (a.contains('phone')) return Icons.visibility_outlined;
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final warn = _icon(entry.action) == Icons.gpp_maybe_outlined;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(_icon(entry.action), color: warn ? scheme.error : null),
      title: Text.rich(TextSpan(children: [
        TextSpan(text: entry.actor, style: text.titleSmall),
        TextSpan(text: ' ${entry.action}', style: text.bodyMedium),
      ])),
      subtitle: Text('${Fmt.relative(entry.at)} · ${Fmt.time(entry.at)}'),
    );
  }
}

Future<void> showAuditLog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _AuditLogSheet(),
  );
}

class _AuditLogSheet extends StatefulWidget {
  const _AuditLogSheet();

  @override
  State<_AuditLogSheet> createState() => _AuditLogSheetState();
}

class _AuditLogSheetState extends State<_AuditLogSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      builder: (context, controller) => ListenableBuilder(
        listenable: _query,
        builder: (context, _) {
          final q = _query.text.trim().toLowerCase();
          final rows = s.store.activity
              .where((e) => q.isEmpty || e.actor.toLowerCase().contains(q) || e.action.toLowerCase().contains(q))
              .toList();
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Semantics(header: true, child: Text('Audit log', style: Theme.of(context).textTheme.titleLarge)),
              const SizedBox(height: 4),
              Text('The latest 60 events on this device. Private messages are never logged.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filter by person or action'),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(Fmt.plural(rows.length, 'event'), style: Theme.of(context).textTheme.labelLarge),
              ),
              for (final e in rows) _LogRow(entry: e),
            ],
          );
        },
      ),
    );
  }
}

// ================================================================== DIRECTORY

enum _Dir {
  students('Members', Icons.groups_outlined),
  educators('Leaders', Icons.co_present_outlined),
  ngos('NGOs', Icons.volunteer_activism_outlined);

  const _Dir(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ManagerDirectoryScreen extends StatefulWidget {
  const ManagerDirectoryScreen({super.key});

  @override
  State<ManagerDirectoryScreen> createState() => _ManagerDirectoryScreenState();
}

class _ManagerDirectoryScreenState extends State<ManagerDirectoryScreen> {
  final _search = TextEditingController();
  _Dir _tab = _Dir.students;
  bool _riskOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      appBar: aqAppBar(context, 'Directory'),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.store, _search]),
        builder: (context, _) {
          final q = _search.text.trim().toLowerCase();
          bool hit(String v) => q.isEmpty || v.toLowerCase().contains(q);
          final store = s.store;
          final List<Widget> rows;
          switch (_tab) {
            case _Dir.students:
              final list = [
                for (final p in [...store.students]..sort((a, b) => a.name.compareTo(b.name)))
                  if (hit(p.name) || hit(p.classCode)) store.summaryOf(p),
              ].where((e) => !_riskOnly || (e.profile.isClaimed && e.atRisk)).toList();
              rows = [for (final e in list) _StudentTile(summary: e)];
            case _Dir.educators:
              rows = [
                for (final a in store.educatorAccounts)
                  if (hit(a.name) || hit(a.loginId) || hit(a.school ?? '') || hit(a.classCode ?? '')) _EducatorTile(account: a),
              ];
            case _Dir.ngos:
              rows = [
                for (final n in CommunitySeed.ngos)
                  if (hit(n.name) || hit(n.area) || hit(n.focus)) _NgoTile(ngo: n),
              ];
          }
          return PageFrame(
            children: [
              SegmentedButton<_Dir>(
                showSelectedIcon: false,
                segments: [
                  for (final d in _Dir.values) ButtonSegment(value: d, icon: Icon(d.icon), label: Text(d.label)),
                ],
                selected: {_tab},
                onSelectionChanged: (v) => setState(() => _tab = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search ${_tab.label.toLowerCase()}',
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: _search.clear),
                ),
              ),
              if (_tab == _Dir.students)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _riskOnly,
                  onChanged: (v) => setState(() => _riskOnly = v),
                  title: const Text('Only people who may need support'),
                ),
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Text(Fmt.plural(rows.length, 'result'), style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const EmptyState(icon: Icons.search_off, title: 'No matches', message: 'Try a shorter search or another tab.')
              else
                Card(child: Column(children: rows)),
            ],
          );
        },
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.summary});
  final StudentSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = summary.profile;
    return ListTile(
      leading: CircleAvatar(child: Text(_initials(p.name))),
      title: Text(p.name),
      subtitle: Text('${p.classCode} · ${summary.points} points · ${summary.avgScorePct}% average'),
      trailing: !p.isClaimed
          ? const Pill('Not joined')
          : summary.atRisk
              ? const Pill('At risk', tone: Tone.warning, icon: Icons.trending_down)
              : null,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ManagerStudentSheet(studentId: p.id),
      ),
    );
  }
}

/// Q3 — move a student between schools without losing points or badges,
/// because the ledger is keyed by student, not by school.
class _ManagerStudentSheet extends StatefulWidget {
  const _ManagerStudentSheet({required this.studentId});
  final String studentId;

  @override
  State<_ManagerStudentSheet> createState() => _ManagerStudentSheetState();
}

class _ManagerStudentSheetState extends State<_ManagerStudentSheet> {
  String? _target;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final p = s.store.studentById(widget.studentId);
        if (p == null) return const SizedBox(height: 120, child: Center(child: Text('This person was not found.')));
        final sum = s.store.summaryOf(p);
        final room = s.store.classByCode(p.classCode);
        final others = s.store.classes.where((c) => c.code != p.classCode).toList();
        // After a move the old choice may be the student's own class, which
        // is no longer listed — fall back to the first valid option.
        final chosen = _target;
        final target = chosen != null && others.any((c) => c.code == chosen)
            ? chosen
            : (others.isEmpty ? null : others.first.code);
        final history = s.store.historyOf(p.id).take(4).toList();
        final text = Theme.of(context).textTheme;
        final manager = s.auth.user?.name ?? 'Manager';
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(p.name, style: text.headlineSmall)),
              Text('${room?.school ?? p.classCode} · ${p.classCode}', style: text.bodyMedium),
              Text(p.isClaimed ? 'Joined ${Fmt.date(p.joinedAt)}' : 'Has not signed in yet', style: text.bodySmall),
              const SizedBox(height: 14),
              StatStrip(items: [
                StatItem('Modules', '${sum.modulesDone}/${ContentSeed.modules.length}'),
                StatItem('Average', '${sum.avgScorePct}%'),
                StatItem('Points', Fmt.number(sum.points)),
              ]),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Recent points', style: text.titleSmall),
                for (final e in history)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${e.delta > 0 ? '+' : ''}${e.delta}  ${e.reason} · ${Fmt.relative(e.at)}', style: text.bodySmall),
                  ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(_revealed ? (p.phone ?? 'Not available') : InputRules.maskPhone(p.phone ?? '')),
                subtitle: const Text('Guardian phone (masked for privacy)'),
                trailing: _revealed || p.phone == null
                    ? null
                    : TextButton(
                        onPressed: () async {
                          final ok = await confirmAction(context,
                              title: 'Show phone number?',
                              message: 'Viewing someone’s number is recorded in the audit log.',
                              confirmLabel: 'Show');
                          if (!ok || !mounted) return;
                          setState(() => _revealed = true);
                          s.store.logEvent(manager, 'viewed the phone number of ${p.name}');
                        },
                        child: const Text('Show'),
                      ),
              ),
              const Divider(height: 28),
              Semantics(header: true, child: Text('Move to another group', style: text.titleMedium)),
              const SizedBox(height: 4),
              Text('Points, badges and quiz history move with them.', style: text.bodySmall),
              const SizedBox(height: 10),
              if (others.isEmpty)
                Text('There is no other group to move to yet.', style: text.bodyMedium)
              else ...[
                DropdownButtonFormField<String>(
                  // initialValue is read once; rebuild the field when the
                  // student's class (and so the list of options) changes.
                  key: ValueKey('move-${p.classCode}'),
                  initialValue: target,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'New group', prefixIcon: Icon(Icons.swap_horiz)),
                  items: [
                    for (final c in others)
                      DropdownMenuItem(value: c.code, child: Text('${c.school} (${c.code})', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _target = v),
                ),
                const SizedBox(height: 10),
                BusyButton(
                  label: 'Move ${p.name}',
                  icon: Icons.swap_horiz,
                  tonal: true,
                  onPressed: target == null
                      ? null
                      : () async {
                          final dest = s.store.classByCode(target);
                          final ok = await confirmAction(context,
                              title: 'Move ${p.name}?',
                              message: 'From ${p.classCode} to ${dest?.school ?? target}. '
                                  'Their new ${dest?.kind.leaderNoun ?? 'leader'} will see them straight away.',
                              confirmLabel: 'Move');
                          if (!ok || !context.mounted) return;
                          try {
                            await s.store.transferStudent(p.id, target, by: manager);
                            if (context.mounted) context.toast('${p.name} moved to $target. Points and badges kept.');
                          } on ActionRefused catch (e) {
                            if (context.mounted) context.toast(e.message, error: true);
                          }
                        },
                ),
              ],
              if (p.isClaimed) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await confirmAction(context,
                        title: 'Reset ${p.name}’s PIN?',
                        message: 'They will choose a new PIN the next time they sign in.',
                        confirmLabel: 'Reset PIN');
                    if (!ok || !context.mounted) return;
                    await s.auth.resetStudentPin(p.id, by: manager);
                    if (context.mounted) context.toast('PIN reset for ${p.name}');
                  },
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reset PIN'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EducatorTile extends StatelessWidget {
  const _EducatorTile({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final code = account.classCode;
    final roster = code == null ? 0 : s.store.studentsIn(code).length;
    final sent = s.store.sentBy(account.id).length;
    final k = s.store.kindOf(code);
    return ListTile(
      leading: CircleAvatar(child: Text(_initials(account.name))),
      title: Text(account.name),
      subtitle: Text('${k.leaderTitle} · ${account.school ?? 'No group yet'} · ${code ?? '—'} · ${Fmt.plural(roster, k.memberNoun)}'),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (sheet) {
          final text = Theme.of(sheet).textTheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(account.name, style: text.headlineSmall)),
                Text(account.school ?? '', style: text.bodyMedium),
                const SizedBox(height: 12),
                StatStrip(items: [
                  StatItem(k.membersTitle, '$roster'),
                  StatItem('Announcements', '$sent'),
                  StatItem(k.codeLabel, code ?? '—'),
                ]),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline),
                  title: SelectableText(account.loginId),
                  trailing: IconButton(
                    tooltip: 'Copy email',
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: account.loginId));
                      if (sheet.mounted) sheet.toast('Email copied');
                    },
                  ),
                ),
                if (account.createdAt != null) Text('Registered ${Fmt.date(account.createdAt!)}', style: text.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NgoTile extends StatelessWidget {
  const _NgoTile({required this.ngo});
  final Ngo ngo;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final phone = InputRules.normalizePhone(ngo.phone);
    final broadcasts = s.store.sentBy('DESK-${ngo.id}').length;
    final handed = s.store.redemptionsBy(ngo.name).length;
    final events = s.store.activitiesFor(ngo.id).length;
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.volunteer_activism_outlined)),
      title: Text(ngo.name),
      subtitle: Text('${ngo.area} · ${Fmt.plural(events, 'event')} · ${Fmt.plural(broadcasts, 'broadcast')} · '
          '${Fmt.plural(handed, 'reward')} handed over'),
      trailing: phone == null
          ? null
          : IconButton(
              tooltip: 'Call ${ngo.shortName}',
              icon: const Icon(Icons.call_outlined),
              onPressed: () => unawaited(launchUrl(Uri(scheme: 'tel', path: phone))),
            ),
      onTap: () => unawaited(showPlaceSheet(
        context,
        MapPlace(id: ngo.id, name: ngo.name, subtitle: 'NGO partner · ${ngo.area}', point: ngo.location, kind: PlaceKind.ngo),
      )),
    );
  }
}

// ======================================================================== MAP

class ManagerMapScreen extends StatelessWidget {
  const ManagerMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      appBar: aqAppBar(context, 'Map'),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) => EcoMap(
          places: communityPlaces(s.store),
          onSelect: (p) => unawaited(showPlaceSheet(context, p)),
        ),
      ),
    );
  }
}
