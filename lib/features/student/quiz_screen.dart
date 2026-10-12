import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/app_store.dart';
import '../../data/models/models.dart';
import '../../data/points_rules.dart';
import '../../data/seed/content_seed.dart';
import '../../services/app_services.dart';
import '../../services/settings_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> _qs = ContentSeed.quizFor(widget.moduleId);
  late final List<int?> _answers = List<int?>.filled(_qs.length, null);
  int _i = 0;
  bool _timedOut = false;
  bool _finished = false;
  bool _saving = false;
  bool _leaving = false;
  int _burst = 0;
  Timer? _ticker;
  int _secondsLeft = 0;
  int _totalSeconds = 0;
  ({int points, bool newBest, int previousBest})? _result;
  AppServices? _services;

  String get _backupSlot => 'quiz_backup_${widget.moduleId}';
  int get _score => [for (var k = 0; k < _qs.length; k++) if (_answers[k] == _qs[k].correct) 1].length;
  int? get _picked => _answers[_i];
  bool get _answered => _picked != null || _timedOut;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = context.services;
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerResume());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_services?.speech.stop());
    super.dispose();
  }

  // ------------------------------------------------------------ backup ---

  /// Q2 — progress is saved after every answer, so a phone that dies on low
  /// battery (or an accidental close) loses nothing.
  Future<void> _saveBackup() async {
    await _services?.vault.writeJson(_backupSlot, {
      'i': _i,
      'answers': _answers,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _offerResume() async {
    final raw = await context.services.vault.readJson(_backupSlot);
    if (!mounted) return;
    if (raw is Map) {
      final at = DateTime.fromMillisecondsSinceEpoch((raw['at'] as int?) ?? 0);
      final saved = (raw['answers'] as List?)?.cast<int?>() ?? const <int?>[];
      final idx = (raw['i'] as int?) ?? 0;
      final fresh = DateTime.now().difference(at) < const Duration(days: 1);
      if (fresh && saved.length == _qs.length && saved.any((a) => a != null)) {
        final resume = await confirmAction(
          context,
          title: 'Pick up where you left off?',
          message: 'You had answered ${saved.where((a) => a != null).length} of ${_qs.length} questions.',
          confirmLabel: 'Resume',
        );
        if (!mounted) return;
        if (resume) {
          setState(() {
            for (var k = 0; k < saved.length; k++) {
              _answers[k] = saved[k];
            }
            _i = math.min(idx + (saved[idx] != null ? 1 : 0), _qs.length - 1);
          });
        } else {
          await context.services.vault.delete(_backupSlot);
        }
      }
    }
    if (mounted) _startQuestion();
  }

  // ------------------------------------------------------------- timer ---

  void _startQuestion() {
    _ticker?.cancel();
    final mode = context.services.settings.quizTimer;
    setState(() {
      _timedOut = false;
      _totalSeconds = mode.seconds;
      _secondsLeft = mode.seconds;
    });
    if (mode == QuizTimerMode.off || _picked != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft == 10) context.announce('10 seconds left');
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() => _timedOut = true);
        final q = _qs[_i];
        context.announce('Time is up. The answer was ${String.fromCharCode(65 + q.correct)}, ${q.options[q.correct]}.');
        unawaited(_saveBackup());
      }
    });
  }

  void _choose(int option) {
    if (_answered || _finished) return;
    _ticker?.cancel();
    final q = _qs[_i];
    setState(() => _answers[_i] = option);
    final ok = option == q.correct;
    if (ok) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    context.announce(ok
        ? 'Correct!'
        : 'Not quite. The answer is ${String.fromCharCode(65 + q.correct)}, ${q.options[q.correct]}.');
    unawaited(_saveBackup());
  }

  Future<void> _next() async {
    unawaited(_services?.speech.stop());
    if (_i < _qs.length - 1) {
      setState(() => _i++);
      _startQuestion();
      context.announce('Question ${_i + 1} of ${_qs.length}. ${_qs[_i].prompt}');
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    final s = context.services;
    final u = s.auth.user;
    if (u == null) return;
    setState(() => _saving = true);
    try {
      final r = await s.store.recordQuiz(u.id, widget.moduleId, _score, _qs.length);
      await s.vault.delete(_backupSlot);
      if (!mounted) return;
      setState(() {
        _result = r;
        _finished = true;
        _saving = false;
        _burst++;
      });
      context.announce('Quiz finished. You scored $_score out of ${_qs.length}.');
    } on ActionRefused catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.toast(e.message, error: true);
    }
  }

  void _restart() {
    setState(() {
      for (var k = 0; k < _answers.length; k++) {
        _answers[k] = null;
      }
      _i = 0;
      _finished = false;
      _result = null;
    });
    _startQuestion();
  }

  Future<void> _close() async {
    if (_finished || _answers.every((a) => a == null)) {
      context.pop();
      return;
    }
    final leave = await confirmAction(context,
        title: 'Leave the quiz?', message: 'Your answers so far are saved. You can resume later today.', confirmLabel: 'Leave');
    if (!leave || !mounted) return;
    _ticker?.cancel();
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  // ---------------------------------------------------------------- UI ---

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final m = ContentSeed.module(widget.moduleId);
    return PopScope(
      canPop: _finished || _leaving || _answers.every((a) => a == null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Close quiz', icon: const Icon(Icons.close), onPressed: _close),
          title: Text('Quiz: ${m.title}'),
          actions: [
            if (!_finished && s.speech.available)
              ListenableBuilder(
                listenable: s.speech,
                builder: (context, _) {
                  final id = 'quiz-${m.id}-$_i';
                  final reading = s.speech.speaking && s.speech.currentId == id;
                  final q = _qs[_i];
                  final spoken = '${q.prompt}. ${[
                    for (var k = 0; k < q.options.length; k++) '${String.fromCharCode(65 + k)}: ${q.options[k]}'
                  ].join('. ')}';
                  return IconButton(
                    tooltip: reading ? 'Stop reading' : 'Read the question aloud',
                    isSelected: reading,
                    icon: const Icon(Icons.volume_up_outlined),
                    selectedIcon: const Icon(Icons.stop_circle_outlined),
                    onPressed: () => reading ? s.speech.stop() : s.speech.speak(spoken, id: id, rate: s.settings.speechRate),
                  );
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: _finished ? _results(context) : _question(context),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final q = _qs[_i];
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final timed = _totalSeconds > 0;
    final low = timed && _secondsLeft <= _totalSeconds * 0.3;

    return CallbackShortcuts(
      bindings: {
        for (var k = 0; k < q.options.length && k < 4; k++) ...{
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + k)): () => _choose(k),
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.keyA.keyId + k)): () => _choose(k),
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (_answered) unawaited(_next());
        },
      },
      child: Focus(
        autofocus: true,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Row(
                  children: [
                    Text('Question ${_i + 1} of ${_qs.length}', style: text.labelLarge),
                    const Spacer(),
                    if (timed)
                      ExcludeSemantics(
                        child: Pill(
                          _timedOut ? 'Time is up' : '$_secondsLeft s',
                          tone: low ? Tone.warning : Tone.neutral,
                          icon: Icons.timer_outlined,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (timed)
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _totalSeconds == 0 ? 0 : (_secondsLeft / _totalSeconds).clamp(0.0, 1.0),
                        minHeight: 6,
                        color: low ? scheme.secondary : scheme.primary,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                Semantics(header: true, child: Text(q.prompt, style: text.headlineSmall)),
                const SizedBox(height: 20),
                for (var k = 0; k < q.options.length; k++) ...[
                  _OptionTile(
                    letter: String.fromCharCode(65 + k),
                    label: q.options[k],
                    state: !_answered
                        ? _OptionState.idle
                        : k == q.correct
                            ? _OptionState.correct
                            : k == _picked
                                ? _OptionState.wrong
                                : _OptionState.muted,
                    onTap: _answered ? null : () => _choose(k),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_answered) ...[
                  const SizedBox(height: 6),
                  Semantics(
                    liveRegion: true,
                    child: InfoNote(
                      _picked == q.correct
                          ? 'Correct!${q.explain == null ? '' : ' ${q.explain}'}'
                          : '${_timedOut && _picked == null ? 'Time is up.' : 'Not quite.'} The answer is ${String.fromCharCode(65 + q.correct)}: ${q.options[q.correct]}.',
                      tone: _picked == q.correct ? Tone.success : Tone.warning,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BusyButton(
                    label: _i == _qs.length - 1 ? 'See my score' : 'Next question',
                    busyLabel: 'Saving your score…',
                    icon: _i == _qs.length - 1 ? Icons.flag_outlined : Icons.arrow_forward,
                    onPressed: _saving ? null : _next,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results(BuildContext context) {
    final s = context.services;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ratio = _score / _qs.length;
    final stars = ratio >= 0.8 ? 3 : ratio >= 0.5 ? 2 : 1;
    final r = _result;
    final pointsLine = r == null
        ? ''
        : r.points > 0
            ? '+${r.points} points${r.previousBest > 0 ? ' for beating your best of ${r.previousBest}/${_qs.length}' : ''}'
            : 'No new points this time. Points come from beating your best (${math.max(r.previousBest, _score)}/${_qs.length}).';

    return DropletBurst(
      trigger: _burst,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Semantics(
                  label: '$stars of 3 stars',
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var k = 0; k < 3; k++)
                          RiseIn(
                            delay: Duration(milliseconds: 150 * k),
                            child: Icon(
                              k < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 52,
                              color: k < stars ? AqColors.ochre : scheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('$_score / ${_qs.length}', style: text.displayMedium),
                const SizedBox(height: 4),
                Text(
                  ratio >= 0.8 ? 'Excellent work!' : ratio >= 0.5 ? 'Good effort — review and try again.' : 'Keep going — the lesson will help.',
                  style: text.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // InfoNote wraps long lines; a Pill would overflow on phones.
                if (pointsLine.isNotEmpty)
                  InfoNote(pointsLine, tone: (r?.points ?? 0) > 0 ? Tone.success : Tone.neutral, icon: Icons.water_drop_outlined),
                const SizedBox(height: 12),
                Text(
                  s.sync.isConfigured
                      ? 'Your score is saved and being sent to the server (retries automatically if the network drops).'
                      : 'Your score is saved securely on this device.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/student/learn'),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Back to lessons'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _restart, icon: const Icon(Icons.replay), label: const Text('Try again')),
                const SizedBox(height: 10),
                Text('Each correct answer above your best earns ${PointRules.perCorrectAnswer} points.', style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, muted }

class _OptionTile extends StatefulWidget {
  const _OptionTile({required this.letter, required this.label, required this.state, this.onTap});
  final String letter;
  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(_OptionTile old) {
    super.didUpdateWidget(old);
    if (widget.state == _OptionState.wrong && old.state != _OptionState.wrong && !context.reduceMotion) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (bg, border, icon, status) = switch (widget.state) {
      _OptionState.idle => (scheme.surface, scheme.outlineVariant, null, ''),
      _OptionState.correct => (scheme.tertiaryContainer, scheme.tertiary, Icons.check_circle, 'correct answer'),
      _OptionState.wrong => (scheme.errorContainer, scheme.error, Icons.cancel, 'your answer, incorrect'),
      _OptionState.muted => (scheme.surface, scheme.outlineVariant, null, ''),
    };
    final fg = widget.state == _OptionState.muted ? scheme.onSurfaceVariant : scheme.onSurface;

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(math.sin(_shake.value * math.pi * 5) * 8 * (1 - _shake.value), 0),
        child: child,
      ),
      child: Semantics(
        button: widget.onTap != null,
        label: 'Option ${widget.letter}: ${widget.label}${status.isEmpty ? '' : ', $status'}',
        // The InkWell is inside ExcludeSemantics, so expose the tap here —
        // otherwise TalkBack / VoiceOver users could not answer at all.
        onTap: widget.onTap,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: context.motion(AqMotion.fast),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AqRadius.card),
              border: Border.all(color: border, width: widget.state == _OptionState.idle ? 1 : 2),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(AqRadius.card),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.state == _OptionState.idle ? scheme.primaryContainer : border.withValues(alpha: 0.18),
                        ),
                        child: Text(widget.letter, style: text.titleSmall?.copyWith(color: fg)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(widget.label, style: text.bodyLarge?.copyWith(color: fg))),
                      if (icon != null) Icon(icon, color: border),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
