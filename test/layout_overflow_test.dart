import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/ui/screens/contracts_screen.dart';
import 'package:vending_empire/ui/screens/hq_dashboard.dart';
import 'package:vending_empire/ui/screens/options_screen.dart';
import 'package:vending_empire/ui/screens/research_screen.dart';
import 'package:vending_empire/ui/screens/rival_screen.dart';
import 'package:vending_empire/ui/screens/route_planner_screen.dart';
import 'package:vending_empire/ui/screens/warehouse_screen.dart';
import 'package:vending_empire/ui/theme/vex_theme.dart';

/// Lays out each main screen at phone sizes and fails on any overflow.
void main() {
  final screens = <String, Widget Function()>{
    'hq': () => const HQDashboard(),
    'fleet': () => const RoutePlannerScreen(),
    'market': () => const WarehouseScreen(),
    'contracts': () => const ContractsScreen(),
    'research': () => const ResearchScreen(),
    'rival': () => const RivalScreen(),
    'options': () => const OptionsScreen(),
  };
  for (final size in const [Size(390, 844), Size(844, 390)]) {
    for (final entry in screens.entries) {
      testWidgets('audit ${entry.key} ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        final problems = <String>[];
        await tester.pumpWidget(ProviderScope(child: MaterialApp(
          theme: VexTheme.light,
          home: Scaffold(body: entry.value()),
        )));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          dynamic e;
          while ((e = tester.takeException()) != null) {
            final text = e.toString();
            if (text.contains('overflowed')) problems.add(text.replaceAll('\n', ' | ').substring(0, text.length > 400 ? 400 : text.length));
          }
        }
        await tester.pumpWidget(const SizedBox());
        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }
  }
}
