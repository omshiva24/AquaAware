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
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class _BinStyle {
  const _BinStyle(this.label, this.meaning, this.color, this.onColor, this.icon);
  final String label;
  final String meaning;
  final Color color;
  final Color onColor;
  final IconData icon;
}

/// India's colour-coded bins. These are real-world colours, so every bin
/// also carries its name and meaning in text.
const _bins = <BinColor, _BinStyle>{
  BinColor.green: _BinStyle('Green', 'Wet and organic', Color(0xFF2E7D32), Colors.white, Icons.compost),
  BinColor.blue: _BinStyle('Blue', 'Dry and recyclable', Color(0xFF1565C0), Colors.white, Icons.recycling),
  BinColor.red: _BinStyle('Red', 'Hazardous', Color(0xFFC62828), Colors.white, Icons.warning_amber_rounded),
  BinColor.yellow: _BinStyle('Yellow', 'Medical', Color(0xFFF9C433), Color(0xFF2B1D00), Icons.medical_services_outlined),
};

class SortGameScreen extends StatefulWidget {
  const SortGameScreen({super.key});

  @override
  State<SortGameScreen> createState() => _SortGameScreenState();
}

class _SortGameScreenState extends State<SortGameScreen> {
  late List<SortItem> _items;
  final List<SortItem> _sorted = [];
  SortItem? _selected;
  int _mistakes = 0;
  int _round = 0;
  int _burst = 0;
  String? _feedback;
  bool _lastCorrect = true;
  int? _awarded;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final pool = List.of(ContentSeed.sortItems)..shuffle(math.Random());
    setState(() {
      _items = pool.take(8).toList();
      _sorted.clear();
      _selected = null;
      _mistakes = 0;
      _feedback = null;
      _awarded = null;
      _round++;
    });
  }

  Future<void> _drop(SortItem item, BinColor bin) async {
    final style = _bins[bin]!;
    if (item.bin == bin) {
      HapticFeedback.selectionClick();
      setState(() {
        _sorted.add(item);
        _selected = null;
        _lastCorrect = true;
        _feedback = '${item.name} goes in the ${style.label.toLowerCase()} bin. ${item.why}';
      });
      context.announce(_feedback!);
      if (_sorted.length == _items.length) await _complete();
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _mistakes++;
        _lastCorrect = false;
        _feedback = 'Not the ${style.label.toLowerCase()} bin. Think about what ${item.name.toLowerCase()} is made of.';
      });
      context.announce(_feedback!);
    }
  }

  Future<void> _complete() async {
    final s = context.services;
    final u = s.auth.user;
    var pts = 0;
    if (u != null) {
      try {
        pts = await s.store.completeSortGame(u.id);
      } on ActionRefused catch (e) {
        if (mounted) context.toast(e.message, error: true);
      }
    }
    if (!mounted) return;
    setState(() {
      _awarded = pts;
      _burst++;
    });
    context.announce('All sorted with $_mistakes ${_mistakes == 1 ? 'mistake' : 'mistakes'}.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = _items.where((i) => !_sorted.contains(i)).toList();
    final finished = remaining.isEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: const Text('Sorting challenge'),
      ),
      body: DropletBurst(
        trigger: _burst,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  finished
                      ? 'All sorted!'
                      : 'Drag each item into the right bin, or tap an item and then tap a bin.',
                  style: finished ? text.headlineSmall : text.bodyLarge,
                ),
                const SizedBox(height: 6),
                Text('Sorted ${_sorted.length} of ${_items.length} · mistakes: $_mistakes', style: text.bodySmall),
                const SizedBox(height: 16),
                if (!finished)
                  Wrap(
                    key: ValueKey(_round),
                    spacing: 10,
                    runSpacing: 10,
                    children: [for (final item in remaining) _itemChip(item)],
                  )
                else
                  _doneCard(context),
                if (_feedback != null) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: InfoNote(_feedback!, tone: _lastCorrect ? Tone.success : Tone.warning),
                  ),
                ],
                const SizedBox(height: 20),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 640 ? 4 : 2;
                  final w = (c.maxWidth - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final b in BinColor.values) SizedBox(width: w, child: _binTarget(b)),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemChip(SortItem item) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected == item;
    void toggle() {
      setState(() => _selected = selected ? null : item);
      if (!selected) context.announce('${item.name} selected. Now choose a bin.');
    }

    final chip = Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(item.name, style: Theme.of(context).textTheme.labelLarge),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
      hint: selected ? 'Selected. Choose a bin below.' : 'Select, then choose a bin',
      onTap: toggle, // the chip's InkWell is excluded below
      child: ExcludeSemantics(
        child: Draggable<SortItem>(
          data: item,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: ShapeDecoration(color: scheme.primary, shape: const StadiumBorder()),
              child: Text(item.name, style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700)),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: chip),
          child: chip,
        ),
      ),
    );
  }

  Widget _binTarget(BinColor bin) {
    final st = _bins[bin]!;
    final text = Theme.of(context).textTheme;
    final sel = _selected;
    return DragTarget<SortItem>(
      onAcceptWithDetails: (d) => _drop(d.data, bin),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Semantics(
          button: true,
          label: '${st.label} bin: ${st.meaning}',
          hint: sel == null ? 'Select an item first' : 'Put ${sel.name} here',
          // The InkWell below is inside ExcludeSemantics, so the tap must be
          // exposed here for TalkBack / VoiceOver users (the drag-free path).
          onTap: sel == null ? null : () => _drop(sel, bin),
          child: ExcludeSemantics(
            child: AnimatedScale(
              scale: hovering ? 1.04 : 1,
              duration: context.motion(AqMotion.fast),
              child: Material(
                color: st.color,
                borderRadius: BorderRadius.circular(AqRadius.card),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AqRadius.card),
                  onTap: sel == null ? null : () => _drop(sel, bin),
                  child: Container(
                    // A minimum, not a fixed height, so large text never overflows.
                    constraints: const BoxConstraints(minHeight: 120),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AqRadius.card),
                      border: Border.all(color: hovering ? Colors.white : Colors.transparent, width: 3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(st.icon, color: st.onColor, size: 28),
                        const SizedBox(height: 18),
                        Text('${st.label} bin', style: text.titleMedium?.copyWith(color: st.onColor)),
                        Text(st.meaning, style: text.bodySmall?.copyWith(color: st.onColor)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _doneCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _mistakes == 0 ? 'Perfect sorting — not a single mistake.' : 'Sorted with $_mistakes ${_mistakes == 1 ? 'mistake' : 'mistakes'}.',
            style: text.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            (_awarded ?? 0) > 0
                ? '+$_awarded points added to your reservoir.'
                : 'You already earned the ${PointRules.sortGame} points for this challenge — play again for practice.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(onPressed: _newRound, icon: const Icon(Icons.replay), label: const Text('Play again')),
              OutlinedButton(onPressed: () => context.pop(), child: const Text('Done')),
            ],
          ),
        ],
      ),
    );
  }
}
