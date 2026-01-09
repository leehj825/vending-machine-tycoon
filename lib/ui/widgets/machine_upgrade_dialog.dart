import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config.dart';
import '../../simulation/models/machine.dart';
import '../../state/providers.dart';
import '../../services/sound_service.dart';
import '../utils/screen_utils.dart';

/// Dialog to manage upgrades for a specific machine
class MachineUpgradeDialog extends ConsumerStatefulWidget {
  final Machine machine;

  const MachineUpgradeDialog({
    super.key,
    required this.machine,
  });

  @override
  ConsumerState<MachineUpgradeDialog> createState() => _MachineUpgradeDialogState();
}

class _MachineUpgradeDialogState extends ConsumerState<MachineUpgradeDialog> {
  late Machine _currentMachine;

  @override
  void initState() {
    super.initState();
    _currentMachine = widget.machine;
  }

  void _purchaseUpgrade(String upgradeType, double cost) {
    final gameState = ref.read(gameStateProvider);
    if (gameState.cash < cost) {
      // Not enough money
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Not enough cash!"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final controller = ref.read(gameControllerProvider.notifier);
    final machines = ref.read(machinesProvider);
    final machineIndex = machines.indexWhere((m) => m.id == _currentMachine.id);

    if (machineIndex == -1) return;

    Machine updatedMachine = machines[machineIndex];
    bool upgraded = false;

    switch (upgradeType) {
      case 'capacity':
        if (updatedMachine.levelCapacity < AppConfig.upgradeCapacityMaxLevel) {
          updatedMachine = updatedMachine.copyWith(
            levelCapacity: updatedMachine.levelCapacity + 1,
          );
          upgraded = true;
        }
        break;
      case 'cooling':
        if (updatedMachine.levelCooling < AppConfig.upgradeCoolingMaxLevel) {
          updatedMachine = updatedMachine.copyWith(
            levelCooling: updatedMachine.levelCooling + 1,
          );
          upgraded = true;
        }
        break;
      case 'security':
        if (updatedMachine.levelSecurity < AppConfig.upgradeSecurityMaxLevel) {
          updatedMachine = updatedMachine.copyWith(
            levelSecurity: updatedMachine.levelSecurity + 1,
          );
          upgraded = true;
        }
        break;
      case 'ads':
        if (updatedMachine.levelAds < AppConfig.upgradeAdDisplayMaxLevel) {
          updatedMachine = updatedMachine.copyWith(
            levelAds: updatedMachine.levelAds + 1,
          );
          upgraded = true;
        }
        break;
    }

    if (upgraded) {
      // Deduct cash
      controller.updateCash(gameState.cash - cost);
      // Update machine
      controller.updateMachine(updatedMachine);

      setState(() {
        _currentMachine = updatedMachine;
      });

      // Play success sound
      SoundService().playCoinCollectSound();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upgrade successful!"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    // Ensure we are watching the specific machine to reflect updates immediately
    final machines = ref.watch(machinesProvider);
    final latestMachine = machines.firstWhere(
      (m) => m.id == widget.machine.id,
      orElse: () => _currentMachine
    );

    // Update local state if needed (though we mostly use latestMachine for rendering)
    if (latestMachine != _currentMachine) {
        // We can just use latestMachine for rendering, but let's keep _currentMachine in sync
        // triggering a rebuild is handled by ref.watch
        _currentMachine = latestMachine;
    }

    final gameDimension = ScreenUtils.getGameDimension(context);
    final dialogWidth = gameDimension * 0.9;
    final padding = dialogWidth * 0.04;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(padding),
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Machine Upgrades',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cash Display
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.attach_money, color: Colors.green),
                Text(
                  gameState.cash.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            const Divider(),
            // Upgrades List
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildUpgradeItem(
                      context,
                      title: 'Capacity Upgrade',
                      description: '+${AppConfig.upgradeCapacityBonus} slots per level',
                      icon: Icons.inventory_2,
                      currentLevel: latestMachine.levelCapacity,
                      maxLevel: AppConfig.upgradeCapacityMaxLevel,
                      cost: AppConfig.upgradeCapacityCost,
                      onBuy: () => _purchaseUpgrade('capacity', AppConfig.upgradeCapacityCost),
                      canAfford: gameState.cash >= AppConfig.upgradeCapacityCost,
                    ),
                    _buildUpgradeItem(
                      context,
                      title: 'Cooling System',
                      description: 'Reduces spoilage rate',
                      icon: Icons.ac_unit,
                      currentLevel: latestMachine.levelCooling,
                      maxLevel: AppConfig.upgradeCoolingMaxLevel,
                      cost: AppConfig.upgradeCoolingCost,
                      onBuy: () => _purchaseUpgrade('cooling', AppConfig.upgradeCoolingCost),
                      canAfford: gameState.cash >= AppConfig.upgradeCoolingCost,
                    ),
                    _buildUpgradeItem(
                      context,
                      title: 'Security System',
                      description: 'Reduces empty machine penalties',
                      icon: Icons.security,
                      currentLevel: latestMachine.levelSecurity,
                      maxLevel: AppConfig.upgradeSecurityMaxLevel,
                      cost: AppConfig.upgradeSecurityCost,
                      onBuy: () => _purchaseUpgrade('security', AppConfig.upgradeSecurityCost),
                      canAfford: gameState.cash >= AppConfig.upgradeSecurityCost,
                    ),
                    _buildUpgradeItem(
                      context,
                      title: 'Ad Display',
                      description: 'Generates \$${AppConfig.upgradeAdDisplayIncome}/day passive income',
                      icon: Icons.tv,
                      currentLevel: latestMachine.levelAds,
                      maxLevel: AppConfig.upgradeAdDisplayMaxLevel,
                      cost: AppConfig.upgradeAdDisplayCost,
                      onBuy: () => _purchaseUpgrade('ads', AppConfig.upgradeAdDisplayCost),
                      canAfford: gameState.cash >= AppConfig.upgradeAdDisplayCost,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeItem(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required int currentLevel,
    required int maxLevel,
    required double cost,
    required VoidCallback onBuy,
    required bool canAfford,
  }) {
    final isMaxed = currentLevel >= maxLevel;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 32, color: Colors.blue[700]),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Lvl $currentLevel/$maxLevel',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isMaxed ? Colors.green : Colors.orange[800],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Buy Button
            ElevatedButton(
              onPressed: (isMaxed || !canAfford) ? null : onBuy,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMaxed ? 'MAX' : '\$${cost.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (!isMaxed)
                    const Text(
                      'BUY',
                      style: TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
