import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../config.dart';
import '../../simulation/models/machine.dart';
import '../../simulation/models/product.dart';
import '../utils/screen_utils.dart';

/// CEO Dashboard - Main HQ screen displaying empire overview
class HQDashboard extends ConsumerWidget {
  const HQDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final machines = ref.watch(machinesProvider);
    final totalInventoryValue = ref.watch(totalInventoryValueProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: ScreenUtils.relativePadding(context, 0.02),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section A: Empire Health (Header)
            _buildEmpireHealthSection(context, ref, gameState, machines, totalInventoryValue),
            
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge)),
            
            // Section B: Sales Analytics
            _buildSalesAnalyticsSection(context, ref, machines),
            
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge)),
            
            // Section C: Maintenance
            _buildNeedsAttentionSection(context, machines),
          ],
        ),
      ),
    );
  }

  /// Section A: Empire Health - 3 Stat Cards
  Widget _buildEmpireHealthSection(
    BuildContext context,
    WidgetRef ref,
    gameState,
    List<Machine> machines,
    double totalInventoryValue,
  ) {
    // Calculate Net Worth: player.wallet + (machineCount * machineCost) + totalInventoryValue
    final machineCount = machines.length;
    final machineCost = _calculateAverageMachineCost(machines);
    final netWorth = gameState.cash + (machineCount * machineCost) + totalInventoryValue;
    
    // Calculate Active Machines: working machines / total machines
    final workingMachines = machines.where((m) => !m.isBroken).length;
    final totalMachines = machines.length;
    
    // Calculate Total Inventory: sum of currentStock across all machines
    final totalInventory = machines.fold<int>(
      0,
      (sum, machine) => sum + machine.totalInventory,
    );

    return Card(
      elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor),
      child: Padding(
        padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue.shade700, size: ScreenUtils.relativeSizeClamped(
                  context,
                  0.04,
                  min: ScreenUtils.getSmallerDimension(context) * 0.03,
                  max: ScreenUtils.getSmallerDimension(context) * 0.05,
                )),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Text(
                  'Business Health',
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorLarge,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Net Worth',
                    '\$${netWorth.toStringAsFixed(2)}',
                    Icons.attach_money,
                  ),
                ),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Active Machines',
                    '$workingMachines / $totalMachines',
                    Icons.local_grocery_store,
                  ),
                ),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Inventory',
                    '$totalInventory',
                    Icons.inventory,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a single stat card with vibrant colors
  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    // Determine colors based on label
    Color cardColor;
    Color iconColor;
    Color valueColor;
    
    if (label == 'Net Worth') {
      cardColor = Colors.blue.shade50;
      iconColor = Colors.blue.shade700;
      valueColor = Colors.blue.shade900;
    } else if (label == 'Active Machines') {
      cardColor = Colors.green.shade50;
      iconColor = Colors.green.shade700;
      valueColor = Colors.green.shade900;
    } else {
      cardColor = Colors.purple.shade50;
      iconColor = Colors.purple.shade700;
      valueColor = Colors.purple.shade900;
    }
    
    return Card(
      color: cardColor,
      elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor * 0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.012)),
      ),
      child: Padding(
        padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorSmall),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: ScreenUtils.relativeSizeClamped(
                  context,
                  0.045,
                  min: ScreenUtils.getSmallerDimension(context) * 0.035,
                  max: ScreenUtils.getSmallerDimension(context) * 0.055,
                ),
                color: iconColor,
              ),
            ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
            Text(
              value,
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(
                  context,
                  AppConfig.fontSizeFactorMedium,
                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                ),
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny)),
            Text(
              label,
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(
                  context,
                  AppConfig.fontSizeFactorSmall,
                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                ),
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Section B: Sales Analytics
  Widget _buildSalesAnalyticsSection(
    BuildContext context,
    WidgetRef ref,
    List<Machine> machines,
  ) {
    final gameState = ref.watch(gameStateProvider);
    
    // Find Best Selling Item: product with highest global soldCount
    Product? bestSellingProduct;
    int bestSellingCount = 0;
    for (final entry in gameState.productSalesCount.entries) {
      if (entry.value > bestSellingCount) {
        bestSellingCount = entry.value;
        bestSellingProduct = entry.key;
      }
    }
    
    // Find Top Performing Location: machine with highest currentCash
    Machine? topPerformingMachine;
    double maxCash = 0.0;
    for (final machine in machines) {
      if (machine.currentCash > maxCash) {
        maxCash = machine.currentCash;
        topPerformingMachine = machine;
      }
    }

    return Card(
      elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor),
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.012)),
      ),
      child: Padding(
        padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.amber.shade800, size: ScreenUtils.relativeSizeClamped(
                  context,
                  0.04,
                  min: ScreenUtils.getSmallerDimension(context) * 0.03,
                  max: ScreenUtils.getSmallerDimension(context) * 0.05,
                )),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Text(
                  'Sales Analytics',
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorLarge,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            if (bestSellingProduct != null)
              Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: Colors.orange.shade900,
                      size: ScreenUtils.relativeSizeClamped(
                        context,
                        0.03,
                        min: ScreenUtils.getSmallerDimension(context) * 0.02,
                        max: ScreenUtils.getSmallerDimension(context) * 0.04,
                      ),
                    ),
                  ),
                  title: Text(
                    'Best Selling Item',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorMedium,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                  subtitle: Text(
                    '${bestSellingProduct.name}: $bestSellingCount sold',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorNormal,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                ),
              )
            else
              Card(
                color: Colors.grey.shade100,
                child: ListTile(
                  leading: Icon(
                    Icons.star_border,
                    color: Colors.grey,
                    size: ScreenUtils.relativeSizeClamped(
                      context,
                      0.03,
                      min: ScreenUtils.getSmallerDimension(context) * 0.02,
                      max: ScreenUtils.getSmallerDimension(context) * 0.04,
                    ),
                  ),
                  title: Text(
                    'Best Selling Item',
                    style: TextStyle(
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorMedium,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                  subtitle: Text(
                    'No sales data yet',
                    style: TextStyle(
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorNormal,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
            if (topPerformingMachine != null)
              Card(
                color: Colors.teal.shade50,
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.place,
                      color: Colors.teal.shade900,
                      size: ScreenUtils.relativeSizeClamped(
                        context,
                        0.03,
                        min: ScreenUtils.getSmallerDimension(context) * 0.02,
                        max: ScreenUtils.getSmallerDimension(context) * 0.04,
                      ),
                    ),
                  ),
                  title: Text(
                    'Top Performing Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorMedium,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                  subtitle: Text(
                    '${topPerformingMachine.name}: \$${maxCash.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorNormal,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                ),
              )
            else
              Card(
                color: Colors.grey.shade100,
                child: ListTile(
                  leading: Icon(
                    Icons.location_off,
                    color: Colors.grey,
                    size: ScreenUtils.relativeSizeClamped(
                      context,
                      0.03,
                      min: ScreenUtils.getSmallerDimension(context) * 0.02,
                      max: ScreenUtils.getSmallerDimension(context) * 0.04,
                    ),
                  ),
                  title: Text(
                    'Top Performing Location',
                    style: TextStyle(
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorMedium,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                  subtitle: Text(
                    'No machines yet',
                    style: TextStyle(
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorNormal,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Section C: Maintenance
  Widget _buildNeedsAttentionSection(
    BuildContext context,
    List<Machine> machines,
  ) {
    // Filter machines: currentStock < 10 OR status == broken
    final needsAttention = machines.where((machine) {
      return machine.totalInventory < 10 || machine.isBroken;
    }).toList();

    return Card(
      elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor),
      color: needsAttention.isEmpty ? Colors.green.shade50 : Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.012)),
      ),
      child: Padding(
        padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  needsAttention.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: needsAttention.isEmpty ? Colors.green.shade700 : Colors.red.shade700,
                  size: ScreenUtils.relativeSizeClamped(
                    context,
                    0.04,
                    min: ScreenUtils.getSmallerDimension(context) * 0.03,
                    max: ScreenUtils.getSmallerDimension(context) * 0.05,
                  ),
                ),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Text(
                  'Maintenance',
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorLarge,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                    fontWeight: FontWeight.bold,
                    color: needsAttention.isEmpty ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            if (needsAttention.isEmpty)
              Card(
                color: Colors.green.shade100,
                elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor * 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.008)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                    decoration: BoxDecoration(
                      color: Colors.green.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade900,
                      size: ScreenUtils.relativeSizeClamped(
                        context,
                        0.03,
                        min: ScreenUtils.getSmallerDimension(context) * 0.02,
                        max: ScreenUtils.getSmallerDimension(context) * 0.04,
                      ),
                    ),
                  ),
                  title: Text(
                    'All Systems Operational',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorNormal,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                  subtitle: Text(
                    'All machines are working and stock levels are adequate',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorSmall,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...needsAttention.map((machine) {
                String issue;
                IconData icon;
                Color color;
                Color bgColor;
                
                if (machine.isBroken) {
                  issue = 'Broken';
                  icon = Icons.error_outline;
                  color = Colors.red.shade700;
                  bgColor = Colors.red.shade100;
                } else {
                  issue = 'Critically Low Stock (${machine.totalInventory} items)';
                  icon = Icons.inventory_2_outlined;
                  color = Colors.orange.shade700;
                  bgColor = Colors.orange.shade100;
                }
                
                return Card(
                  color: bgColor,
                  margin: EdgeInsets.only(bottom: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                  elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor * 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.008)),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: ScreenUtils.relativeSizeClamped(
                          context,
                          0.025,
                          min: ScreenUtils.getSmallerDimension(context) * 0.02,
                          max: ScreenUtils.getSmallerDimension(context) * 0.03,
                        ),
                      ),
                    ),
                    title: Text(
                      machine.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          AppConfig.fontSizeFactorNormal,
                          min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                          max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      issue,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          AppConfig.fontSizeFactorSmall,
                          min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                          max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  /// Calculate average machine cost (for net worth calculation)
  double _calculateAverageMachineCost(List<Machine> machines) {
    if (machines.isEmpty) return 0.0;
    
    // Calculate average based on zone types
    double totalCost = 0.0;
    for (final machine in machines) {
      totalCost += MachinePrices.getPrice(machine.zone.type);
    }
    return totalCost / machines.length;
  }
}

