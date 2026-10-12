import 'dart:async';

import 'package:file_picker/file_picker.dart' show FilePicker, FileType, PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/platform/device_context.dart';
import '../../core/platform/file_store.dart';
import '../../core/security/file_rules.dart';
import '../../core/security/input_rules.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/app_store.dart';
import '../../data/models/models.dart';
import '../../data/seed/community_seed.dart';
import '../../data/seed/content_seed.dart';
import '../../services/app_services.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/composer.dart';
import '../student/learn_screens.dart' show openResource, resourceIcon;

String _initials(String name) => name
    .split(' ')
    .where((p) => p.isNotEmpty && !p.endsWith('.'))
    .take(2)
    .map((p) => p[0].toUpperCase())
    .join();

Future<void> postClassAnnouncement(BuildContext context, SessionUser u) async {
  final r = await showComposer(
    context,
    title: 'Announcement to ${u.classCode}',
    hint: 'What should your class do?',
    submitLabel: 'Send to class',
    allowUrgent: true,
    note: 'Students can mark it done for +5 points. You will see who has finished.',
  );
  if (r == null || !context.mounted) return;
  try {
    await context.services.store.postAnnouncement(sender: u, message: r.text, audience: u.classCode!, urgent: r.urgent);
    if (context.mounted) context.toast('Announcement sent to ${u.classCode}');
  } on ActionRefused catch (e) {
    if (context.mounted) context.toast(e.message, error: true);
  }
}

// =================================================================== OVERVIEW

