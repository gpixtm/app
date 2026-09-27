import 'localization.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/trail_geometry.dart';
import 'design.dart';

class ElevationChart extends StatefulWidget {
  const ElevationChart({
    required this.geometry,
    this.projection,
    this.reverse = false,
    this.estimated = false,
    super.key,
  });
  final TrailGeometry geometry;
  final Projection? projection;
  final bool reverse, estimated;
  @override
  State<ElevationChart> createState() => _ElevationChartState();
}

class _ElevationChartState extends State<ElevationChart> {
  bool full = false;
  double offset = 0, scale = 1;
  @override
  Widget build(BuildContext context) {
    final g = widget.geometry;
    final position = widget.projection == null
        ? null
        : widget.reverse
        ? g.total - widget.projection!.along
        : widget.projection!.along;
    final width = full ? g.total : math.min(g.total, 5000.0 / scale);
    final start = full
        ? 0.0
        : ((position ?? 0.0) - width / 2 + offset)
              .clamp(0.0, math.max(0.0, g.total - width))
              .toDouble();
    final points = g.orientedProfile(widget.reverse);
    final available = points.where((p) => p.elevation != null).length > 1;
    final partial = points.any((p) => p.elevation == null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.landscape_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.altitudeTitle(
                  widget.estimated ? context.l10n.estimatedSuffix : '',
                  partial ? context.l10n.partialSuffix : '',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                full = !full;
                offset = 0;
              }),
              child: Text(full ? context.l10n.nearMe : context.l10n.wholeTrail),
            ),
          ],
        ),
        if (!available)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Text(context.l10n.profileUnavailable),
          )
        else
          GestureDetector(
            onScaleUpdate: (d) => setState(() {
              if (!full) {
                offset -= d.focalPointDelta.dx * width / 300;
                scale = (scale * (1 + (d.scale - 1) * .04)).clamp(.25, 8);
              }
            }),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: CustomPaint(
                painter: _ProfilePainter(
                  points,
                  start,
                  math.max(1.0, width),
                  position,
                ),
              ),
            ),
          ),
        if (available)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(kilometers(start)),
              Text(
                context.l10n.distanceAlongTrail,
                style: TextStyle(fontSize: 10),
              ),
              Text(kilometers(start + width)),
            ],
          ),
      ],
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter(this.points, this.start, this.span, this.position);
  final List<ProfilePoint> points;
  final double start, span;
  final double? position;
  @override
  void paint(Canvas canvas, Size size) {
    final elevations = points
        .where(
          (p) =>
              p.elevation != null &&
              p.distance >= start &&
              p.distance <= start + span,
        )
        .map((p) => p.elevation!)
        .toList();
    if (elevations.isEmpty) return;
    final low = elevations.reduce(math.min) - 10,
        high = elevations.reduce(math.max) + 10;
    Offset xy(ProfilePoint p) => Offset(
      (p.distance - start) / span * size.width,
      size.height -
          14 -
          (p.elevation! - low) / (high - low) * (size.height - 30),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 0; y < 3; y++) {
      final dy = 15 + y * (size.height - 25) / 2;
      canvas.drawLine(
        Offset(0, dy),
        Offset(size.width, dy),
        Paint()..color = const Color(0xffe8eae3),
      );
    }
    ProfilePoint? previous;
    final line = Paint()
      ..color = forest
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (final p in points) {
      if (previous != null &&
          p.elevation != null &&
          previous.elevation != null &&
          previous.segment == p.segment) {
        final a = xy(previous), b = xy(p);
        final area = Path()
          ..moveTo(a.dx, size.height)
          ..lineTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(b.dx, size.height)
          ..close();
        canvas.drawPath(area, Paint()..color = forest.withValues(alpha: .10));
        canvas.drawLine(a, b, line);
      }
      previous = p;
    }
    if (position != null) {
      final x = (position! - start) / span * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = const Color(0xffdd7337)
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
    final text = TextPainter(
      text: TextSpan(
        text: '${high.round()} m',
        style: const TextStyle(color: forest, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, const Offset(4, 0));
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter oldDelegate) => true;
}
