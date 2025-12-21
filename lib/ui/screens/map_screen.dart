import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../../game/city_map_game.dart';
import '../../simulation/models/machine.dart';
import '../../state/providers.dart';

/// Screen that displays the city map using Flame game engine
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMachineId = ref.watch(selectedMachineIdProvider);
    final machines = ref.watch(machinesProvider);
    
    Machine? selectedMachine;
    if (selectedMachineId != null) {
      try {
        selectedMachine = machines.firstWhere((m) => m.id == selectedMachineId);
      } catch (e) {
        // Machine might have been removed or ID is invalid
        selectedMachine = null;
      }
    }

    // AppBar removed - managed by MainScreen
    return Stack(
      children: [
        GameWidget<CityMapGame>.controlled(
          gameFactory: () => CityMapGame(
            ref,
            onMachineTap: (machine) {
              // Legacy tap handler, kept for now but could be removed
              // The MapMachine component now updates the provider directly
              
              /*
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
              */
            },
          ),
        ),
        
        // Simple machine info overlay (detailed info available on main page)
        if (selectedMachine != null)
          Builder(
            builder: (context) {
              final machine = selectedMachine!;
              return Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                machine.name,
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'View details on HQ page',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            ref.read(selectedMachineIdProvider.notifier).state = null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