class EducatorOverviewScreen extends StatelessWidget {
  const EducatorOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([s.store, s.sync]),
      builder: (context, _) {
        final u = s.auth.user;
        if (u == null || u.classCode == null) return const SizedBox.shrink();
        final store = s.store;
        final roster = store.studentsIn(u.classCode!);
        final summaries = roster.map(store.summaryOf).toList();
        final avg = summaries.isEmpty
            ? 0
            : (summaries.map((e) => e.avgScorePct).reduce((a, b) => a + b) / summaries.length).round();
        final atRisk = summaries.where((e) => e.atRisk).toList()..sort((a, b) => a.avgScorePct.compareTo(b.avgScorePct));
        final top = [...summaries]..sort((a, b) => b.points.compareTo(a.points));
        final water = WaterMeter.read(DateTime.now());
        final feed = store.announcementsFor(u.classCode).take(6).toList();
        final text = Theme.of(context).textTheme;

        return Scaffold(
          appBar: aqAppBar(context, 'Overview', actions: [
            IconButton(tooltip: 'NGO partners', icon: const Icon(Icons.handshake_outlined), onPressed: () => showNgoPartners(context)),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => postClassAnnouncement(context, u),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Announce'),
          ),
          body: PageFrame(
            children: [
              Text(u.name, style: text.headlineSmall),
              Text('${u.school ?? ''}, class ${u.classCode}', style: text.bodyMedium),
              const SizedBox(height: 16),
              StatStrip(items: [
                StatItem('Students', '${roster.length}', icon: Icons.groups_outlined),
                StatItem('Quiz average', '$avg%', icon: Icons.quiz_outlined),
                StatItem('Pickups done', '${store.handedOverCount(u.classCode)}', icon: Icons.local_shipping_outlined),
                StatItem('Water today', '${water.usedLitres} L', icon: Icons.water_drop_outlined,
                    tone: water.underTarget ? null : AqColors.ochreInk),
              ]),
              const SizedBox(height: 12),
              InfoNote(
                'Works offline: all ${ContentSeed.modules.length} modules and quizzes are stored on this device. '
                '${s.sync.isConfigured ? '${s.sync.pendingCount} update(s) waiting to sync.' : 'Connect a server to sync between devices.'}',
                tone: Tone.neutral,
                icon: Icons.offline_bolt_outlined,
              ),
              SectionHeader('Needs attention', subtitle: atRisk.isEmpty ? 'Everyone is on track' : null,
                  action: 'Open class', onAction: () => context.go('/educator/class')),
              if (atRisk.isNotEmpty)
                Card(
                  child: Column(
                    children: [
                      for (final a in atRisk.take(4))
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            child: Text(_initials(a.profile.name)),
                          ),
                          title: Text(a.profile.name),
                          subtitle: Text(a.riskReason),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showStudentSheet(context, a.profile),
                        ),
                    ],
                  ),
                ),
              const SectionHeader('Top of the class'),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < top.length && i < 3; i++)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: i == 0 ? AqColors.ochre : Theme.of(context).colorScheme.surfaceContainerHigh,
                          foregroundColor: AqColors.ink,
                          child: Text('${i + 1}'),
                        ),
                        title: Text(top[i].profile.name),
                        subtitle: Text('${top[i].avgScorePct}% quiz average, ${top[i].modulesDone}/6 modules'),
                        trailing: Text('${top[i].points} pts', style: text.titleSmall),
                        onTap: () => showStudentSheet(context, top[i].profile),
                      ),
                  ],
                ),
              ),
              const SectionHeader('Announcements', subtitle: 'Yours and NGO broadcasts your class can see'),
              if (feed.isEmpty)
                const EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No announcements yet',
                  message: 'Use Announce to give your class a task. You will see who completes it.',
                )
              else
                for (final a in feed) ...[
                  _AnnouncementProgress(announcement: a),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _AnnouncementProgress extends StatelessWidget {
  const _AnnouncementProgress({required this.announcement});
  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final total = a.audienceSize == 0 ? 1 : a.audienceSize;
    final done = a.completedBy.length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (a.senderRole == Role.ngo)
                      const Pill('From NGO', tone: Tone.success, icon: Icons.volunteer_activism_outlined)
                    else
                      const Pill('Your class', tone: Tone.info),
                    if (a.urgent) const Pill('Urgent', tone: Tone.danger),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(Fmt.relative(a.sentAt), style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(a.message, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Semantics(
            label: '$done of ${a.audienceSize} students completed',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (done / total).clamp(0.0, 1.0),
                        minHeight: 6,
                        color: a.senderRole == Role.ngo ? scheme.tertiary : scheme.primary,
                        backgroundColor: scheme.surfaceContainerHighest,
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

Future<void> showNgoPartners(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('NGO partners', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final n in CommunitySeed.ngos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: Text(n.name),
              subtitle: Text('${n.area}. ${n.focus}'),
              trailing: IconButton(
                tooltip: 'Call ${n.shortName}',
                icon: const Icon(Icons.call_outlined),
                onPressed: () {
                  final p = InputRules.normalizePhone(n.phone);
                  if (p != null) unawaited(launchUrl(Uri(scheme: 'tel', path: p)));
                },
              ),
            ),
        ],
      ),
    ),
  );
}

// ====================================================================== CLASS

class EducatorClassScreen extends StatefulWidget {
  const EducatorClassScreen({super.key});

  @override
  State<EducatorClassScreen> createState() => _EducatorClassScreenState();
}

class _EducatorClassScreenState extends State<EducatorClassScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      appBar: aqAppBar(context, 'Class'),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.store, _search]),
        builder: (context, _) {
          final u = s.auth.user;
          if (u == null || u.classCode == null) return const SizedBox.shrink();
          final q = _search.text.trim().toLowerCase();
          final roster = s.store.studentsIn(u.classCode!).where((p) => q.isEmpty || p.name.toLowerCase().contains(q)).toList();
          final text = Theme.of(context).textTheme;
          return PageFrame(
            children: [
              Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Class code', style: text.labelLarge),
                          SelectableText(u.classCode!, style: text.headlineSmall),
                          Text('Students join with this code and a PIN they choose.', style: text.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy class code',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: u.classCode!));
                        if (context.mounted) context.toast('Class code copied');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search students'),
              ),
              const SizedBox(height: 12),
              if (roster.isEmpty)
                const EmptyState(icon: Icons.groups_outlined, title: 'No students found', message: 'Share the class code so students can join.')
              else
                Card(
                  child: Column(
                    children: [
                      for (final p in roster) _StudentRow(summary: s.store.summaryOf(p)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.summary});
  final StudentSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = summary.profile;
    return ListTile(
      leading: CircleAvatar(child: Text(_initials(p.name))),
      title: Text(p.name),
      subtitle: Text('${summary.modulesDone}/6 modules, ${summary.avgScorePct}% average, ${summary.points} points'),
      trailing: !p.isClaimed
          ? const Pill('Not joined', tone: Tone.neutral)
          : summary.atRisk
              ? const Pill('At risk', tone: Tone.warning, icon: Icons.trending_down)
              : null,
      onTap: () => showStudentSheet(context, p),
    );
  }
}

/// Student details with privacy-first contact: the phone number stays
/// masked until the educator deliberately reveals it.
Future<void> showStudentSheet(BuildContext context, StudentProfile p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _StudentSheet(profile: p),
  );
}

class _StudentSheet extends StatefulWidget {
  const _StudentSheet({required this.profile});
  final StudentProfile profile;

  @override
  State<_StudentSheet> createState() => _StudentSheetState();
}

class _StudentSheetState extends State<_StudentSheet> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final p = widget.profile;
    final sum = s.store.summaryOf(p);
    final text = Theme.of(context).textTheme;
    final phone = p.phone == null ? null : InputRules.normalizePhone(p.phone!);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.name, style: text.headlineSmall),
          Text(p.isClaimed ? 'Joined ${Fmt.date(p.joinedAt)}' : 'Has not signed in yet', style: text.bodySmall),
          const SizedBox(height: 14),
          StatStrip(items: [
            StatItem('Modules', '${sum.modulesDone}/6'),
            StatItem('Average', '${sum.avgScorePct}%'),
            StatItem('Points', '${sum.points}'),
          ]),
          const SizedBox(height: 12),
          if (sum.lastActive != null) Text('Last active ${Fmt.relative(sum.lastActive!)}', style: text.bodySmall),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_outlined),
            title: Text(_revealed ? (p.phone ?? 'Not available') : InputRules.maskPhone(p.phone ?? '')),
            subtitle: const Text('Guardian phone'),
            trailing: phone == null || _revealed
                ? null
                : TextButton(
                    onPressed: () async {
                      final ok = await confirmAction(context,
                          title: 'Show phone number?',
                          message: 'Only use it to contact the student or their guardian about school work.',
                          confirmLabel: 'Show');
                      if (ok && mounted) {
                        setState(() => _revealed = true);
                        s.store.logEvent(s.auth.user?.name ?? 'Educator', 'viewed the phone number of ${p.name}');
                      }
                    },
                    child: const Text('Show'),
                  ),
          ),
          if (_revealed && phone != null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.https('wa.me', '/${phone.replaceAll('+', '')}'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/thread/${p.id}');
            },
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Message in AquaAware'),
          ),
          if (p.isClaimed) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final ok = await confirmAction(context,
                    title: 'Reset ${p.name}’s PIN?',
                    message: 'They will choose a new PIN the next time they sign in with the class code.',
                    confirmLabel: 'Reset PIN');
                if (!ok || !context.mounted) return;
                await s.auth.resetStudentPin(p.id, by: s.auth.user?.name ?? 'Educator');
                if (context.mounted) {
                  Navigator.of(context).pop();
                  context.toast('PIN reset for ${p.name}');
                }
              },
              icon: const Icon(Icons.lock_reset),
              label: const Text('Reset PIN'),
            ),
          ],
        ],
      ),
    );
  }
}

