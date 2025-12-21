import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/machine.dart';
import '../../state/providers.dart';
import '../theme/zone_ui.dart';

/// Widget that displays a machine's status in a card format
class MachineStatusCard extends ConsumerStatefulWidget {
  final Machine machine;

  const MachineStatusCard({
    super.key,
    required this.machine,
  });

  @override
  ConsumerState<MachineStatusCard> createState() => _MachineStatusCardState();
}

class _MachineStatusCardState extends ConsumerState<MachineStatusCard> {
  bool _isExpanded = false;

  /// Calculate stock level percentage (0.0 to 1.0)
  /// Assuming max capacity of 50 items for visualization
  double _getStockLevel(Machine machine) {
    const maxCapacity = 50.0;
    final currentStock = machine.totalInventory.toDouble();
    return (currentStock / maxCapacity).clamp(0.0, 1.0);
  }

  /// Get color for stock level indicator
  Color _getStockColor(Machine machine) {
    final level = _getStockLevel(machine);
    if (level > 0.5) return Colors.green;
    if (level > 0.2) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final machine = widget.machine;
    final stockLevel = _getStockLevel(machine);
    final stockColor = _getStockColor(machine);
    final zoneIcon = machine.zone.type.icon;
    final zoneColor = machine.zone.type.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main row with machine info
              Row(
                children: [
                  // Left: Zone Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      zoneIcon,
                      color: zoneColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Center: Machine Info and Stock Level
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          machine.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Stock Level Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stock: ${machine.totalInventory} items',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: stockLevel,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(stockColor),
                              minHeight: 6,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right: Cash Display and Expand Icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cash',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '\$${machine.currentCash.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),
              // Expanded section with detailed stock and retrieve button
              if (_isExpanded) ...[
                const Divider(height: 24),
                // Stock details
                Text(
                  'Stock Details:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (machine.inventory.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Empty',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                else
                  ...machine.inventory.values.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.product.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${item.quantity}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                const SizedBox(height: 16),
                // Retrieve cash button
                if (machine.currentCash > 0)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(gameControllerProvider.notifier).retrieveCash(machine.id);
                        // Optionally close the expanded view after retrieving
                        // setState(() {
                        //   _isExpanded = false;
                        // });
                      },
                      icon: const Icon(Icons.account_balance_wallet, size: 18),
                      label: Text(
                        'Retrieve \$${machine.currentCash.toStringAsFixed(2)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'No cash to retrieve',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

