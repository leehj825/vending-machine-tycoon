import '../engine.dart';
import '../models/product.dart';
import '../../state/game_log_entry.dart';
import '../../state/providers.dart'; // Import Warehouse
import 'simulation_system.dart';
import 'dart:math' as math;

class PurchasingSystem implements SimulationSystem {
  @override
  SimulationState update(SimulationState state, GameTime time) {
    if (time.minute != 0) return state; // Only run hourly

    final result = _processPurchasingAgents(
      state.cash,
      state.warehouse,
      state.purchasingAgentCount,
      state.purchasingAgentTargetInventory,
      time,
    );

    final currentMessages = List<GameLogEntry>.from(state.pendingMessages);
    currentMessages.addAll(result.messages);

    return state.copyWith(
      cash: result.cash,
      warehouse: result.warehouse,
      pendingMessages: currentMessages,
    );
  }

  /// Process purchasing agents
  ({double cash, Warehouse warehouse, List<GameLogEntry> messages}) _processPurchasingAgents(
    double currentCash,
    Warehouse currentWarehouse,
    int purchasingAgentCount,
    Map<Product, int> purchasingAgentTargetInventory,
    GameTime time,
  ) {
    if (purchasingAgentCount <= 0) {
      return (cash: currentCash, warehouse: currentWarehouse, messages: []);
    }

    var updatedCash = currentCash;
    var updatedWarehouseInventory = Map<Product, int>.from(currentWarehouse.inventory);
    var messages = <GameLogEntry>[];
    const int itemsPerAgentPerHour = 50;
    final totalItemsToBuy = purchasingAgentCount * itemsPerAgentPerHour;
    int itemsBought = 0;

    for (final product in Product.values) {
      if (itemsBought >= totalItemsToBuy) break;

      final currentStock = updatedWarehouseInventory[product] ?? 0;
      final targetStock = purchasingAgentTargetInventory[product] ?? 0;

      if (targetStock <= 0) continue;

      if (currentStock < (targetStock * 0.5)) {
        final deficit = targetStock - currentStock;
        final itemsToBuy = math.min(deficit, totalItemsToBuy - itemsBought);

        if (itemsToBuy > 0) {
          final costPerItem = product.basePrice * 0.4;
          final totalCost = itemsToBuy * costPerItem;

          if (updatedCash >= totalCost) {
            updatedWarehouseInventory[product] = currentStock + itemsToBuy;
            updatedCash -= totalCost;
            itemsBought += itemsToBuy;

            if (itemsBought == itemsToBuy) {
              messages.add(GameLogEntry(
                type: LogType.purchasingAgentBuy,
                timestamp: time,
                data: {
                  'amount': itemsToBuy,
                  'product': product.name,
                }
              ));
            }
          }
        }
      }
    }

    return (
      cash: updatedCash,
      warehouse: Warehouse(inventory: updatedWarehouseInventory),
      messages: messages,
    );
  }
}
