import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/trail_geometry.dart';
import 'design.dart';

const _grid = Color(0xffdfe5dc), _muted = Color(0xff5d6b64);

TextPainter _label(String text, {Color color = _muted}) => TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(fontSize: 10, color: color),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// The trend of one series, without axes: the latest value is marked.
class Sparkline extends CustomPainter {
  Sparkline(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final span = math.max(high - low, .1);
    Offset at(int i) => Offset(
      3 + (size.width - 6) * i / (values.length - 1),
      size.height - 3 - (size.height - 6) * (values[i] - low) / span,
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = forest
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(values.length - 1), 3, Paint()..color = forest);
  }

  @override
  bool shouldRepaint(Sparkline old) => old.values != values;
}

/// Seconds walk A leads walk B at each distance along their common stretch,
/// above the zero line when A is ahead. The route's altitude is a faint
/// backdrop, so gains and losses read against climbs. Touching the chart
/// moves a cursor that [onCursor] reports.
class GapChart extends StatefulWidget {
  const GapChart({
    required this.gap,
    required this.aheadColor,
    required this.behindColor,
    required this.minutes,
    required this.distance,
    required this.onCursor,
    this.profile = const [],
    super.key,
  });
  final List<(double, double)> gap;
  final List<ProfilePoint> profile;
  final Color aheadColor, behindColor;

  /// Axis labels: signed minutes, and a distance.
  final String Function(int) minutes;
  final String Function(double) distance;
  final ValueChanged<int> onCursor;
  @override
  State<GapChart> createState() => _GapChartState();
}

class _GapChartState extends State<GapChart> {
  int? cursor;
  void _move(Offset local, double width) {
    final g = widget.gap;
    final start = g.first.$1, end = g.last.$1;
    final d =
        start + (end - start) * ((local.dx - 36) / (width - 44)).clamp(0, 1);
    var best = 0;
    for (var i = 1; i < g.length; i++) {
      if ((g[i].$1 - d).abs() < (g[best].$1 - d).abs()) best = i;
    }
    if (best != cursor) {
      setState(() => cursor = best);
      widget.onCursor(best);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) => GestureDetector(
      onPanDown: (d) => _move(d.localPosition, box.maxWidth),
      onPanUpdate: (d) => _move(d.localPosition, box.maxWidth),
      child: CustomPaint(
        size: Size(box.maxWidth, 190),
        painter: _GapPainter(widget, cursor),
      ),
    ),
  );
}

class _GapPainter extends CustomPainter {
  _GapPainter(this.chart, this.cursor);
  final GapChart chart;
  final int? cursor;
  @override
  void paint(Canvas canvas, Size size) {
    final g = chart.gap;
    const left = 36.0, right = 8.0, top = 8.0, bottom = 20.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final start = g.first.$1, end = g.last.$1;
    // The scale follows the data on each side of zero, at least two minutes
    // tall, so a lead kept all along does not leave half the chart empty.
    var up = math.max(0.0, g.map((p) => p.$2).reduce(math.max)) * 1.15;
    var down = math.max(0.0, -g.map((p) => p.$2).reduce(math.min)) * 1.15;
    if (up + down < 120) {
      final missing = (120 - up - down) / 2;
      up += missing;
      down += missing;
    }
    double x(double d) => plot.left + plot.width * (d - start) / (end - start);
    double y(double s) => plot.top + plot.height * (up - s) / (up + down);

    // Altitude backdrop over the same stretch.
    final relief = chart.profile
        .where(
          (p) =>
              p.elevation != null && p.distance >= start && p.distance <= end,
        )
        .toList();
    if (relief.length > 1) {
      final low = relief.map((p) => p.elevation!).reduce(math.min);
      final high = relief.map((p) => p.elevation!).reduce(math.max);
      final span = math.max(high - low, 20);
      final path = Path()..moveTo(x(relief.first.distance), plot.bottom);
      for (final p in relief) {
        path.lineTo(
          x(p.distance),
          plot.bottom - plot.height * .8 * (p.elevation! - low) / span,
        );
      }
      path
        ..lineTo(x(relief.last.distance), plot.bottom)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xffeef1ea));
    }

    // Grid: zero and about four steps in whole minutes.
    final step = math.max(1, ((up + down) / 60 / 4).round()) * 60.0;
    for (var s = -(down / step).floor() * step; s <= up; s += step) {
      final line = Paint()
        ..color = s == 0 ? ink : _grid
        ..strokeWidth = s == 0 ? 1 : .8;
      canvas.drawLine(Offset(plot.left, y(s)), Offset(plot.right, y(s)), line);
      final label = _label(chart.minutes((s / 60).round()));
      label.paint(
        canvas,
        Offset(plot.left - label.width - 4, y(s) - label.height / 2),
      );
    }
    for (final d in [start, (start + end) / 2, end]) {
      final label = _label(chart.distance(d));
      label.paint(
        canvas,
        Offset(
          (x(d) - label.width / 2).clamp(0, size.width - label.width),
          plot.bottom + 4,
        ),
      );
    }

    // Area on each side of zero in the colour of the walk that leads.
    final line = Path()..moveTo(x(g.first.$1), y(g.first.$2));
    for (final p in g.skip(1)) {
      line.lineTo(x(p.$1), y(p.$2));
    }
    final area = Path.from(line)
      ..lineTo(x(g.last.$1), y(0))
      ..lineTo(x(g.first.$1), y(0))
      ..close();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plot.left, 0, plot.right, y(0)));
    canvas.drawPath(
      area,
      Paint()..color = chart.aheadColor.withValues(alpha: .28),
    );
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plot.left, y(0), plot.right, size.height));
    canvas.drawPath(
      area,
      Paint()..color = chart.behindColor.withValues(alpha: .28),
    );
    canvas.restore();
    canvas.drawPath(
      line,
      Paint()
        ..color = ink
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    final i = cursor ?? g.length - 1;
    final at = Offset(x(g[i].$1), y(g[i].$2));
    canvas.drawLine(
      Offset(at.dx, plot.top),
      Offset(at.dx, plot.bottom),
      Paint()
        ..color = _muted
        ..strokeWidth = 1,
    );
    canvas.drawCircle(at, 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      at,
      4.5,
      Paint()..color = g[i].$2 >= 0 ? chart.aheadColor : chart.behindColor,
    );
  }

  @override
  bool shouldRepaint(_GapPainter old) =>
      old.chart != chart || old.cursor != cursor;
}

