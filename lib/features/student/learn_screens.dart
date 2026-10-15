// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/file_store.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../data/app_store.dart';
import '../../data/models/models.dart';
import '../../data/points_rules.dart';
import '../../data/seed/content_seed.dart';
import '../../services/app_services.dart';
import '../../widgets/common.dart';
import '../../widgets/slide_art.dart';

IconData moduleIcon(String id) => switch (id) {
      'MOD_A' => Icons.water_drop_outlined,
      'MOD_B' => Icons.recycling,
      'MOD_C' => Icons.autorenew,
      'MOD_D' => Icons.local_shipping_outlined,
      'MOD_E' => Icons.thunderstorm_outlined,
      _ => Icons.spa_outlined,
    };

IconData resourceIcon(ResourceKind k) => switch (k) {
      ResourceKind.pdf => Icons.picture_as_pdf_outlined,
      ResourceKind.slides => Icons.slideshow_outlined,
      ResourceKind.document => Icons.description_outlined,
      ResourceKind.other => Icons.insert_drive_file_outlined,
    };

Future<void> openResource(BuildContext context, Resource r) async {
  final path = r.localPath;
  if (path == null) {
    context.toast('This sample file is not stored on this device. Ask the person who shared it to share it again.', error: true);
    return;
  }
  final problem = await openLocalFile(path);
  if (problem != null && context.mounted) context.toast(problem, error: true);
}

