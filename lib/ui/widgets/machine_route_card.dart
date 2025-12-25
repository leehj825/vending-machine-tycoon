import 'package:flutter/material.dart';
import '../../simulation/models/machine.dart';
import '../theme/zone_ui.dart';

/// Card widget that displays a machine in a route list
class MachineRouteCard extends StatelessWidget {
  final Machine machine;
  final VoidCallback onRemove;

  const MachineRouteCard({
    super.key,
    required this.machine,
    required this.onRemove,
  });

  /// Get stock level color
  Color _getStockColor(int stock) {
    if (stock == 0) return Colors.red;
    if (stock < 5) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final zoneIcon = machine.zone.type.icon;
    final zoneColor = machine.zone.type.color;
    final stock = machine.totalInventory;
    final stockColor = _getStockColor(stock);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: zoneColor.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: zoneColor.withOpacity(0.1),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {}, // Can be used for future tap actions
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Zone Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: zoneColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: zoneColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Icon(zoneIcon, color: zoneColor, size: 24),
              ),
              const SizedBox(width: 16),
              // Machine Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      machine.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Zone: ${machine.zone.type.name.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 16, color: stockColor),
                        const SizedBox(width: 4),
                        Text(
                          'Stock: $stock items',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Remove Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: onRemove,
                  tooltip: 'Remove from route',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

