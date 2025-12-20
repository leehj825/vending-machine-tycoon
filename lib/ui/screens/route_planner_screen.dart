import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import '../../state/providers.dart';
import '../../simulation/models/machine.dart';
import '../../simulation/models/truck.dart';
import '../../simulation/models/product.dart';
import '../widgets/machine_route_card.dart';
import '../theme/zone_ui.dart';
import 'dart:math' as math;

/// Notifier for selected truck ID
class SelectedTruckNotifier extends StateNotifier<String?> {
  SelectedTruckNotifier() : super(null);

  void selectTruck(String? truckId) {
    state = truckId;
  }

  String? get selectedId => state;
}

/// Provider for selected truck ID
final selectedTruckIdProvider = Provider<SelectedTruckNotifier>((ref) {
  return SelectedTruckNotifier();
});

/// Route Planner Screen for managing truck routes
class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-select first truck if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trucks = ref.read(trucksProvider);
      final notifier = ref.read(selectedTruckIdProvider);
      if (trucks.isNotEmpty && notifier.selectedId == null) {
        notifier.selectTruck(trucks.first.id);
      }
    });
  }

  /// Calculate Euclidean distance between two points
  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Calculate total route distance
  double _calculateRouteDistance(
    List<String> machineIds,
    List<Machine> machines,
  ) {
    if (machineIds.isEmpty) return 0.0;

    double totalDistance = 0.0;
    double lastX = 0.0; // Warehouse at (0, 0)
    double lastY = 0.0;

    // Distance from warehouse to first stop
    if (machineIds.isNotEmpty) {
      final firstMachine = machines.firstWhere(
        (m) => m.id == machineIds.first,
        orElse: () => machines.first,
      );
      totalDistance += _calculateDistance(
        lastX,
        lastY,
        firstMachine.zone.x,
        firstMachine.zone.y,
      );
      lastX = firstMachine.zone.x;
      lastY = firstMachine.zone.y;
    }

    // Distance between stops
    for (int i = 1; i < machineIds.length; i++) {
      final machine = machines.firstWhere(
        (m) => m.id == machineIds[i],
        orElse: () => machines.first,
      );
      totalDistance += _calculateDistance(
        lastX,
        lastY,
        machine.zone.x,
        machine.zone.y,
      );
      lastX = machine.zone.x;
      lastY = machine.zone.y;
    }

    // Return to warehouse
    totalDistance += _calculateDistance(lastX, lastY, 0.0, 0.0);

    return totalDistance;
  }

  /// Get efficiency rating
  String _getEfficiencyRating(double distance, int machineCount) {
    if (machineCount == 0) return 'N/A';
    final ratio = distance / machineCount;
    if (ratio < 50) return 'Great';
    if (ratio < 100) return 'Good';
    if (ratio < 200) return 'Fair';
    return 'Poor';
  }

  /// Get efficiency color
  Color _getEfficiencyColor(String rating) {
    switch (rating) {
      case 'Great':
        return Colors.green;
      case 'Good':
        return Colors.blue;
      case 'Fair':
        return Colors.orange;
      case 'Poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showAddStopDialog(Truck selectedTruck, List<Machine> allMachines) {
    // Get machines not currently on the route
    final routeMachineIds = selectedTruck.route.toSet();
    final availableMachines = allMachines
        .where((m) => !routeMachineIds.contains(m.id))
        .toList();

    if (availableMachines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available machines to add')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Stop'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableMachines.length,
            itemBuilder: (context, index) {
              final machine = availableMachines[index];
              return ListTile(
                leading: Icon(
                  machine.zone.type.icon,
                  color: machine.zone.type.color,
                ),
                title: Text(machine.name),
                subtitle: Text('Zone: ${machine.zone.type.name}'),
                onTap: () {
                  _addStopToRoute(selectedTruck.id, machine.id);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _addStopToRoute(String truckId, String machineId) {
    final controller = ref.read(gameControllerProvider.notifier);
    final trucks = ref.read(trucksProvider);
    final truck = trucks.firstWhere((t) => t.id == truckId);
    final newRoute = [...truck.route, machineId];
    controller.updateRoute(truckId, newRoute);
  }

  void _removeStopFromRoute(String truckId, String machineId) {
    final controller = ref.read(gameControllerProvider.notifier);
    final trucks = ref.read(trucksProvider);
    final truck = trucks.firstWhere((t) => t.id == truckId);
    final newRoute = truck.route.where((id) => id != machineId).toList();
    controller.updateRoute(truckId, newRoute);
  }

  void _reorderRoute(String truckId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final controller = ref.read(gameControllerProvider.notifier);
    final trucks = ref.read(trucksProvider);
    final truck = trucks.firstWhere((t) => t.id == truckId);
    final newRoute = List<String>.from(truck.route);
    final item = newRoute.removeAt(oldIndex);
    newRoute.insert(newIndex, item);
    controller.updateRoute(truckId, newRoute);
  }

  void _showLoadCargoDialog(Truck truck) {
    final warehouse = ref.read(warehouseProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    showDialog(
      context: context,
      builder: (context) => _LoadCargoDialog(
        truck: truck,
        warehouse: warehouse,
        onLoad: (product, quantity) {
          controller.loadTruck(truck.id, product, quantity);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded $quantity ${product.name} onto ${truck.name}'),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trucks = ref.watch(trucksProvider);
    final machines = ref.watch(machinesProvider);
    final selectedTruckNotifier = ref.watch(selectedTruckIdProvider);
    final selectedTruckId = selectedTruckNotifier.selectedId;

    final selectedTruck = selectedTruckId != null
        ? trucks.firstWhere(
            (t) => t.id == selectedTruckId,
            orElse: () => trucks.isNotEmpty ? trucks.first : trucks.first,
          )
        : null;

    // Get machines for the selected truck's route
    final routeMachines = selectedTruck != null
        ? selectedTruck.route
            .map((id) => machines.firstWhere(
                  (m) => m.id == id,
                  orElse: () => machines.first,
                ))
            .toList()
        : <Machine>[];

    // Calculate route stats
    final totalDistance = selectedTruck != null
        ? _calculateRouteDistance(selectedTruck.route, machines)
        : 0.0;
    final fuelCost = totalDistance * 0.50;
    final efficiencyRating = selectedTruck != null
        ? _getEfficiencyRating(totalDistance, selectedTruck.route.length)
        : 'N/A';

    return Scaffold(
      // AppBar removed - managed by MainScreen
      body: CustomScrollView(
        slivers: [
          // Top Section: Truck Selector
          SliverToBoxAdapter(
            child: Container(
              constraints: const BoxConstraints(minHeight: 150),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Select Truck',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 130,
                    child: trucks.isEmpty
                        ? const Center(
                            child: Text('No trucks available'),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: trucks.length,
                            itemBuilder: (context, index) {
                              final truck = trucks[index];
                              final isSelected = truck.id == selectedTruckId;

                            return GestureDetector(
                              onTap: () {
                                ref.read(selectedTruckIdProvider)
                                    .selectTruck(truck.id);
                              },
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.local_shipping,
                                        size: 32,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(height: 8),
                                      Flexible(
                                        child: Text(
                                          truck.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Colors.black87,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.local_gas_station,
                                            size: 14,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '${truck.fuel.toStringAsFixed(0)}%',
                                              style: const TextStyle(fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(truck.status)
                                                .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getStatusText(truck.status),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: _getStatusColor(truck.status),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 1),
          ),
          // Middle Section: Route Editor
          if (selectedTruck == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: const Center(
                child: Text('Select a truck to manage its route'),
              ),
            )
          else ...[
            // Route Header with Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Current Route (Drag to Reorder)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showLoadCargoDialog(selectedTruck),
                          icon: const Icon(Icons.inventory, size: 18),
                          label: const Text('Load Cargo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showAddStopDialog(selectedTruck, machines),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Stop'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Route List or Empty State
            if (routeMachines.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.route,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No stops in route',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddStopDialog(selectedTruck, machines),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Stop'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: routeMachines.length,
                    onReorder: (oldIndex, newIndex) {
                      _reorderRoute(
                        selectedTruck.id,
                        oldIndex,
                        newIndex,
                      );
                    },
                    itemBuilder: (context, index) {
                      final machine = routeMachines[index];
                      return MachineRouteCard(
                        key: ValueKey(machine.id),
                        machine: machine,
                        onRemove: () => _removeStopFromRoute(
                          selectedTruck.id,
                          machine.id,
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Bottom Section: Efficiency Stats
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Route Efficiency',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              icon: Icons.straighten,
                              label: 'Total Distance',
                              value: '${totalDistance.toStringAsFixed(1)} units',
                            ),
                            _StatItem(
                              icon: Icons.local_gas_station,
                              label: 'Est. Fuel Cost',
                              value: '\$${fuelCost.toStringAsFixed(2)}',
                            ),
                            _StatItem(
                              icon: Icons.star,
                              label: 'Efficiency',
                              value: efficiencyRating,
                              valueColor: _getEfficiencyColor(efficiencyRating),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(TruckStatus status) {
    switch (status) {
      case TruckStatus.idle:
        return Colors.grey;
      case TruckStatus.traveling:
        return Colors.blue;
      case TruckStatus.restocking:
        return Colors.orange;
    }
  }

  String _getStatusText(TruckStatus status) {
    switch (status) {
      case TruckStatus.idle:
        return 'Idle';
      case TruckStatus.traveling:
        return 'Moving';
      case TruckStatus.restocking:
        return 'Restocking';
    }
  }
}

/// Dialog for loading cargo onto a truck
class _LoadCargoDialog extends ConsumerStatefulWidget {
  final Truck truck;
  final Warehouse warehouse;
  final void Function(Product product, int quantity) onLoad;

  const _LoadCargoDialog({
    required this.truck,
    required this.warehouse,
    required this.onLoad,
  });

  @override
  ConsumerState<_LoadCargoDialog> createState() => _LoadCargoDialogState();
}

class _LoadCargoDialogState extends ConsumerState<_LoadCargoDialog> {
  Product? _selectedProduct;
  double _quantity = 1.0;

  @override
  Widget build(BuildContext context) {
    final availableProducts = Product.values
        .where((p) => (widget.warehouse.inventory[p] ?? 0) > 0)
        .toList();
    final availableCapacity = widget.truck.capacity - widget.truck.currentLoad;
    final maxQuantity = _selectedProduct != null
        ? [
            widget.warehouse.inventory[_selectedProduct] ?? 0,
            availableCapacity,
          ].reduce((a, b) => a < b ? a : b)
        : 0;
    final quantityInt = _quantity.round().clamp(1, maxQuantity);

    return AlertDialog(
      title: Text('Load Cargo - ${widget.truck.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Capacity: $availableCapacity / ${widget.truck.capacity}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const Text('Select Product:'),
            const SizedBox(height: 8),
            DropdownButtonFormField<Product>(
              value: _selectedProduct,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Choose a product',
              ),
              items: availableProducts.map((product) {
                final stock = widget.warehouse.inventory[product] ?? 0;
                return DropdownMenuItem(
                  value: product,
                  child: Text('${product.name} (Stock: $stock)'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProduct = value;
                  _quantity = 1.0;
                });
              },
            ),
            if (_selectedProduct != null) ...[
              const SizedBox(height: 16),
              Text('Quantity: $quantityInt'),
              Slider(
                value: _quantity.clamp(1.0, maxQuantity.toDouble()),
                min: 1.0,
                max: maxQuantity.toDouble(),
                divisions: maxQuantity > 1 ? maxQuantity - 1 : 1,
                label: quantityInt.toString(),
                onChanged: (value) {
                  setState(() {
                    _quantity = value;
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedProduct != null && quantityInt > 0
              ? () => widget.onLoad(_selectedProduct!, quantityInt)
              : null,
          child: const Text('Load'),
        ),
      ],
    );
  }
}

/// Widget for displaying a stat item in the efficiency card
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: valueColor ?? Colors.grey[700]),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