// ====================================================================== LEARN

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  AppServices? _services;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services ??= context.services;
  }

  @override
  void dispose() {
    // Like the first version: resources count as seen once you leave Learn.
    final s = _services;
    final u = s?.auth.user;
    if (s != null && u?.classCode != null) {
      unawaited(s.store.markResourcesSeen(u!.classCode!, u.id));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Scaffold(
      appBar: aqAppBar(context, 'Learn'),
      body: ListenableBuilder(
        listenable: s.store,
        builder: (context, _) {
          final u = s.auth.user;
          if (u == null) return const SizedBox.shrink();
          final p = s.store.progressOf(u.id);
          final done = p.modulesDone.length;
          final total = ContentSeed.modules.length;
          final resources = u.classCode == null ? <Resource>[] : s.store.resourcesFor(u.classCode!);
          final text = Theme.of(context).textTheme;
          final leader = s.store.kindOf(u.classCode).leaderNoun;
          return PageFrame(
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$done of $total modules done', style: text.titleLarge),
                    const SizedBox(height: 10),
                    Semantics(
                      label: '$done of $total modules complete',
                      child: ExcludeSemantics(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(value: done / total, minHeight: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      done == total
                          ? 'Every module done — you have earned the Water scholar badge.'
                          : 'Each module earns ${PointRules.moduleCompleted} points, and quizzes add more as you improve.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              SectionHeader('From your $leader', subtitle: resources.isEmpty ? null : 'Opened files stay on this device'),
              if (resources.isEmpty)
                Text('Nothing shared yet. Files your $leader uploads appear here.', style: text.bodyMedium)
              else
                Card(
                  child: Column(
                    children: [
                      for (final r in resources.take(6))
                        ListTile(
                          leading: Icon(resourceIcon(r.kind)),
                          title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${r.kindLabel}, added ${Fmt.relative(r.addedAt)}'),
                          trailing: r.seenBy.contains(u.id) ? const Icon(Icons.open_in_new) : const Pill('New', tone: Tone.info),
                          onTap: () => openResource(context, r),
                        ),
                    ],
                  ),
                ),
              const SectionHeader('Modules'),
              for (final m in ContentSeed.modules) ...[
                _ModuleCard(module: m, progress: p),
                const SizedBox(height: 10),
              ],
              const SectionHeader('Activities'),
              Panel(
                onTap: () => context.push('/sort'),
                semanticLabel: 'Sorting challenge. Drag each item into the right bin.',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_outlined, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sorting challenge', style: text.titleMedium),
                          Text('Put each item in the right coloured bin. +${PointRules.sortGame} points the first time.',
                              style: text.bodySmall),
                        ],
                      ),
                    ),
                    if (s.store.hasEarned(u.id, 'sort_game')) const Pill('Done', tone: Tone.success, icon: Icons.check),
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

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.progress});
  final LearningModule module;
  final StudentProgress progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final done = progress.modulesDone.contains(module.id);
    final best = progress.quizBest[module.id];
    final total = ContentSeed.quizFor(module.id).length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: done ? scheme.tertiaryContainer : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AqRadius.control),
                ),
                child: Icon(moduleIcon(module.id), color: done ? scheme.onTertiaryContainer : scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.title, style: text.titleMedium),
                    Text(module.summary, style: text.bodyMedium),
                    const SizedBox(height: 4),
                    Text('${module.minutes} min, ${Fmt.plural(module.slides.length, 'slide')}', style: text.bodySmall),
                  ],
                ),
              ),
              if (done) const Pill('Done', tone: Tone.success, icon: Icons.check),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: () => context.push('/learn/${module.id}'),
                child: Text(done ? 'Review lesson' : 'Start lesson'),
              ),
              OutlinedButton(
                onPressed: () => context.push('/quiz/${module.id}'),
                child: Text(best == null ? 'Take the quiz' : 'Quiz best: $best/$total'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================= MODULE PLAYER

class ModulePlayerScreen extends StatefulWidget {
  const ModulePlayerScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  State<ModulePlayerScreen> createState() => _ModulePlayerScreenState();
}

class _ModulePlayerScreenState extends State<ModulePlayerScreen> {
  final PageController _pages = PageController();
  int _index = 0;
  AppServices? _services;

  LearningModule get _module => ContentSeed.module(widget.moduleId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services ??= context.services;
  }

  @override
  void dispose() {
    unawaited(_services?.speech.stop());
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    final n = _module.slides.length;
    if (i < 0 || i >= n) return;
    if (context.reduceMotion) {
      _pages.jumpToPage(i);
    } else {
      unawaited(_pages.animateToPage(i, duration: AqMotion.medium, curve: AqMotion.emphasized));
    }
  }

  Future<void> _finish() async {
    final s = context.services;
    final u = s.auth.user;
    if (u == null) return;
    await s.speech.stop();
    try {
      final pts = await s.store.completeModule(u.id, widget.moduleId);
      if (!mounted) return;
      context.toast(pts > 0 ? 'Lesson complete! +$pts points. Now try the quiz.' : 'Lesson reviewed. Ready for the quiz?');
      context.pushReplacement('/quiz/${widget.moduleId}');
    } on ActionRefused catch (e) {
      if (mounted) context.toast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final m = _module;
    final n = m.slides.length;
    final last = _index == n - 1;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close lesson',
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(m.title),
        actions: [
          if (s.speech.available)
            ListenableBuilder(
              listenable: s.speech,
              builder: (context, _) {
                final id = 'slide-${m.id}-$_index';
                final reading = s.speech.speaking && s.speech.currentId == id;
                final slide = m.slides[_index];
                return IconButton(
                  tooltip: reading ? 'Stop reading' : 'Read this slide aloud',
                  isSelected: reading,
                  icon: const Icon(Icons.volume_up_outlined),
                  selectedIcon: const Icon(Icons.stop_circle_outlined),
                  onPressed: () => reading
                      ? s.speech.stop()
                      : s.speech.speak('${slide.title}. ${slide.text}', id: id, rate: s.settings.speechRate),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _goTo(_index + 1),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _goTo(_index - 1),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              Semantics(
                label: 'Slide ${_index + 1} of $n',
                child: ExcludeSemantics(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_index + 1) / n),
                    duration: context.motion(AqMotion.medium),
                    builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 4),
                  ),
                ),
              ),
              if (s.device.shouldConserveEnergy)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: InfoNote('Battery is low: animations are paused to save power.',
                      tone: Tone.warning, icon: Icons.battery_alert),
                ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: n,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    unawaited(s.speech.stop());
                    context.announce('Slide ${i + 1} of $n: ${m.slides[i].title}');
                  },
                  itemBuilder: (context, i) => _SlideView(module: m, index: i),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: OutlinedButton.icon(
                          onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('${_index + 1} / $n', style: text.labelLarge),
                      ),
                      Flexible(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: last ? _finish : () => _goTo(_index + 1),
                          icon: Icon(last ? Icons.quiz_outlined : Icons.arrow_forward),
                          label: Text(last ? 'Finish and quiz' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.module, required this.index});
  final LearningModule module;
  final int index;

  @override
  Widget build(BuildContext context) {
    final slide = module.slides[index];
    final text = Theme.of(context).textTheme;
    final last = index == module.slides.length - 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SlideArtView(art: slide.art, variant: index),
              const SizedBox(height: 22),
              Semantics(header: true, child: Text(slide.title, style: text.headlineMedium)),
              const SizedBox(height: 12),
              Text(slide.text, style: text.bodyLarge?.copyWith(fontSize: 19, height: 1.6)),
              if (last && module.activity == 'sort_game') ...[
                const SizedBox(height: 24),
                Panel(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Try it yourself', style: text.titleMedium),
                      const SizedBox(height: 4),
                      const Text('Drag everyday items into the right coloured bin.'),
                      const SizedBox(height: 10),
                      FilledButton.tonal(onPressed: () => context.push('/sort'), child: const Text('Open the sorting challenge')),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
