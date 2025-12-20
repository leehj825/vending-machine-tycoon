import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../../game/city_map_game.dart';
import '../../simulation/models/machine.dart';

/// Screen that displays the city map using Flame game engine
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AppBar removed - managed by MainScreen
    return GameWidget<CityMapGame>.controlled(
      gameFactory: () => CityMapGame(
        ref,
        onMachineTap: (machine) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    machine.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Cash: \$${machine.currentCash.toStringAsFixed(2)}'),
                  Text(
                    'Inventory: ${machine.inventory.isEmpty ? "Empty" : machine.inventory.values.map((i) => "${i.product.name}: ${i.quantity}").join(", ")}',
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }
}

