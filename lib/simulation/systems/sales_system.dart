import '../engine.dart';
import '../models/machine.dart';
import '../models/product.dart';
import '../models/research.dart';
import '../models/zone.dart';
import '../../config.dart';
import 'simulation_system.dart';

class SalesSystem implements SimulationSystem {
  @override
  SimulationState update(SimulationState state, GameTime time) {
    // Process machine sales based on demand math
    final machines = state.machines;
    final currentReputation = state.reputation;
    var totalSales = 0;
    final reputationMultiplier = _calculateReputationMultiplier(currentReputation);
    final rushMultiplier = state.rushMultiplier; // Get rush multiplier from state

    // Check for Premium Branding research
    final hasPremiumBranding = state.unlockedResearch.contains(ResearchType.premiumBranding);

    final updatedMachines = machines.map((machine) {
      if (machine.isUnderMaintenance) {
        return machine.copyWith(
          hoursSinceRestock: machine.hoursSinceRestock + (1.0 / SimulationConstants.ticksPerHour), // 1 tick = 1/ticksPerHour hours
        );
      }

      if (machine.isBroken || machine.isEmpty) {
        return machine.copyWith(
          hoursSinceRestock: machine.hoursSinceRestock + (1.0 / SimulationConstants.ticksPerHour), // 1 tick = 1/ticksPerHour hours
        );
      }

      var updatedInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var updatedCash = machine.currentCash;
      var salesCount = machine.totalSales;
      var hoursSinceRestock = machine.hoursSinceRestock;

      for (final product in Product.values) {
        final stock = machine.getStock(product);
        if (stock == 0) continue;

        final item = updatedInventory[product]!;

        final baseDemand = product.baseDemand;
        final zoneMultiplier = machine.zone.getDemandMultiplier(time.hour);
        final trafficMultiplier = machine.zone.trafficMultiplier;

        final saleChancePerHour = baseDemand * zoneMultiplier * trafficMultiplier * reputationMultiplier * rushMultiplier;
        final saleChance = saleChancePerHour / SimulationConstants.ticksPerHour;

        final clampedChance = saleChance.clamp(0.0, 1.0);
        final newSalesProgress = item.salesProgress + clampedChance;

        if (newSalesProgress >= 1.0) {
          final newQuantity = item.quantity - 1;
          final remainingProgress = newSalesProgress - 1.0;

          updatedInventory[product] = item.copyWith(
            quantity: newQuantity.clamp(0, double.infinity).toInt(),
            salesProgress: remainingProgress,
          );

          // Apply Premium Branding price increase (10%)
          double price = product.basePrice;
          if (hasPremiumBranding) {
            price *= 1.10;
          }

          updatedCash += price;
          salesCount++;
          totalSales++;
        } else {
          updatedInventory[product] = item.copyWith(salesProgress: newSalesProgress);
        }
      }
      hoursSinceRestock += (1.0 / SimulationConstants.ticksPerHour);

      return machine.copyWith(
        inventory: updatedInventory,
        currentCash: updatedCash,
        totalSales: salesCount,
        hoursSinceRestock: hoursSinceRestock,
      );
    }).toList();

    // Only apply reputation GAIN here. Penalty is handled by ReputationSystem.
    final reputationGain = totalSales * SimulationConstants.reputationGainPerSale;
    var updatedReputation = ((state.reputation + reputationGain).clamp(0, 1000)).round();

    return state.copyWith(
      machines: updatedMachines,
      reputation: updatedReputation,
    );
  }

  /// Calculate reputation multiplier for sales bonus
  double _calculateReputationMultiplier(int reputation) {
    final bonus = (reputation / 100).floor() * AppConfig.reputationBonusPer100;
    return (1.0 + bonus.clamp(0.0, AppConfig.maxReputationBonus));
  }
}
