import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import '../../state/providers.dart';
import '../../simulation/models/machine.dart';
import '../../simulation/models/truck.dart';
import '../../simulation/models/product.dart';
import '../../config.dart';
import '../../services/sound_service.dart';
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
        },
      ),
    );
  }

  /// Check if truck can go stock (has items and machines have room)
  bool _canGoStock(Truck truck, List<Machine> routeMachines) {
    // Check if truck is already doing a route (traveling or restocking)
    if (truck.status != TruckStatus.idle) return false;
    
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
    
    // Play truck sound when "Go Stock" is pressed
    SoundService().playTruckSound();
    
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
    // Show pending route if it exists (when truck is moving or just became idle)
    // Otherwise show current route
    final routeToDisplay = selectedTruck != null
        ? (selectedTruck.pendingRoute.isNotEmpty
            ? selectedTruck.pendingRoute
            : selectedTruck.route)
        : <String>[];
    
    final routeMachines = selectedTruck != null && machines.isNotEmpty
        ? routeToDisplay
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

    // Calculate route stats (use displayed route)
    final totalDistance = selectedTruck != null
        ? _calculateRouteDistance(routeToDisplay, machines)
        : 0.0;
    final fuelCost = totalDistance * AppConfig.fuelCostPerUnit;
    final efficiencyRating = selectedTruck != null
        ? _getEfficiencyRating(totalDistance, routeToDisplay.length)
        : 'N/A';

    // Calculate dynamic truck price (base price + 500 per existing truck)
    final controller = ref.read(gameControllerProvider.notifier);
    final truckPrice = controller.getTruckPrice();

    return Scaffold(
      // AppBar removed - managed by MainScreen
      body: CustomScrollView(
        slivers: [
          // Top Section: Truck Selector
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ScreenUtils.relativeSize(context, AppConfig.paddingMediumFactor),
                      vertical: ScreenUtils.relativeSize(context, AppConfig.paddingSmallFactor),
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
                    child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(
                              horizontal: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
                            ),
                            itemCount: trucks.length + 1, // +1 for Buy Truck button
                            itemBuilder: (context, index) {
                              // Last item is always the Buy Truck button
                              if (index == trucks.length) {
                                return _BuyTruckButton(
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
                                  onPressed: () {
                                    controller.buyTruck();
                                  },
                                  price: truckPrice,
                                );
                              }
                              
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
                                  borderRadius: BorderRadius.circular(
                                    ScreenUtils.relativeSize(context, AppConfig.truckCardBorderRadiusFactor),
                                  ),
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
                                            offset: Offset(
                                              0,
                                              ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                                            ),
                                            blurRadius: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.grey.withValues(alpha: 0.1),
                                            offset: Offset(
                                              0,
                                              ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 2,
                                            ),
                                            blurRadius: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
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
                                          borderRadius: BorderRadius.circular(
                                            ScreenUtils.relativeSize(context, AppConfig.truckIconContainerBorderRadiusFactor),
                                          ),
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
                                            borderRadius: BorderRadius.circular(
                                              ScreenUtils.relativeSize(context, AppConfig.truckStatusBorderRadiusFactor),
                                            ),
                                            border: Border.all(
                                              color: _getStatusColor(truck.status).withValues(alpha: 0.5),
                                              width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny),
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
          SliverToBoxAdapter(
            child: Divider(
              height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny),
            ),
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
              Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final padding = ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge);
                  final maxItemWidth = screenWidth * AppConfig.truckCargoMaxItemWidthFactor;
                  
                  final containerWidth = screenWidth - (padding * 2);
                  
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: padding,
                        vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
                      ),
                      child: SizedBox(
                        width: containerWidth,
                        child: Container(
                          padding: EdgeInsets.all(padding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge),
                          ),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.5),
                            width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.1),
                              offset: Offset(
                                0,
                                ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                              ),
                              blurRadius: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LayoutBuilder(
                                  builder: (context, rowConstraints) {
                                    // Use relative icon size
                                    final iconSize = ScreenUtils.relativeSize(context, AppConfig.iconSizeSmallFactor);
                                    final spacing = AppConfig.spacingFactorMedium * ScreenUtils.getSmallerDimension(context);
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.inventory_2,
                                          size: iconSize,
                                          color: Colors.blue,
                                        ),
                                        SizedBox(width: spacing),
                                        Flexible(
                                          child: Text(
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
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                            SizedBox(
                              height: ScreenUtils.relativeSize(
                                context,
                                AppConfig.spacingFactorMedium,
                              ),
                            ),
                            Wrap(
                              spacing: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                              runSpacing: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                              children: selectedTruck.inventory.entries.map((entry) {
                                final itemText = '${entry.key.name}: ${entry.value}';
                                return Container(
                                  constraints: BoxConstraints(
                                    maxWidth: maxItemWidth,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                                    vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
                                    ),
                                    border: Border.all(
                                      color: Colors.blue.withValues(alpha: 0.3),
                                      width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny),
                                    ),
                                  ),
                                  child: Text(
                                    itemText,
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
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Route Header with Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(
                  ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge),
                ),
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
                      spacing: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 2,
                      runSpacing: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 2,
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
                        size: ScreenUtils.relativeSize(context, AppConfig.routeListEmptyIconSizeFactor),
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
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * AppConfig.routeListMaxHeightFactor,
                  child: ReorderableListView.builder(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
                      vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
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
                padding: EdgeInsets.all(
                  ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge),
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                      offset: Offset(
                        0,
                        -ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 2,
                      ),
                    ),
                  ],
                ),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(
                      ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Route Efficiency',
                          style: TextStyle(
                            fontSize: ScreenUtils.relativeFontSize(
                              context,
                              AppConfig.routeEfficiencyTitleFontSizeFactor,
                              min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                              max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
                        ),
                        Builder(
                          builder: (context) {
                            return Row(
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
                            );
                          },
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
  double _quantity = 0.0;

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
                color: Colors.black,
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
                  color: Colors.black,
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
                      color: Colors.black,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProduct = value;
                  _quantity = 0.0;
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
                // Number pad input
                _NumberPadInput(
                  value: quantityInt,
                  maxValue: maxQuantity,
                  onValueChanged: (value) {
                    setState(() {
                      _quantity = value.toDouble();
                    });
                  },
                  dialogWidth: null, // Use screen-based sizing for load cargo dialog
                  padding: null,
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
              onPressed: _selectedProduct != null && quantityInt > 0 && _quantity > 0
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

  // Removed - replaced with number pad
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
          Icon(
            icon,
            size: ScreenUtils.relativeSize(context, AppConfig.efficiencyStatIconSizeFactor),
            color: valueColor ?? Colors.grey[700],
          ),
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
                AppConfig.routeEfficiencyValueFontSizeFactor,
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
                AppConfig.routeEfficiencyLabelFontSizeFactor,
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
        margin: EdgeInsets.only(
          top: _isPressed
              ? ScreenUtils.relativeSize(context, AppConfig.routePlannerSmallButtonPressedMarginFactor)
              : 0,
        ),
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
          borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.smallGameButtonBorderRadiusFactor)),
          boxShadow: _isPressed || !isEnabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: Offset(
                      0,
                      ScreenUtils.relativeSize(context, AppConfig.routePlannerSmallButtonShadowOffsetFactor),
                    ),
                    blurRadius: 0,
                  ),
                ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: ScreenUtils.relativeSize(context, AppConfig.routePlannerSmallButtonBorderWidthFactor),
          ),
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

/// Custom Buy Truck button styled like GameButton with vertical layout
class _BuyTruckButton extends StatefulWidget {
  final double width;
  final EdgeInsets margin;
  final VoidCallback? onPressed;
  final double price;

  const _BuyTruckButton({
    required this.width,
    required this.margin,
    this.onPressed,
    required this.price,
  });

  @override
  State<_BuyTruckButton> createState() => _BuyTruckButtonState();
}

class _BuyTruckButtonState extends State<_BuyTruckButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return Container(
      width: widget.width,
      margin: widget.margin,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppConfig.animationDurationFast,
          margin: EdgeInsets.only(
            top: _isPressed
                ? ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny)
                : 0,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: ScreenUtils.relativeSize(
              context,
              AppConfig.gameButtonPaddingHorizontalFactor,
            ),
            vertical: ScreenUtils.relativeSize(
              context,
              AppConfig.gameButtonPaddingVerticalFactor,
            ),
          ),
          decoration: BoxDecoration(
            color: isEnabled ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.gameButtonBorderRadiusFactor)),
            boxShadow: _isPressed || !isEnabled
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: Offset(
                        0,
                        ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                      ),
                      blurRadius: 0,
                    ),
                  ],
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                color: Colors.white,
                size: ScreenUtils.relativeSize(
                  context,
                  AppConfig.gameButtonIconSizeFactor * AppConfig.gameButtonIconSizeMultiplier,
                ),
              ),
              SizedBox(
                height: ScreenUtils.relativeSize(
                  context,
                  AppConfig.spacingFactorSmall,
                ),
              ),
              Text(
                '\$${widget.price.toInt()}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    AppConfig.gameButtonFontSizeFactor,
                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                  ),
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Number pad input widget for entering quantities
class _NumberPadInput extends StatefulWidget {
  final int value;
  final int maxValue;
  final ValueChanged<int> onValueChanged;
  final double? dialogWidth;
  final double? padding;

  const _NumberPadInput({
    required this.value,
    required this.maxValue,
    required this.onValueChanged,
    this.dialogWidth,
    this.padding,
  });

  @override
  State<_NumberPadInput> createState() => _NumberPadInputState();
}

class _NumberPadInputState extends State<_NumberPadInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value > 0 ? widget.value.toString() : '');
  }

  @override
  void didUpdateWidget(_NumberPadInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNumberTap(String number) {
    final currentText = _controller.text;
    final newText = currentText.isEmpty ? number : currentText + number;
    final newValue = int.tryParse(newText) ?? 0;
    
    if (newValue <= widget.maxValue) {
      _controller.text = newText;
      widget.onValueChanged(newValue);
    }
  }

  void _onSetAll() {
    _controller.text = widget.maxValue.toString();
    widget.onValueChanged(widget.maxValue);
  }

  void _onClearAll() {
    _controller.text = '';
    widget.onValueChanged(0);
  }

  double _getSize(double baseSize) {
    if (widget.dialogWidth != null && widget.padding != null) {
      return widget.dialogWidth! * baseSize;
    }
    return ScreenUtils.relativeSize(context, baseSize);
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = _getSize(AppConfig.numberPadButtonSizeFactor);
    final fontSize = widget.dialogWidth != null 
        ? widget.dialogWidth! * AppConfig.numberPadButtonFontSizeFactor
        : ScreenUtils.relativeFontSize(context, AppConfig.fontSizeFactorNormal);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text field to display/edit value
        Container(
          padding: EdgeInsets.all(_getSize(AppConfig.numberPadTextFieldPaddingFactor)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(_getSize(AppConfig.numberPadTextFieldBorderRadiusFactor)),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: _getSize(AppConfig.numberPadTextFieldBorderWidthFactor),
            ),
          ),
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: '0',
              hintStyle: TextStyle(
                color: Colors.grey[400],
              ),
            ),
            onChanged: (value) {
              if (value.isEmpty) {
                widget.onValueChanged(0);
                return;
              }
              final intValue = int.tryParse(value) ?? 0;
              if (intValue <= widget.maxValue) {
                widget.onValueChanged(intValue);
              } else {
                _controller.text = widget.maxValue.toString();
                widget.onValueChanged(widget.maxValue);
              }
            },
          ),
        ),
        SizedBox(height: _getSize(AppConfig.numberPadSpacingFactor)),
        // Number pad grid
        Container(
          padding: EdgeInsets.all(_getSize(AppConfig.numberPadContainerPaddingFactor)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(_getSize(AppConfig.numberPadContainerBorderRadiusFactor)),
            border: Border.all(
              color: Colors.grey[300]!,
              width: _getSize(AppConfig.numberPadContainerBorderWidthFactor),
            ),
          ),
          child: Column(
            children: [
              // Number buttons 1-9
              for (int row = 0; row < 3; row++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int col = 1; col <= 3; col++)
                      _NumberButton(
                        label: (row * 3 + col).toString(),
                        size: buttonSize,
                        fontSize: fontSize,
                        onTap: () => _onNumberTap((row * 3 + col).toString()),
                      ),
                  ],
                ),
              // Bottom row: 0, All (set to max), AC (clear all)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _NumberButton(
                    label: '0',
                    size: buttonSize,
                    fontSize: fontSize,
                    onTap: () => _onNumberTap('0'),
                  ),
                  _NumberButton(
                    label: 'All',
                    size: buttonSize,
                    fontSize: fontSize,
                    onTap: _onSetAll,
                  ),
                  _NumberButton(
                    label: 'AC',
                    size: buttonSize,
                    fontSize: fontSize,
                    onTap: _onClearAll,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Individual number button for the number pad
class _NumberButton extends StatelessWidget {
  final String label;
  final double size;
  final double fontSize;
  final VoidCallback onTap;

  const _NumberButton({
    required this.label,
    required this.size,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(size * AppConfig.numberPadButtonPaddingMultiplier),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(size * AppConfig.numberPadButtonBorderRadiusMultiplier),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: size * AppConfig.numberPadButtonBorderWidthMultiplier,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
