import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sound_service.dart';
import '../../simulation/models/district.dart';
import '../../state/providers.dart';
import '../utils/screen_utils.dart';

/// Districts - unlock new rings of the city for new-machine purchases
class DistrictsScreen extends ConsumerWidget {
  const DistrictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    void unlockDistrict(DistrictData district) {
      if (gameState.cash < district.unlockCost) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough cash!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }

      controller.unlockDistrict(district.id);
      SoundService().playButtonSound();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${district.name} unlocked!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Districts'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.indigo.shade50,
        padding: ScreenUtils.relativePadding(context, 0.02),
        child: ListView(
          children: [
            Card(
              elevation: 4,
              color: Colors.indigo.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map, size: 32, color: Colors.indigo),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        const Text('Available Funds', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${gameState.cash.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...DistrictData.all.map((district) {
              final unlocked = gameState.unlockedDistricts.contains(district.id);
              final canAfford = gameState.cash >= district.unlockCost;
              final bonusPercent = ((district.trafficBonusMultiplier - 1.0) * 100).round();

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: unlocked
                        ? BorderSide(color: Colors.green.shade400, width: 2)
                        : BorderSide.none,
                  ),
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
                                color: unlocked ? Colors.green.shade100 : Colors.indigo.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _iconFor(district.id),
                                size: 32,
                                color: unlocked ? Colors.green.shade700 : Colors.indigo.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    district.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    district.description,
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (bonusPercent > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+$bonusPercent% traffic for every machine here',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: unlocked
                              ? Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'UNLOCKED',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: canAfford ? () => unlockDistrict(district) : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: Text('Unlock for \$${district.unlockCost.toStringAsFixed(0)}'),
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

  IconData _iconFor(DistrictId id) {
    switch (id) {
      case DistrictId.core:
        return Icons.home_work;
      case DistrictId.suburban:
        return Icons.holiday_village;
      case DistrictId.outer:
        return Icons.terrain;
    }
  }
}
