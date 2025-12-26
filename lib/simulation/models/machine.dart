import 'package:freezed_annotation/freezed_annotation.dart';
import 'product.dart';
import 'zone.dart';

part 'machine.freezed.dart';

/// Machine condition states
enum MachineCondition {
  excellent,
  good,
  fair,
  poor,
  broken,
}

/// Represents inventory item with expiration tracking
@freezed
abstract class InventoryItem with _$InventoryItem {
  const factory InventoryItem({
    required Product product,
    required int quantity,
    required int dayAdded, // Game day when item was added
    @Default(0.0) double salesProgress, // Accumulator for customer interest (0.0 to 1.0+)
  }) = _InventoryItem;

  const InventoryItem._();
}

/// Extension for InventoryItem methods
extension InventoryItemExtension on InventoryItem {
  /// Check if this item has expired
  bool isExpired(int currentDay) {
    if (!product.canSpoil) return false;
    return (currentDay - dayAdded) >= product.spoilageDays;
  }

  /// Get current customer interest (clamped between 0.0 and 1.0 for UI display)
  double get customerInterest => salesProgress.clamp(0.0, 1.0);
}

/// Vending machine model
@freezed
abstract class Machine with _$Machine {
  const factory Machine({
    required String id,
    required String name,
    required Zone zone,
    required MachineCondition condition,
    /// Inventory: Map of Product to InventoryItem
    @Default({}) Map<Product, InventoryItem> inventory,
    @Default(0.0) double currentCash,
    /// Hours since last restock (for reputation penalty calculation)
    @Default(0.0) double hoursSinceRestock,
    /// Total sales count (for analytics)
    @Default(0) int totalSales,
  }) = _Machine;

  const Machine._();

  /// Get total inventory count
  int get totalInventory {
    return inventory.values.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
  }

  /// Check if machine is empty
  bool get isEmpty => totalInventory == 0;

  /// Check if machine is broken
  bool get isBroken => condition == MachineCondition.broken;

  /// Get stock level for a specific product
  int getStock(Product product) {
    return inventory[product]?.quantity ?? 0;
  }

  /// Check if machine needs restock (empty or low stock)
  bool needsRestock() {
    return isEmpty || totalInventory < 5;
  }

  /// Get hours machine has been empty (for reputation penalty)
  double get hoursEmpty {
    if (!isEmpty) return 0.0;
    return hoursSinceRestock;
  }
}

