import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/ui/three_d/lowpoly_engine.dart';

void main() {
  testWidgets('a tap still registers after a pointer was left down and the view reset', (tester) async {
    final controller = LowPolyController();
    final taps = <Object>[];
    // A square of triangles facing the camera, taller than it is wide, so the centre hits it.
    final square = LowPolyObject(
      center: const Vec3(0, 0, 0),
      payload: 'machine',
      triangles: [
        LowPolyTriangle(const Vec3(-1, -1, 0), const Vec3(1, -1, 0), const Vec3(1, 1, 0), const Vec3(0, 0, 1), const Color(0xFF888888)),
        LowPolyTriangle(const Vec3(-1, -1, 0), const Vec3(1, 1, 0), const Vec3(-1, 1, 0), const Vec3(0, 0, 1), const Color(0xFF888888)),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 400,
        height: 400,
        child: LowPolyView(
          objects: [square],
          camera: const LowPolyCamera(target: Vec3(0, 0, 0), yaw: 0, pitch: 0, distance: 6),
          background: const Color(0xFFEEEEEE),
          controller: controller,
          onTapTarget: taps.add,
        ),
      ),
    ));

    final centre = tester.getCenter(find.byType(LowPolyView));
    await tester.tapAt(centre);
    expect(taps, ['machine'], reason: 'a normal tap should register');

    // A dialog opened over the view while a finger was down, so its release never arrived.
    await tester.startGesture(centre);
    controller.reset();

    await tester.tapAt(centre);
    expect(taps, ['machine', 'machine'], reason: 'the view should accept taps again after a reset');
  });
}
