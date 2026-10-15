// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../core/utils/format.dart';
import '../services/app_services.dart';

/// Fades and lifts its child into place once. Used for the single orchestrated
/// entrance on the login and home screens — not on every list item.
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.child, this.delay = Duration.zero, this.offset = 18});
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AqMotion.slow);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: AqMotion.emphasized);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) {
      _c.value = 1;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.offset), child: child),
      ),
    );
  }
}

/// Counts up to [value]. Screen readers hear only the final number.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, this.style, this.suffix = ''});
  final int value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${Fmt.number(value)}$suffix',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: context.motion(const Duration(milliseconds: 900)),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text('${Fmt.number(v.round())}$suffix', style: style),
        ),
      ),
    );
  }
}

/// A burst of water droplets — the reward moment for finishing a quiz,
/// redeeming a reward or completing a task. Increment [trigger] to play.
class DropletBurst extends StatefulWidget {
  const DropletBurst({super.key, required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  State<DropletBurst> createState() => _DropletBurstState();
}

class _DropletBurstState extends State<DropletBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  final List<_Drop> _drops = [];

  @override
  void didUpdateWidget(DropletBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) _play();
  }

  @override
  void initState() {
    super.initState();
    if (widget.trigger > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    if (!mounted || context.reduceMotion) return;
    final rnd = math.Random(widget.trigger * 7919);
    const palette = [AqColors.tide, AqColors.shallows, AqColors.ochre, AqColors.mangrove];
    _drops
      ..clear()
      ..addAll(List.generate(34, (i) {
        final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.5;
        return _Drop(
          angle: angle,
          speed: 220 + rnd.nextDouble() * 260,
          size: 5 + rnd.nextDouble() * 7,
          color: palette[i % palette.length],
          spin: (rnd.nextDouble() - 0.5) * 4,
        );
      }));
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => _c.isAnimating
                    ? CustomPaint(painter: _BurstPainter(_drops, _c.value))
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Drop {
  const _Drop({required this.angle, required this.speed, required this.size, required this.color, required this.spin});
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.drops, this.t);
  final List<_Drop> drops;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.45);
    final secs = t * 1.3;
    for (final d in drops) {
      final dx = math.cos(d.angle) * d.speed * secs;
      final dy = math.sin(d.angle) * d.speed * secs + 420 * secs * secs; // gravity
      final p = origin + Offset(dx, dy);
      final fade = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()..color = d.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(d.spin * t + math.atan2(dy, dx) + math.pi / 2);
      // Teardrop: a circle with a pointed top.
      final r = d.size;
      final path = Path()
        ..moveTo(0, -r * 1.8)
        ..quadraticBezierTo(r * 1.1, -r * 0.2, 0, r)
        ..quadraticBezierTo(-r * 1.1, -r * 0.2, 0, -r * 1.8)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
