import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'design.dart';

/// Map style images of single trail pins, drawn by the map itself like the
/// clusters around them, so panning never rebuilds Flutter widgets.
const ownPinImage = 'pin-own';
const cataloguePinImage = 'pin-catalogue';

/// Logical side of a pin image; the round pin is centred on the trail anchor.
const trailPinSide = 36.0;

/// PNG of a pin at [pixelRatio] physical pixels per logical pixel: a round
/// badge in the trail kind's colour, rimmed in white, with its icon.
Future<Uint8List> trailPinPng(
  double pixelRatio, {
  required bool catalogue,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  const centre = Offset(trailPinSide / 2, trailPinSide / 2);
  canvas.drawCircle(
    centre.translate(0, 1.5),
    15,
    Paint()
      ..color = const Color(0x42000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  canvas.drawCircle(centre, 15, Paint()..color = Colors.white);
  canvas.drawCircle(
    centre,
    12.5,
    Paint()..color = catalogue ? catalogueColor : forest,
  );
  final icon = catalogue ? Icons.travel_explore : Icons.hiking;
  final text = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: 16,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));
  final side = (trailPinSide * pixelRatio).round();
  final image = await recorder.endRecording().toImage(side, side);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
