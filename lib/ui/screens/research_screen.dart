import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/research.dart';
import '../../state/providers.dart';
import '../../services/sound_service.dart';
import '../utils/screen_utils.dart';
import '../../config.dart';

class ResearchScreen extends ConsumerWidget {
  const ResearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    // Check if research is unlocked
    bool isUnlocked(ResearchType type) => gameState.unlockedResearch.contains(type);

    // Purchase research
    void purchaseResearch(ResearchData research) {
      if (gameState.cash >= research.cost) {
        controller.unlockResearch(research.type, research.cost);
        SoundService().playSoundEffect('sound/upgrade.m4a'); // Use a generic sound or fallback

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${research.name} unlocked!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough cash!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Research Lab'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.indigo.shade50,
        padding: ScreenUtils.relativePadding(context, 0.02),
        child: Column(
          children: [
            // Header Stats
            Card(
              elevation: 4,
              color: Colors.indigo.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.science, size: 32, color: Colors.indigo),
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

            // Tech Tree Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: ResearchData.allResearch.length,
                itemBuilder: (context, index) {
                  final research = ResearchData.allResearch[index];
                  final unlocked = isUnlocked(research.type);
                  final canAfford = gameState.cash >= research.cost;

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: unlocked
                        ? BorderSide(color: Colors.green.shade400, width: 2)
                        : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: unlocked ? Colors.green.shade100 : Colors.indigo.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIconForType(research.type),
                              size: 32,
                              color: unlocked ? Colors.green.shade700 : Colors.indigo.shade700,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  research.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  research.description,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                unlocked
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: Colors.green.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: canAfford ? () => purchaseResearch(research) : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: Text(
                                        'Research \$${research.cost.toStringAsFixed(0)}',
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(ResearchType type) {
    switch (type) {
      case ResearchType.turboTrucks:
        return Icons.local_shipping;
      case ResearchType.premiumBranding:
        return Icons.verified;
      case ResearchType.efficientCooling:
        return Icons.ac_unit;
    }
  }
}
