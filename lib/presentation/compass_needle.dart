import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compass needle whose red tip points north, [degrees] clockwise from the
/// top of the widget.
class CompassNeedle extends StatelessWidget {
  const CompassNeedle(this.degrees, {this.size = 24, super.key});
  final double degrees;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: degrees * math.pi / 180,
    child: CustomPaint(size: Size.square(size), painter: _NeedlePainter()),
  );
}

class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final length = size.height * .46, half = size.width * .17;
    Path blade(double tip) => Path()
      ..moveTo(centre.dx, centre.dy + tip)
      ..lineTo(centre.dx + half, centre.dy)
      ..lineTo(centre.dx - half, centre.dy)
      ..close();
    canvas
      ..drawPath(blade(-length), Paint()..color = const Color(0xffd32f2f))
      ..drawPath(blade(length), Paint()..color = const Color(0xff9e9e9e))
      ..drawCircle(centre, half * .45, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) => false;
}
