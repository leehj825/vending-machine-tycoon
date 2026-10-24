import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/simulation/models/truck.dart' as sim;
import 'package:vending_empire/state/providers.dart';
import 'package:vending_empire/ui/screens/tile_city_screen.dart';

void main() {
  testWidgets('3D city keeps its size and stays drawn with a truck and the marketing button',
      (tester) async {
    final key = GlobalKey();
    final truck = sim.Truck(
      id: 't1',
      name: 'Truck 1',
      currentX: 10,
      currentY: 9,
      targetX: 10,
      targetY: 9,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [trucksProvider.overrideWith((ref) => [truck])],
      child: MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(key: key, child: const TileCityScreen()),
        ),
      ),
    ));

    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'at ${i * 100} ms');
    }

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      expect(boundary.size.isEmpty, isFalse, reason: 'the city must not collapse to nothing');

      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var coloured = 0;
      for (var y = 0; y < image.height; y += 4) {
        for (var x = 0; x < image.width; x += 4) {
          final i = (y * image.width + x) * 4;
          final r = data.getUint8(i);
          final g = data.getUint8(i + 1);
          final b = data.getUint8(i + 2);
          // Grass is green and the sky is blue. The blank background is not.
          if ((g - r).abs() > 30 || (b - r).abs() > 30) coloured++;
        }
      }
      expect(coloured, greaterThan(1000), reason: 'the map should be visible');
    });
  });
}
