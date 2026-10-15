// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../services/app_services.dart';

/// Shared wave clock: a looping controller that stops whenever motion should
/// be reduced (system setting, in-app setting, or low battery — Q2).
mixin WaveClock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController wave = AnimationController(vsync: this, duration: AqMotion.wavePeriod);
  AppServices? _services;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      _services!.settings.addListener(_sync);
      _services!.device.addListener(_sync);
    }
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    if (context.reduceMotion) {
      if (wave.isAnimating) wave.stop();
    } else if (!wave.isAnimating) {
      wave.repeat();
    }
  }

  @override
  void dispose() {
    _services?.settings.removeListener(_sync);
    _services?.device.removeListener(_sync);
    wave.dispose();
    super.dispose();
  }
}

/// The signature element: a reservoir whose water rises with progress.
///
/// It inverts the Day Zero story from module A — instead of watching a
/// reservoir drain, students fill theirs with every action. Tide marks on
/// the right edge show the level thresholds.
class Reservoir extends StatefulWidget {
  const Reservoir({
    super.key,
    required this.level,
    required this.semanticLabel,
    this.height = 232,
    this.marks = const [],
    this.child,
  });

  /// 0 – 1.
  final double level;
  final String semanticLabel;
  final double height;
  final List<double> marks;
  final Widget? child;

  @override
  State<Reservoir> createState() => _ReservoirState();
}

class _ReservoirState extends State<Reservoir> with SingleTickerProviderStateMixin, WaveClock {
  @override
  Widget build(BuildContext context) {
    final target = widget.level.clamp(0.0, 1.0);
    // Grow with the reader's text size so large text never overflows the tank.
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AqRadius.hero),
        child: SizedBox(
          height: widget.height * textScale,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B2230), Color(0xFF123A4B)],
                  ),
                ),
              ),
              ExcludeSemantics(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: target),
                  duration: context.motion(const Duration(milliseconds: 1400)),
                  curve: Curves.easeOutCubic,
                  builder: (context, level, _) => AnimatedBuilder(
                    animation: wave,
                    builder: (context, _) => CustomPaint(
                      painter: WaterPainter(
                        phase: wave.value,
                        level: 0.08 + level * 0.8,
                        marks: [for (final m in widget.marks) 0.08 + m * 0.8],
                        back: const Color(0xFF1B6A86),
                        front: AqColors.tide,
                        deep: AqColors.tideDeep,
                        mark: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.child != null)
                Padding(padding: const EdgeInsets.fromLTRB(22, 20, 34, 20), child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints two phase-shifted sine waves filled to [level] (0 bottom – 1 top).
class WaterPainter extends CustomPainter {
  WaterPainter({
    required this.phase,
    required this.level,
    required this.back,
    required this.front,
    required this.deep,
    this.mark = Colors.transparent,
    this.marks = const [],
    this.amplitude,
  });

  final double phase;
  final double level;
  final Color back;
  final Color front;
  final Color deep;
  final Color mark;
  final List<double> marks;
  final double? amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    if (marks.isNotEmpty) {
      final p = Paint()
        ..color = mark
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (final m in marks) {
        final y = h * (1 - m.clamp(0.0, 1.0));
        canvas.drawLine(Offset(w - 20, y), Offset(w - 8, y), p);
      }
    }

    final top = h * (1 - level.clamp(0.0, 1.0));
    final amp = amplitude ?? math.min(10.0, h * 0.045);
    final t = phase * 2 * math.pi;

    Path wavePath(double a, double shift, double cycles) {
      final path = Path()..moveTo(0, h);
      for (double x = 0; x <= w + 3; x += 3) {
        path.lineTo(x, top + math.sin(x / w * 2 * math.pi * cycles + t + shift) * a);
      }
      return path
        ..lineTo(w, h)
        ..close();
    }

    canvas.drawPath(wavePath(amp * 0.75, math.pi * 0.65, 1.4), Paint()..color = back);
    final rect = Rect.fromLTWH(0, top - amp, w, h - top + amp);
    canvas.drawPath(
      wavePath(amp, 0, 1.0),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [front, deep],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(WaterPainter old) =>
      old.phase != phase || old.level != level || old.front != front || old.back != back || old.deep != deep;
}

/// A band of waves along the bottom edge of a header — the "horizon" where
/// the sea meets the page on the login screen and role headers.
class WaveHorizon extends StatefulWidget {
  const WaveHorizon({super.key, required this.color, this.height = 36, this.backColor});
  final Color color;
  final Color? backColor;
  final double height;

  @override
  State<WaveHorizon> createState() => _WaveHorizonState();
}

class _WaveHorizonState extends State<WaveHorizon> with SingleTickerProviderStateMixin, WaveClock {
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: wave,
          builder: (context, _) => CustomPaint(
            painter: WaterPainter(
              phase: wave.value,
              level: 0.55,
              amplitude: widget.height * 0.22,
              back: widget.backColor ?? widget.color.withValues(alpha: 0.45),
              front: widget.color,
              deep: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
