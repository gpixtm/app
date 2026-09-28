import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Map style image name of the walker's direction arrow.
const positionArrowImage = 'position-arrow';

/// Logical side of the square arrow image; the arrow sits at its centre so the
/// map anchors it exactly on the GPS position.
const positionArrowSide = 64.0;

const _blue = Color(0xff2563eb);

/// Paints the direction arrow pointing up, centred on [centre]: a soft beam
/// showing where the walker faces, then a compact white-rimmed navigation
/// chevron whose visual centre is the position itself.
void paintPositionArrow(Canvas canvas, Offset centre) {
  const beamRadius = 30.0, beamHalfAngle = 32 * math.pi / 180;
  final beam = Path()
    ..moveTo(centre.dx, centre.dy)
    ..arcTo(
      Rect.fromCircle(center: centre, radius: beamRadius),
      -math.pi / 2 - beamHalfAngle,
      beamHalfAngle * 2,
      false,
    )
    ..close();
  canvas.drawPath(
    beam,
    Paint()
      ..shader = ui.Gradient.radial(centre, beamRadius, [
        _blue.withValues(alpha: .42),
        _blue.withValues(alpha: 0),
      ]),
  );

  final arrow = Path()
    ..moveTo(centre.dx, centre.dy - 12)
    ..lineTo(centre.dx + 9.5, centre.dy + 10)
    ..lineTo(centre.dx, centre.dy + 5)
    ..lineTo(centre.dx - 9.5, centre.dy + 10)
    ..close();
  canvas.drawShadow(arrow, const Color(0xff000000), 2.5, false);
  canvas.drawPath(
    arrow,
    Paint()
      ..color = const Color(0xffffffff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(arrow, Paint()..color = _blue);
}

/// PNG of the arrow at [pixelRatio] physical pixels per logical pixel, so the
/// map shows it at [positionArrowSide] logical pixels on every screen.
Future<Uint8List> positionArrowPng(double pixelRatio) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  paintPositionArrow(
    canvas,
    const Offset(positionArrowSide / 2, positionArrowSide / 2),
  );
  final side = (positionArrowSide * pixelRatio).round();
  final image = await recorder.endRecording().toImage(side, side);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
