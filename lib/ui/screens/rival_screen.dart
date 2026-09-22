import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sound_service.dart';
import '../../simulation/models/rival.dart';
import '../../simulation/models/zone.dart';
import '../../state/providers.dart';
import '../theme/zone_ui.dart';
import '../utils/screen_utils.dart';

/// Rival Company - a competitor eating into each zone type's market. Grows
/// fastest where the player has the fewest machines; counter-attack
/// campaigns push it back, at a cost that rises with how entrenched it is.
class RivalScreen extends ConsumerWidget {
  const RivalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    final machineCountByZone = <ZoneType, int>{};
    for (final machine in gameState.machines) {
      machineCountByZone[machine.zone.type] = (machineCountByZone[machine.zone.type] ?? 0) + 1;
    }

    void counterAttack(ZoneType type, double presence) {
      final cost = RivalMath.counterAttackCost(presence);
      if (gameState.cash < cost) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough cash!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }

      controller.counterAttackRival(type);
      SoundService().playButtonSound();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Counter-attack launched in the ${type.name} market!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rival Company'),
        backgroundColor: Colors.deepOrange.shade900,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.deepOrange.shade50,
        padding: ScreenUtils.relativePadding(context, 0.02),
        child: ListView(
          children: [
            Card(
              elevation: 4,
              color: Colors.deepOrange.shade100,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.storefront, size: 32, color: Colors.deepOrange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A competitor is chasing the same customers you are. They grow fastest in zone '
                        "types where you're thin on machines - the fewer of yours, the easier it is for "
                        'them to move in. A counter-attack pushes them back, but they never stay gone '
                        'for long.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...ZoneType.values.map((type) {
              final presence = gameState.rivalPresence[type] ?? 0.0;
              final machineCount = machineCountByZone[type] ?? 0;
              final demandCutPercent = ((1.0 - RivalMath.demandMultiplier(presence)) * 100).round();
              final cost = RivalMath.counterAttackCost(presence);
              final canAfford = gameState.cash >= cost;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: type.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(type.icon, size: 28, color: type.color),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    type.name[0].toUpperCase() + type.name.substring(1),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  Text(
                                    'Your machines here: $machineCount',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(presence * 100).round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: presence > 0.5 ? Colors.red.shade700 : Colors.deepOrange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: presence,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            color: presence > 0.5 ? Colors.red.shade400 : Colors.deepOrange.shade400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          demandCutPercent > 0
                              ? 'Cutting your sales here by about $demandCutPercent%'
                              : 'No impact on your sales here yet',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: presence <= 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'NO RIVAL PRESENCE',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: canAfford ? () => counterAttack(type, presence) : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: Text('Counter-Attack for \$${cost.toStringAsFixed(0)}'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
