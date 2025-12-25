import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import '../../state/providers.dart';
import '../../simulation/models/machine.dart';
import '../../simulation/models/truck.dart';
import '../../simulation/models/product.dart';
import '../../config.dart';
import '../widgets/machine_route_card.dart';
import '../widgets/game_button.dart';
import '../theme/zone_ui.dart';
import '../utils/screen_utils.dart';
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
    if (machineIds.isEmpty || machines.isEmpty) return 0.0;

    double totalDistance = 0.0;
    double lastX = 0.0; // Warehouse at (0, 0)
    double lastY = 0.0;

    // Distance from warehouse to first stop
    if (machineIds.isNotEmpty) {
      final firstMachineId = machineIds.first;
      final firstMachine = machines.firstWhere(
        (m) => m.id == firstMachineId,
        orElse: () => throw StateError('Machine $firstMachineId not found'),
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
      final machineId = machineIds[i];
      final machine = machines.firstWhere(
        (m) => m.id == machineId,
        orElse: () => throw StateError('Machine $machineId not found'),
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
    if (ratio < AppConfig.routeEfficiencyGreat) return 'Great';
    if (ratio < AppConfig.routeEfficiencyGood) return 'Good';
    if (ratio < AppConfig.routeEfficiencyFair) return 'Fair';
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
    final truck = trucks.firstWhere(
      (t) => t.id == truckId,
      orElse: () => throw StateError('Truck with id $truckId not found'),
    );
    final newRoute = [...truck.route, machineId];
    controller.updateRoute(truckId, newRoute);
  }

  void _removeStopFromRoute(String truckId, String machineId) {
    final controller = ref.read(gameControllerProvider.notifier);
    final trucks = ref.read(trucksProvider);
    final truck = trucks.firstWhere(
      (t) => t.id == truckId,
      orElse: () => throw StateError('Truck with id $truckId not found'),
    );
    final newRoute = truck.route.where((id) => id != machineId).toList();
    controller.updateRoute(truckId, newRoute);
  }

  void _reorderRoute(String truckId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final controller = ref.read(gameControllerProvider.notifier);
    final trucks = ref.read(trucksProvider);
    final truck = trucks.firstWhere(
      (t) => t.id == truckId,
      orElse: () => throw StateError('Truck with id $truckId not found'),
    );
    final newRoute = List<String>.from(truck.route);
    final item = newRoute.removeAt(oldIndex);
    newRoute.insert(newIndex, item);
    controller.updateRoute(truckId, newRoute);
  }

  void _showLoadCargoDialog(Truck truck) {
    final warehouse = ref.read(warehouseProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    // Save the parent context before showing dialog
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => _LoadCargoDialog(
        truck: truck,
        warehouse: warehouse,
        onLoad: (product, quantity) {
          // Close dialog first using dialog's context
          Navigator.of(dialogContext).pop();
          // Perform the load operation
          controller.loadTruck(truck.id, product, quantity);
          // Show snackbar using parent context after dialog closes
          Future.delayed(AppConfig.debounceDelay, () {
            if (parentContext.mounted) {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(
                  content: Text('Loaded $quantity ${product.name} onto ${truck.name}'),
                ),
              );
            }
          });
        },
      ),
    );
  }

  /// Check if truck can go stock (has items and machines have room)
  bool _canGoStock(Truck truck, List<Machine> routeMachines) {
    // Check if truck has items
    if (truck.inventory.isEmpty) return false;
    
    // Check if route has machines
    if (routeMachines.isEmpty) return false;
    
    // Check if any machine in the route has room for any product the truck is carrying
    const maxItemsPerProduct = AppConfig.machineMaxItemsPerProduct;
    for (final machine in routeMachines) {
      for (final entry in truck.inventory.entries) {
        final product = entry.key;
        final truckQuantity = entry.value;
        if (truckQuantity > 0) {
          final machineStock = machine.getStock(product);
          if (machineStock < maxItemsPerProduct) {
            // Found at least one machine with room for at least one product
            return true;
          }
        }
      }
    }
    
    return false;
  }

  /// Start truck on route to stock machines
  void _goStock(Truck truck) {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.goStock(truck.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${truck.name} starting route to stock machines'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trucks = ref.watch(trucksProvider);
    final machines = ref.watch(machinesProvider);
    final selectedTruckNotifier = ref.watch(selectedTruckIdProvider);
    final selectedTruckId = selectedTruckNotifier.selectedId;

    final selectedTruck = selectedTruckId != null && trucks.isNotEmpty
        ? trucks.firstWhere(
            (t) => t.id == selectedTruckId,
            orElse: () => trucks.first, // Fallback to first truck if ID not found
          )
        : null;

    // Get machines for the selected truck's route
    final routeMachines = selectedTruck != null && machines.isNotEmpty
        ? selectedTruck.route
            .map((id) {
              try {
                return machines.firstWhere((m) => m.id == id);
              } catch (e) {
                // If machine not found, skip it (shouldn't happen in normal operation)
                return null;
              }
            })
            .whereType<Machine>()
            .toList()
        : <Machine>[];

    // Calculate route stats
    final totalDistance = selectedTruck != null
        ? _calculateRouteDistance(selectedTruck.route, machines)
        : 0.0;
    final fuelCost = totalDistance * AppConfig.fuelCostPerUnit;
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppConfig.paddingMedium,
                      vertical: AppConfig.paddingSmall,
                    ),
                    child: Text(
                      'Select Truck',
                      style: TextStyle(
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          AppConfig.fontSizeFactorMedium,
                          min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                          max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Truck List or Empty State (with Buy button)
                  SizedBox(
                    height: ScreenUtils.relativeSize(
                      context,
                      AppConfig.truckCardHeightFactor,
                    ),
                    child: trucks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No trucks available',
                                  style: TextStyle(
                                    fontSize: ScreenUtils.relativeFontSize(
                                      context,
                                      AppConfig.fontSizeFactorMedium,
                                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: ScreenUtils.relativeSize(context, 0.03)),
                                GameButton(
                                  onPressed: () {
                                    ref
                                        .read(gameControllerProvider.notifier)
                                        .buyTruck();
                                  },
                                  icon: Icons.add_shopping_cart,
                                  label: 'Buy Truck (\$${AppConfig.truckPrice.toInt()})',
                                  color: Colors.green,
                                ),
                              ],
                            ),
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
                                width: ScreenUtils.relativeSize(
                                  context,
                                  AppConfig.truckCardWidthFactor,
                                ),
                                margin: EdgeInsets.symmetric(
                                  horizontal: ScreenUtils.relativeSize(
                                    context,
                                    AppConfig.truckCardMarginHorizontalFactor,
                                  ),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(AppConfig.truckCardBorderRadius),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.green
                                        : Colors.grey.withValues(alpha: 0.3),
                                    width: isSelected ? 3 : 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.green.withValues(alpha: 0.2),
                                            offset: const Offset(0, 4),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.grey.withValues(alpha: 0.1),
                                            offset: const Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    ScreenUtils.relativeSize(
                                      context,
                                      AppConfig.truckCardPaddingFactor,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: ScreenUtils.relativeSize(
                                          context,
                                          AppConfig.truckIconContainerSizeFactor,
                                        ),
                                        height: ScreenUtils.relativeSize(
                                          context,
                                          AppConfig.truckIconContainerSizeFactor,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.green.withValues(alpha: 0.2)
                                              : Colors.grey.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppConfig.truckIconContainerBorderRadius),
                                        ),
                                        child: Icon(
                                          Icons.local_shipping,
                                          size: ScreenUtils.relativeSize(
                                            context,
                                            AppConfig.truckIconSizeFactor,
                                          ),
                                          color: isSelected
                                              ? Colors.green
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(
                                        height: ScreenUtils.relativeSize(
                                          context,
                                          AppConfig.spacingFactorMedium,
                                        ),
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        child: Text(
                                          truck.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.green
                                                : Colors.black87,
                                            fontSize: ScreenUtils.relativeFontSize(
                                              context,
                                              AppConfig.truckNameFontSizeFactor,
                                              min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                              max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                            ),
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.fade,
                                        ),
                                      ),
                                      SizedBox(
                                        height: ScreenUtils.relativeSize(
                                          context,
                                          AppConfig.spacingFactorSmall,
                                        ),
                                      ),
                                      Flexible(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: ScreenUtils.relativeSize(
                                              context,
                                              AppConfig.truckStatusPaddingHorizontalFactor,
                                            ),
                                            vertical: ScreenUtils.relativeSize(
                                              context,
                                              AppConfig.truckStatusPaddingVerticalFactor,
                                            ),
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(truck.status)
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(AppConfig.truckStatusBorderRadius),
                                            border: Border.all(
                                              color: _getStatusColor(truck.status).withValues(alpha: 0.5),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            _getStatusText(truck.status).toUpperCase(),
                                            style: TextStyle(
                                              fontSize: ScreenUtils.relativeFontSize(
                                                context,
                                                AppConfig.truckStatusFontSizeFactor,
                                                min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                                max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                              ),
                                              color: _getStatusColor(truck.status),
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
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
            // Truck Cargo Info
            if (selectedTruck.inventory.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.1),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, size: 16, color: Colors.blue),
                          SizedBox(
                            width: ScreenUtils.relativeSize(
                              context,
                              AppConfig.spacingFactorMedium,
                            ),
                          ),
                          Text(
                            'Cargo: ${selectedTruck.currentLoad}/${selectedTruck.capacity}',
                            style: TextStyle(
                              fontSize: ScreenUtils.relativeFontSize(
                                context,
                                AppConfig.fontSizeFactorSmall,
                                min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                              ),
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: ScreenUtils.relativeSize(
                          context,
                          AppConfig.spacingFactorMedium,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: selectedTruck.inventory.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${entry.key.name}: ${entry.value}',
                              style: TextStyle(
                                fontSize: ScreenUtils.relativeFontSize(
                                  context,
                                  AppConfig.fontSizeFactorSmall,
                                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                ),
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[900],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            // Route Header with Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Route (Drag to Reorder)',
                      style: TextStyle(
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          AppConfig.fontSizeFactorMedium,
                          min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                          max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: ScreenUtils.relativeSize(
                        context,
                        AppConfig.spacingFactorLarge,
                      ),
                    ),
                    Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        GameButton(
                          onPressed: () => _showLoadCargoDialog(selectedTruck),
                          icon: Icons.inventory,
                          label: 'Load Cargo',
                          color: Colors.green,
                        ),
                        GameButton(
                          onPressed: () =>
                              _showAddStopDialog(selectedTruck, machines),
                          icon: Icons.add,
                          label: 'Add Stop',
                          color: Colors.blue,
                        ),
                        GameButton(
                          onPressed: _canGoStock(selectedTruck, routeMachines)
                              ? () => _goStock(selectedTruck)
                              : null,
                          icon: Icons.local_shipping,
                          label: 'Go Stock',
                          color: Colors.orange,
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
                      SizedBox(
                        height: ScreenUtils.relativeSize(
                          context,
                          AppConfig.spacingFactorXLarge,
                        ),
                      ),
                      Text(
                        'No stops in route',
                        style: TextStyle(
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorSmall,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(
                        height: ScreenUtils.relativeSize(
                          context,
                          AppConfig.spacingFactorMedium,
                        ),
                      ),
                      GameButton(
                        onPressed: () => _showAddStopDialog(selectedTruck, machines),
                        icon: Icons.add,
                        label: 'Add First Stop',
                        color: Colors.green,
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
                        Text(
                          'Route Efficiency',
                          style: TextStyle(
                            fontSize: ScreenUtils.relativeFontSize(
                              context,
                              AppConfig.fontSizeFactorSmall,
                              min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                              max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                            ),
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
    final quantityInt = maxQuantity > 0 ? _quantity.round().clamp(1, maxQuantity) : 0;

    return AlertDialog(
      title: Text(
        'Load Cargo - ${widget.truck.name}',
        style: TextStyle(
          fontSize: ScreenUtils.relativeFontSize(
            context,
            AppConfig.fontSizeFactorMedium,
            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
          ),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Capacity: $availableCapacity / ${widget.truck.capacity}',
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(
                  context,
                  AppConfig.fontSizeFactorNormal,
                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                ),
              ),
            ),
            SizedBox(
              height: ScreenUtils.relativeSize(
                context,
                AppConfig.spacingFactorXLarge,
              ),
            ),
            Text(
              'Select Product:',
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(
                  context,
                  AppConfig.fontSizeFactorNormal,
                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                ),
              ),
            ),
            SizedBox(
              height: ScreenUtils.relativeSize(
                context,
                AppConfig.spacingFactorMedium,
              ),
            ),
            DropdownButtonFormField<Product>(
              value: _selectedProduct,
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(
                  context,
                  AppConfig.fontSizeFactorNormal,
                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                ),
              ),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Choose a product',
                hintStyle: TextStyle(
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    AppConfig.fontSizeFactorNormal,
                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                  ),
                ),
              ),
              items: availableProducts.map((product) {
                final stock = widget.warehouse.inventory[product] ?? 0;
                return DropdownMenuItem(
                  value: product,
                  child: Text(
                    '${product.name} (Stock: $stock)',
                    style: TextStyle(
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorNormal,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
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
              SizedBox(
                height: ScreenUtils.relativeSize(
                  context,
                  AppConfig.spacingFactorXLarge,
                ),
              ),
              if (maxQuantity > 0) ...[
                // Quantity Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Quantity: ',
                        style: TextStyle(
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorNormal,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                        ),
                      ),
                      Text(
                        '$quantityInt',
                        style: TextStyle(
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorLarge,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: ScreenUtils.relativeSize(
                    context,
                    AppConfig.spacingFactorXLarge,
                  ),
                ),
                // Slider for quantity selection
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
                SizedBox(
                  height: ScreenUtils.relativeSize(
                    context,
                    AppConfig.spacingFactorXLarge,
                  ),
                ),
                // Quick increment buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildIncrementButton(10, maxQuantity),
                    _buildIncrementButton(50, maxQuantity),
                    _buildIncrementButton(100, maxQuantity),
                    _buildFullButton(maxQuantity),
                  ],
                ),
              ] else
                Text(
                  'Cannot load: Truck is full',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorNormal,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _SmallGameButton(
              onPressed: () => Navigator.of(context).pop(),
              label: 'Cancel',
              color: Colors.grey,
              icon: Icons.close,
            ),
            SizedBox(
              width: ScreenUtils.relativeSize(
                context,
                AppConfig.spacingFactorMedium,
              ),
            ),
            _SmallGameButton(
              onPressed: _selectedProduct != null && quantityInt > 0
                  ? () {
                      widget.onLoad(_selectedProduct!, quantityInt);
                      // Dialog will be closed by the onLoad callback
                    }
                  : null,
              label: 'Load',
              color: Colors.green,
              icon: Icons.check_circle,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIncrementButton(int increment, int maxQuantity) {
    final newQuantity = (_quantity + increment).clamp(1.0, maxQuantity.toDouble());
    final isEnabled = _quantity < maxQuantity;
    
    return _SmallGameButton(
      onPressed: isEnabled
          ? () {
              setState(() {
                _quantity = newQuantity;
              });
            }
          : null,
      label: '+$increment',
      color: Colors.blue,
      icon: Icons.add,
    );
  }

  Widget _buildFullButton(int maxQuantity) {
    return _SmallGameButton(
      onPressed: maxQuantity > 0
          ? () {
              setState(() {
                _quantity = maxQuantity.toDouble();
              });
            }
          : null,
      label: 'Full ($maxQuantity)',
      color: Colors.orange,
      icon: Icons.maximize,
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
          SizedBox(
            height: ScreenUtils.relativeSize(
              context,
              AppConfig.spacingFactorMedium,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: ScreenUtils.relativeFontSize(
                context,
                AppConfig.fontSizeFactorSmall,
                min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
              ),
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
          SizedBox(
            height: ScreenUtils.relativeSize(
              context,
              AppConfig.spacingFactorSmall,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: ScreenUtils.relativeFontSize(
                context,
                AppConfig.fontSizeFactorSmall,
                min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
              ),
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Smaller variant of GameButton for use in modals and tight spaces
class _SmallGameButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const _SmallGameButton({
    required this.label,
    this.onPressed,
    this.color = AppConfig.gameGreen,
    this.icon,
  });

  @override
  State<_SmallGameButton> createState() => _SmallGameButtonState();
}

class _SmallGameButtonState extends State<_SmallGameButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    
    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: AppConfig.animationDurationFast,
        margin: EdgeInsets.only(top: _isPressed ? 3 : 0),
        padding: EdgeInsets.symmetric(
          horizontal: ScreenUtils.relativeSize(
            context,
            AppConfig.smallGameButtonPaddingHorizontalFactor,
          ),
          vertical: ScreenUtils.relativeSize(
            context,
            AppConfig.smallGameButtonPaddingVerticalFactor,
          ),
        ),
        decoration: BoxDecoration(
          color: isEnabled ? widget.color : Colors.grey,
          borderRadius: BorderRadius.circular(AppConfig.smallGameButtonBorderRadius),
          boxShadow: _isPressed || !isEnabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                color: Colors.white,
                size: ScreenUtils.relativeSize(
                  context,
                  AppConfig.smallGameButtonIconSizeFactor,
                ),
              ),
              SizedBox(
                width: ScreenUtils.relativeSize(
                  context,
                  AppConfig.spacingFactorMedium,
                ),
              ),
            ],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    AppConfig.smallGameButtonFontSizeFactor,
                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                  ),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

