import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../simulation/models/machine.dart';
import '../simulation/models/product.dart';
import 'providers.dart';

/// Provider that returns the current cash amount
final cashProvider = Provider<double>((ref) {
  final gameState = ref.watch(gameStateProvider);
  return gameState.cash;
});

/// Provider that calculates total income from all machines
final totalIncomeProvider = Provider<double>((ref) {
  final machines = ref.watch(machinesProvider);
  
  return machines.fold<double>(
    0.0,
    (sum, machine) => sum + machine.currentCash,
  );
});

/// Provider that returns the number of machines with empty stock
final alertCountProvider = Provider<int>((ref) {
  final machines = ref.watch(machinesProvider);
  
  return machines.where((machine) => machine.isEmpty).length;
});

/// Provider that returns machines that need restocking (empty or low stock)
final machinesNeedingRestockProvider = Provider<List<Machine>>((ref) {
  final machines = ref.watch(machinesProvider);
  
  return machines.where((machine) => machine.needsRestock()).toList();
});

/// Provider that returns broken machines
final brokenMachinesProvider = Provider<List<Machine>>((ref) {
  final machines = ref.watch(machinesProvider);
  
  return machines.where((machine) => machine.isBroken).toList();
});

/// Provider that returns the current reputation
final reputationProvider = Provider<int>((ref) {
  final gameState = ref.watch(gameStateProvider);
  return gameState.reputation;
});

/// Provider that returns the current day count
final dayCountProvider = Provider<int>((ref) {
  final gameState = ref.watch(gameStateProvider);
  return gameState.dayCount;
});

/// Provider that returns the current hour of day
final hourOfDayProvider = Provider<int>((ref) {
  final gameState = ref.watch(gameStateProvider);
  return gameState.hourOfDay;
});

/// Provider that returns recent log messages (last 10)
final recentLogsProvider = Provider<List<String>>((ref) {
  final gameState = ref.watch(gameStateProvider);
  final logs = gameState.logMessages;
  
  if (logs.length <= 10) return logs;
  return logs.sublist(logs.length - 10);
});

/// Provider that returns whether simulation is running
/// Note: We use .notifier to access the controller instance since gameControllerProvider
/// is a StateNotifierProvider that returns the state, not the controller
final isSimulationRunningProvider = Provider<bool>((ref) {
  final controller = ref.read(gameControllerProvider.notifier);
  return controller.isSimulationRunning;
});

/// Provider that calculates total inventory value across all machines
final totalInventoryValueProvider = Provider<double>((ref) {
  final machines = ref.watch(machinesProvider);
  
  double totalValue = 0.0;
  for (final machine in machines) {
    for (final entry in machine.inventory.entries) {
      final item = entry.value;
      totalValue += item.product.basePrice * item.quantity;
    }
  }
  
  return totalValue;
});

/// Provider that returns warehouse stock for a specific product
final warehouseStockProvider = Provider.family<int, Product>((ref, product) {
  final warehouse = ref.watch(warehouseProvider);
  return warehouse.inventory[product] ?? 0;
});

/// Provider that returns total warehouse value
final warehouseValueProvider = Provider<double>((ref) {
  final warehouse = ref.watch(warehouseProvider);
  
  double totalValue = 0.0;
  for (final entry in warehouse.inventory.entries) {
    totalValue += entry.key.basePrice * entry.value;
  }
  
  return totalValue;
});

/// Provider that calculates net worth (cash + inventory + warehouse)
final netWorthProvider = Provider<double>((ref) {
  final cash = ref.watch(cashProvider);
  final inventoryValue = ref.watch(totalInventoryValueProvider);
  final warehouseValue = ref.watch(warehouseValueProvider);
  
  return cash + inventoryValue + warehouseValue;
});

