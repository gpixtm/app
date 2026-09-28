import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'design.dart';

/// Map style images of single trail pins, drawn by the map itself like the
/// clusters around them, so panning never rebuilds Flutter widgets.
const ownPinImage = 'pin-own';
const cataloguePinImage = 'pin-catalogue';

/// Logical side of a pin image; the round pin is centred on the trail anchor.
const trailPinSide = 34.0;

/// The two pin styles, shared by the map and the lists so both read alike:
/// the walker's trails are solid green with a "saved" mark, catalogue trails
/// light with a purple rim and walker, so one's own trails stand out without
/// hiding the catalogue.
IconData pinIcon({required bool catalogue}) =>
    catalogue ? Icons.hiking : Icons.bookmark;

void paintTrailPin(
  Canvas canvas,
  Offset centre, {
  required bool catalogue,
  double radius = 13,
}) {
  canvas.drawCircle(
    centre.translate(0, 1.5),
    radius + 1.5,
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
  );
  canvas.drawCircle(
    centre,
    radius + 1.5,
    Paint()..color = catalogue ? catalogueColor : Colors.white,
  );
  canvas.drawCircle(
    centre,
    radius - 1,
    Paint()..color = catalogue ? Colors.white : forest,
  );
  final icon = pinIcon(catalogue: catalogue);
  final text = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: radius * 1.2,
        color: catalogue ? catalogueColor : Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));
}

/// PNG of a pin at [pixelRatio] physical pixels per logical pixel.
Future<Uint8List> trailPinPng(
  double pixelRatio, {
  required bool catalogue,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  paintTrailPin(
    canvas,
    const Offset(trailPinSide / 2, trailPinSide / 2),
    catalogue: catalogue,
  );
  final side = (trailPinSide * pixelRatio).round();
  final image = await recorder.endRecording().toImage(side, side);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// The map pin as a widget, for lists and legends.
class TrailPinBadge extends StatelessWidget {
  const TrailPinBadge({required this.catalogue, this.size = 34, super.key});
  final bool catalogue;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _PinPainter(catalogue, size)),
  );
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.catalogue, this.size);
  final bool catalogue;
  final double size;
  @override
  void paint(Canvas canvas, Size _) => paintTrailPin(
    canvas,
    Offset(size / 2, size / 2),
    catalogue: catalogue,
    radius: size * 13 / trailPinSide,
  );

  @override
  bool shouldRepaint(_PinPainter old) =>
      old.catalogue != catalogue || old.size != size;
}
