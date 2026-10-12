import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_services.dart';

class ChartDatum {
  const ChartDatum(this.label, this.value, {this.longLabel});
  final String label;

  /// Null means "no data yet" and is drawn as an empty slot, not a zero.
  final double? value;
  final String? longLabel;
}

/// Bar or line chart with a spoken summary and a "Show as table" toggle —
/// a chart is never the only way to read the numbers.
class AqChart extends StatefulWidget {
  const AqChart({
    super.key,
    required this.data,
    required this.summary,
    this.line = false,
    this.maxValue,
    this.unit = '',
    this.height = 200,
    this.highlightBelow,
  });

  final List<ChartDatum> data;
  final String summary;
  final bool line;
  final double? maxValue;
  final String unit;
  final double height;

  /// Bars below this value use the warning colour (e.g. weak modules).
  final double? highlightBelow;

  @override
  State<AqChart> createState() => _AqChartState();
}

class _AqChartState extends State<AqChart> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final values = widget.data.map((d) => d.value ?? 0).toList();
    final maxV = widget.maxValue ?? math.max(1.0, values.fold<double>(0, math.max) * 1.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_table)
          _DataTableView(data: widget.data, unit: widget.unit)
        else
          Semantics(
            label: widget.summary,
            image: true,
            child: ExcludeSemantics(
              child: SizedBox(
                height: widget.height,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: context.motion(const Duration(milliseconds: 900)),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => CustomPaint(
                    painter: _ChartPainter(
                      data: widget.data,
                      max: maxV,
                      progress: t,
                      line: widget.line,
                      bar: scheme.primary,
                      warn: scheme.secondary,
                      empty: scheme.outlineVariant,
                      grid: scheme.outlineVariant.withValues(alpha: 0.6),
                      label: text.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
                      valueStyle: text.labelMedium!.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700),
                      unit: widget.unit,
                      highlightBelow: widget.highlightBelow,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _table = !_table),
            icon: Icon(_table ? Icons.bar_chart_rounded : Icons.table_rows_outlined),
            label: Text(_table ? 'Show as chart' : 'Show as table'),
          ),
        ),
      ],
    );
  }
}

class _DataTableView extends StatelessWidget {
  const _DataTableView({required this.data, required this.unit});
  final List<ChartDatum> data;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final d in data)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(d.longLabel ?? d.label, style: text.bodyMedium)),
                Text(
                  d.value == null ? 'No data yet' : '${d.value!.round()}$unit',
                  style: text.titleSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.data,
    required this.max,
    required this.progress,
    required this.line,
    required this.bar,
    required this.warn,
    required this.empty,
    required this.grid,
    required this.label,
    required this.valueStyle,
    required this.unit,
    this.highlightBelow,
  });

  final List<ChartDatum> data;
  final double max;
  final double progress;
  final bool line;
  final Color bar;
  final Color warn;
  final Color empty;
  final Color grid;
  final TextStyle label;
  final TextStyle valueStyle;
  final String unit;
  final double? highlightBelow;

  TextPainter _tp(String s, TextStyle style) =>
      TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const bottomPad = 24.0;
    const topPad = 22.0;
    final chartH = size.height - bottomPad - topPad;
    final slot = size.width / data.length;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topPad + chartH * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      final cx = slot * i + slot / 2;
      final lp = _tp(d.label, label);
      lp.paint(canvas, Offset(cx - lp.width / 2, size.height - bottomPad + 6));

      final v = d.value;
      if (v == null) {
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - math.min(14.0, slot * 0.3), topPad + chartH - 4, math.min(28.0, slot * 0.6), 4),
          const Radius.circular(2),
        );
        canvas.drawRRect(r, Paint()..color = empty);
        continue;
      }
      final hgt = chartH * (v / max).clamp(0.0, 1.0) * progress;
      final top = topPad + chartH - hgt;
      if (line) {
        points.add(Offset(cx, top));
      } else {
        final w = math.min(30.0, slot * 0.56);
        final isWarn = highlightBelow != null && v < highlightBelow!;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - w / 2, top, w, hgt),
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
          ),
          Paint()..color = isWarn ? warn : bar,
        );
      }
      if (progress > 0.95) {
        final vp = _tp('${v.round()}$unit', valueStyle);
        vp.paint(canvas, Offset(cx - vp.width / 2, top - vp.height - 3));
      }
    }

    if (line && points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1];
        final b = points[i];
        final mx = (a.dx + b.dx) / 2;
        path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
      }
      final fill = Path.from(path)
        ..lineTo(points.last.dx, topPad + chartH)
        ..lineTo(points.first.dx, topPad + chartH)
        ..close();
      canvas.drawPath(fill, Paint()..color = bar.withValues(alpha: 0.12));
      canvas.drawPath(
        path,
        Paint()
          ..color = bar
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      for (final p in points) {
        canvas.drawCircle(p, 5, Paint()..color = bar);
        canvas.drawCircle(p, 2.5, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.progress != progress || old.data != data || old.bar != bar;
}