// =================================================================== MESSAGES

class EducatorMessagesScreen extends StatelessWidget {
  const EducatorMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      appBar: aqAppBar(context, 'Messages'),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) {
          final u = s.auth.user;
          if (u == null) return const SizedBox.shrink();
          final convos = s.store.conversationsOf(u.id);
          final text = Theme.of(context).textTheme;
          if (convos.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No messages yet',
              message: 'When students ask a question it appears here. You can also message a student from the Class tab.',
            );
          }
          return PageFrame(
            children: [
              Card(
                child: Column(
                  children: [
                    for (final m in convos)
                      Builder(builder: (context) {
                        final peerId = m.fromId == u.id ? m.toId : m.fromId;
                        final peerName = m.fromId == u.id ? m.toName : m.fromName;
                        final unread = s.store.unreadFor(u.id, fromId: peerId);
                        return ListTile(
                          leading: CircleAvatar(child: Text(_initials(peerName))),
                          title: Text(peerName, style: unread > 0 ? text.titleSmall?.copyWith(fontWeight: FontWeight.w800) : null),
                          subtitle: Text('${m.fromId == u.id ? 'You: ' : ''}${m.body}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(Fmt.relative(m.sentAt), style: text.bodySmall),
                              if (unread > 0) Badge(label: Text('$unread')),
                            ],
                          ),
                          onTap: () => context.push('/thread/$peerId'),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ================================================================== RESOURCES

class EducatorResourcesScreen extends StatelessWidget {
  const EducatorResourcesScreen({super.key});

  /// Reads only the first [FileRules.headLength] bytes, never the whole file.
  static Future<List<int>> _readHead(PlatformFile f) async {
    final head = <int>[];
    await for (final chunk in f.readAsByteStream()) {
      head.addAll(chunk.take(FileRules.headLength - head.length));
      if (head.length >= FileRules.headLength) break;
    }
    return head;
  }

  Future<void> _upload(BuildContext context, SessionUser u) async {
    final s = context.services;
    try {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: FileRules.allowed);
      if (f == null || !context.mounted) return;
      final ext = (f.extension ?? '').toLowerCase();
      if (!FileRules.allowed.contains(ext)) {
        context.toast('Only PDF, slides and documents can be shared.', error: true);
        return;
      }
      final size = f.lengthSync() ?? await f.length();
      if (!context.mounted) return;
      if (size != null && size > FileRules.maxBytes) {
        context.toast('That file is over 25 MB. Please share a smaller copy.', error: true);
        return;
      }
      final head = await _readHead(f);
      if (!context.mounted) return;
      if (!FileRules.contentMatches(ext, head)) {
        s.store.logEvent(u.name, 'tried to share a file whose content did not match ".$ext"');
        context.toast('That file is not a real .$ext file, so it was not shared.', error: true);
        return;
      }
      String? local;
      final path = f.path;
      if (!kIsWeb && path != null) local = await storeLocalCopy(sourcePath: path, fileName: f.name);
      await s.store.addResource(by: u, classCode: u.classCode!, fileName: f.name, sizeBytes: size, localPath: local);
      if (context.mounted) context.toast('Shared "${f.name}" with ${u.classCode}');
    } catch (_) {
      if (context.mounted) context.toast('The file could not be added. Try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final u = s.auth.user;
    return Scaffold(
      appBar: aqAppBar(context, 'Resources'),
      floatingActionButton: u == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _upload(context, u),
              icon: const Icon(Icons.upload_file),
              label: const Text('Add file'),
            ),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) {
          if (u == null || u.classCode == null) return const SizedBox.shrink();
          final list = s.store.resourcesFor(u.classCode!);
          final classSize = s.store.studentsIn(u.classCode!).length;
          final text = Theme.of(context).textTheme;
          return PageFrame(
            children: [
              Text('PDFs, slides and documents up to 25 MB. Students see them under Learn.', style: text.bodyMedium),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const EmptyState(icon: Icons.folder_open_outlined, title: 'Nothing shared yet', message: 'Add a worksheet or slides for your class.')
              else
                Card(
                  child: Column(
                    children: [
                      for (final r in list)
                        ListTile(
                          leading: Icon(resourceIcon(r.kind)),
                          title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${r.kindLabel}${r.sizeBytes == null ? '' : ', ${(r.sizeBytes! / 1048576).toStringAsFixed(1)} MB'}, '
                            '${Fmt.relative(r.addedAt)}, seen by ${(r.seenBy.length - 1).clamp(0, classSize)} of $classSize',
                          ),
                          onTap: () => openResource(context, r),
                          trailing: IconButton(
                            tooltip: 'Remove ${r.name}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await confirmAction(context,
                                  title: 'Remove this file?', message: 'Students will no longer see "${r.name}".', confirmLabel: 'Remove', destructive: true);
                              if (!ok) return;
                              final removed = await s.store.removeResource(r.id);
                              final lp = removed?.localPath;
                              if (lp != null) await deleteLocalCopy(lp);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const InfoNote(
                'Files are kept privately on this device, and students see them when they sign in here. '
                'Sending files to students’ own phones needs file storage on the server, which this version does not include yet.',
                tone: Tone.neutral,
              ),
            ],
          );
        },
      ),
    );
  }
}

// =================================================================== INSIGHTS

class EducatorInsightsScreen extends StatelessWidget {
  const EducatorInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      appBar: aqAppBar(context, 'Insights'),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) {
          final u = s.auth.user;
          if (u == null || u.classCode == null) return const SizedBox.shrink();
          final avgs = s.store.moduleAverages(u.classCode!);
          final week = s.store.weeklyEngagement(u.classCode);
          final today = DateTime.now();
          final moduleData = [
            for (var i = 0; i < ContentSeed.modules.length; i++)
              ChartDatum(
                String.fromCharCode(65 + i),
                avgs[ContentSeed.modules[i].id]?.toDouble(),
                longLabel: 'Module ${String.fromCharCode(65 + i)}: ${ContentSeed.modules[i].title}',
              ),
          ];
          final weakest = moduleData.where((d) => d.value != null).fold<ChartDatum?>(
              null, (w, d) => w == null || d.value! < w.value! ? d : w);
          final weekData = [
            for (var i = 0; i < 7; i++)
              ChartDatum(Fmt.weekday(today.subtract(Duration(days: 6 - i))).substring(0, 2), week[i].toDouble(),
                  longLabel: Fmt.date(today.subtract(Duration(days: 6 - i)))),
          ];
          final text = Theme.of(context).textTheme;
          return PageFrame(
            children: [
              const SectionHeader('Quiz average by module', subtitle: 'Best score per student, averaged across the class'),
              Panel(
                child: AqChart(
                  data: moduleData,
                  maxValue: 100,
                  unit: '%',
                  highlightBelow: 70,
                  summary: 'Bar chart of class quiz averages. '
                      '${moduleData.where((d) => d.value != null).map((d) => '${d.longLabel}: ${d.value!.round()} percent').join('. ')}',
                ),
              ),
              if (weakest != null) ...[
                const SizedBox(height: 10),
                InfoNote(
                  '${weakest.longLabel} is the weakest at ${weakest.value!.round()}%. Consider revising it together in class.',
                  tone: weakest.value! < 70 ? Tone.warning : Tone.info,
                  icon: Icons.tips_and_updates_outlined,
                ),
              ],
              const SectionHeader('Activity this week', subtitle: 'Lessons, quizzes, tasks and pickups that earned points'),
              Panel(
                child: AqChart(
                  data: weekData,
                  line: true,
                  summary: 'Line chart of class activity over the last 7 days: ${weekData.map((d) => '${d.longLabel}: ${d.value!.round()}').join(', ')}.',
                ),
              ),
              const SizedBox(height: 10),
              Text('Bars in ochre are below 70%. Charts can be read as tables using the button under each.', style: text.bodySmall),
            ],
          );
        },
      ),
    );
  }
}
