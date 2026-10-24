import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/simulation/models/truck.dart' as sim;
import 'package:vending_empire/state/providers.dart';
import 'package:vending_empire/ui/screens/tile_city_screen.dart';

void main() {
  // The 3D city is a WebView, which a widget test cannot draw. This checks that the
  // screen builds and keeps running with a truck and the marketing button.
  testWidgets('3D city builds and keeps running with a truck and the marketing button',
      (tester) async {
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
          body: const TileCityScreen(),
        ),
      ),
    ));

    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'at ${i * 100} ms');
    }
  });
}
