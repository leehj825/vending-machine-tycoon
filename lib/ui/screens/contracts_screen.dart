import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../../services/sound_service.dart';
import '../../simulation/models/contract.dart';
import '../../state/providers.dart';
import '../utils/screen_utils.dart';

/// Daily Contracts - time limited goals that reset every game day
class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final contracts = gameState.dailyContracts;
    final completedToday = contracts.where((c) => c.isPaid).length;

    void swapContract(DailyContract contract) {
      if (gameState.cash < AppConfig.contractRerollCost) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough cash!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }

      controller.rerollContract(contract.id);
      SoundService().playButtonSound();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Contracts'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.teal.shade50,
        padding: ScreenUtils.relativePadding(context, 0.02),
        child: Column(
          children: [
            _SummaryCard(
              day: gameState.dayCount,
              completedToday: completedToday,
              totalToday: contracts.length,
              completedAllTime: gameState.contractsCompleted,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: contracts.isEmpty
                  ? Center(
                      child: Text(
                        'Today\'s contracts are being drawn up...',
                        style: TextStyle(color: Colors.teal.shade900),
                      ),
                    )
                  : ListView.separated(
                      itemCount: contracts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final contract = contracts[index];
                        return _ContractCard(
                          contract: contract,
                          canAffordSwap:
                              gameState.cash >= AppConfig.contractRerollCost,
                          onSwap: () => swapContract(contract),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header card with today's progress
class _SummaryCard extends StatelessWidget {
  final int day;
  final int completedToday;
  final int totalToday;
  final int completedAllTime;

  const _SummaryCard({
    required this.day,
    required this.completedToday,
    required this.totalToday,
    required this.completedAllTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.teal.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _stat('Day', '$day', Icons.today),
            _stat('Today', '$completedToday / $totalToday', Icons.assignment_turned_in),
            _stat('All Time', '$completedAllTime', Icons.emoji_events),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.teal.shade800),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// A single contract with progress and reward
class _ContractCard extends StatelessWidget {
  final DailyContract contract;
  final bool canAffordSwap;
  final VoidCallback onSwap;

  const _ContractCard({
    required this.contract,
    required this.canAffordSwap,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final done = contract.isComplete;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: done
            ? BorderSide(color: Colors.green.shade400, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: done ? Colors.green.shade100 : Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconFor(contract.goal),
                    size: 28,
                    color: done ? Colors.green.shade700 : Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contract.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contract.description,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _rewardChip(),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: contract.progressRatio,
                minHeight: 10,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  done ? Colors.green.shade600 : Colors.teal.shade600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  contract.progressLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (done)
                  Text(
                    'PAID OUT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  )
                else if (contract.wasRerolled)
                  Text(
                    'Already swapped',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  )
                else
                  TextButton.icon(
                    onPressed: canAffordSwap ? onSwap : null,
                    icon: const Icon(Icons.autorenew, size: 16),
                    label: Text(
                      'Swap \$${AppConfig.contractRerollCost.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.teal.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardChip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '+\$${contract.rewardCash.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.green.shade800,
          ),
        ),
        Text(
          '+${contract.rewardReputation} rep',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  IconData _iconFor(ContractGoal goal) {
    switch (goal) {
      case ContractGoal.sellProduct:
        return Icons.local_mall;
      case ContractGoal.earnRevenue:
        return Icons.attach_money;
      case ContractGoal.sellUnits:
        return Icons.inventory_2;
    }
  }
}
