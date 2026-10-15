// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../data/models/models.dart';
import 'reservoir.dart';

/// Icon keys used by [SlideArt] in the content seed.
const Map<String, IconData> kSlideIcons = {
  'drop': Icons.water_drop_outlined,
  'tap': Icons.plumbing,
  'people': Icons.groups_outlined,
  'groundwater': Icons.water,
  'heat': Icons.wb_sunny_outlined,
  'factory': Icons.factory_outlined,
  'recycle': Icons.recycling,
  'paper': Icons.newspaper,
  'cycle': Icons.autorenew,
  'bottle': Icons.local_drink_outlined,
  'shirt': Icons.checkroom,
  'globe': Icons.public,
  'coins': Icons.savings_outlined,
  'device': Icons.devices_other_outlined,
  'glass': Icons.wine_bar_outlined,
  'truck': Icons.local_shipping_outlined,
  'rain': Icons.thunderstorm_outlined,
  'sprout': Icons.eco_outlined,
  'bag': Icons.shopping_bag_outlined,
};

IconData slideIcon(String key) => kSlideIcons[key] ?? Icons.water_drop_outlined;

/// Draws a lesson slide's illustration: deep water with a still wave line,
/// and either a headline number, a row of topic icons or the four bins.
///
/// Decorative by design — hidden from screen readers because the slide's
/// title and text say everything the picture does. Sizes are derived from
/// the available height and ignore the text-size setting (the real text
/// below the picture still scales), so it never overflows.
class SlideArtView extends StatelessWidget {
  const SlideArtView({super.key, required this.art, this.variant = 0});
  final SlideArt art;

  /// Shifts the wave so neighbouring slides don't look identical.
  final int variant;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AqRadius.sheet),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: LayoutBuilder(builder: (context, c) {
              final h = c.maxHeight;
              final w = c.maxWidth;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0B2230), AqColors.tideDeep],
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: WaterPainter(
                      phase: (variant * 0.17) % 1,
                      level: 0.2,
                      amplitude: h * 0.035,
                      back: const Color(0xFF1B6A86),
                      front: AqColors.tide,
                      deep: AqColors.tideDeep,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(h * 0.1, h * 0.1, h * 0.1, h * 0.26),
                    child: switch (art.kind) {
                      SlideArtKind.stat => _Stat(art: art, h: h),
                      SlideArtKind.icons => _IconRow(keys: art.icons, h: h, w: w - h * 0.2),
                      SlideArtKind.bins => _Bins(h: h, w: w - h * 0.2),
                    },
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.size});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: AqColors.shallows.withValues(alpha: 0.55), width: math.max(1.5, size * 0.03)),
      ),
      child: Icon(icon, color: AqColors.shallows, size: size * 0.52),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.art, required this.h});
  final SlideArt art;
  final double h;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(icon: slideIcon(art.icon), size: h * 0.15),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            art.stat ?? '',
            style: TextStyle(
              fontSize: h * 0.22,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -h * 0.006,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: h * 0.025),
        Text(
          art.caption ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: math.max(12, h * 0.064),
            height: 1.25,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({required this.keys, required this.h, required this.w});
  final List<String> keys;
  final double h;
  final double w;

  @override
  Widget build(BuildContext context) {
    final n = math.max(1, keys.length);
    final gap = h * 0.05;
    final size = math.min(h * 0.34, (w - gap * (n - 1)) / n);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            _Badge(icon: slideIcon(keys[i]), size: size),
          ],
        ],
      ),
    );
  }
}

/// The four segregation bins: wet, dry, hazardous and medical.
class _Bins extends StatelessWidget {
  const _Bins({required this.h, required this.w});
  final double h;
  final double w;

  static const _bins = <(Color, String)>[
    (Color(0xFF2E7D32), 'Wet'),
    (Color(0xFF1565C0), 'Dry'),
    (Color(0xFFC62828), 'Hazardous'),
    (Color(0xFFF9C433), 'Medical'),
  ];

  @override
  Widget build(BuildContext context) {
    final gap = w * 0.04;
    // Each column is 1.3 bins wide (the label), so size from that.
    final binW = math.min(h * 0.32, (w - gap * 3) / (4 * 1.3));
    final binH = binW * 1.15;
    final label = TextStyle(
      fontSize: math.max(11, binW * 0.17),
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.92),
    );
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _bins.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lid
                Container(
                  width: binW * 1.08,
                  height: binW * 0.12,
                  decoration: BoxDecoration(
                    color: Color.lerp(_bins[i].$1, Colors.black, 0.25),
                    borderRadius: BorderRadius.circular(binW * 0.05),
                  ),
                ),
                SizedBox(height: binW * 0.03),
                // Body, slightly tapered with a recycling mark.
                Container(
                  width: binW,
                  height: binH,
                  decoration: BoxDecoration(
                    color: _bins[i].$1,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(binW * 0.04),
                      bottom: Radius.circular(binW * 0.14),
                    ),
                  ),
                  child: Icon(
                    i == 0 ? Icons.eco_outlined : i == 1 ? Icons.recycling : i == 2 ? Icons.warning_amber_rounded : Icons.medical_services_outlined,
                    color: i == 3 ? const Color(0xFF2B1D00) : Colors.white.withValues(alpha: 0.9),
                    size: binW * 0.42,
                  ),
                ),
                SizedBox(height: binW * 0.1),
                SizedBox(
                  width: binW * 1.3,
                  child: Text(_bins[i].$2, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: label),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
