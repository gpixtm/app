import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/presentation/compass_needle.dart';

void main() {
  testWidgets('the needle turns against the phone heading to point north', (
    tester,
  ) async {
    // Facing east (90°), north is a quarter turn to the left.
    await tester.pumpWidget(const Center(child: CompassNeedle(-90)));
    final rotation = tester.widget<Transform>(
      find.descendant(
        of: find.byType(CompassNeedle),
        matching: find.byType(Transform),
      ),
    );
    final tip = MatrixUtils.transformPoint(
      rotation.transform,
      const Offset(0, -1),
    );
    expect(tip.dx, closeTo(-1, 1e-9));
    expect(tip.dy, closeTo(0, 1e-9));
  });
}