/// Average speed of each complete walk over time, with the usual speed as a
/// dashed reference. Touching a walk selects it.
class SpeedChart extends StatelessWidget {
  const SpeedChart({
    required this.walks,
    required this.selected,
    required this.onSelect,
    required this.speed,
    this.usual,
    super.key,
  });

  /// Oldest first.
  final List<(DateTime, double)> walks;
  final int? selected;
  final ValueChanged<int> onSelect;
  final double? usual;
  final String Function(double) speed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final painter = _SpeedPainter(this);
      return GestureDetector(
        onTapDown: (d) {
          final points = painter.points(Size(box.maxWidth, 170));
          var best = 0;
          for (var i = 1; i < points.length; i++) {
            if ((points[i].dx - d.localPosition.dx).abs() <
                (points[best].dx - d.localPosition.dx).abs()) {
              best = i;
            }
          }
          onSelect(best);
        },
        child: CustomPaint(size: Size(box.maxWidth, 170), painter: painter),
      );
    },
  );
}

class _SpeedPainter extends CustomPainter {
  _SpeedPainter(this.chart);
  final SpeedChart chart;
  static const _left = 44.0, _right = 10.0, _top = 10.0, _bottom = 10.0;

  (double, double) get _range {
    final values = [
      ...chart.walks.map((w) => w.$2),
      if (chart.usual != null) chart.usual!,
    ];
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final pad = math.max(.2, (high - low) * .15);
    return (low - pad, high + pad);
  }

  double _y(double kmh, Size size) {
    final (low, high) = _range;
    return _top + (size.height - _top - _bottom) * (high - kmh) / (high - low);
  }

  /// Walks spaced by date, so a long break between walks shows.
  List<Offset> points(Size size) {
    final first = chart.walks.first.$1.millisecondsSinceEpoch;
    final span = math.max(
      1,
      chart.walks.last.$1.millisecondsSinceEpoch - first,
    );
    return [
      for (final (date, kmh) in chart.walks)
        Offset(
          _left +
              (size.width - _left - _right) *
                  (date.millisecondsSinceEpoch - first) /
                  span,
          _y(kmh, size),
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (low, high) = _range;
    for (final v in [
      low + (high - low) * .1,
      (low + high) / 2,
      high - (high - low) * .1,
    ]) {
      final y = _y(v, size);
      canvas.drawLine(
        Offset(_left, y),
        Offset(size.width - _right, y),
        Paint()
          ..color = _grid
          ..strokeWidth = .8,
      );
      final label = _label(chart.speed(v));
      label.paint(
        canvas,
        Offset(_left - label.width - 4, y - label.height / 2),
      );
    }
    if (chart.usual case final usual?) {
      final y = _y(usual, size);
      for (var x = _left; x < size.width - _right; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width - _right), y),
          Paint()
            ..color = _muted
            ..strokeWidth = 1.2,
        );
      }
    }
    final p = points(size);
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (final o in p.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = forest
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < p.length; i++) {
      final chosen = i == chart.selected;
      canvas.drawCircle(p[i], chosen ? 7 : 5, Paint()..color = Colors.white);
      canvas.drawCircle(p[i], chosen ? 5.5 : 4, Paint()..color = forest);
    }
  }

  @override
  bool shouldRepaint(_SpeedPainter old) =>
      old.chart.walks != chart.walks ||
      old.chart.selected != chart.selected ||
      old.chart.usual != chart.usual;
}
