import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../config.dart';
import '../../simulation/models/machine.dart';
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
            
            // Section C: Staff Management (Centralized)
            _buildStaffManagementSection(context, ref),
            
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge)),
            
            // Section D: Maintenance
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
                  'Business Overview',
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
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            // Top Performing Location
            _buildTopPerformingLocationCard(context, machines),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            // Get Funding Button
            _buildGetFundingButton(context, ref),
          ],
        ),
      ),
    );
  }

  /// Build Top Performing Location card
  Widget _buildTopPerformingLocationCard(BuildContext context, List<Machine> machines) {
    // Find Top Performing Location: machine with highest currentCash
    Machine? topPerformingMachine;
    double maxCash = 0.0;
    for (final machine in machines) {
      if (machine.currentCash > maxCash) {
        maxCash = machine.currentCash;
        topPerformingMachine = machine;
      }
    }

    if (topPerformingMachine != null) {
      return Card(
        color: Colors.teal.shade50,
        elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor * 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.008)),
        ),
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
      );
    } else {
      return Card(
        color: Colors.grey.shade100,
        elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor * 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.008)),
        ),
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
      );
    }
  }

  /// Build Get Funding button (Rewarded Ad)
  Widget _buildGetFundingButton(BuildContext context, WidgetRef ref) {
    final adManager = ref.watch(rewardedAdProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    
    // Disable for macOS (rewarded ads not supported)
    final isMacOS = !kIsWeb && Platform.isMacOS;
    final isDisabled = isMacOS;

    return Container(
      decoration: BoxDecoration(
        gradient: isDisabled
            ? LinearGradient(
                colors: [Colors.grey.shade400, Colors.grey.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.008)),
        boxShadow: isDisabled
            ? []
            : [
                BoxShadow(
                  color: Colors.green.shade300.withOpacity(0.3),
                  blurRadius: ScreenUtils.relativeSize(context, 0.01),
                  offset: Offset(0, ScreenUtils.relativeSize(context, 0.002)),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white),
                          SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                          Text(
                            'Rewarded ads are not available on macOS',
                            style: TextStyle(
                              fontSize: ScreenUtils.relativeFontSize(
                                context,
                                AppConfig.fontSizeFactorNormal,
                                min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.grey.shade700,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              : () {
            if (adManager.isReady) {
              adManager.showAd(
                onReward: () {
                  controller.addCash(1000);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                          Text(
                            'Received \$1,000 from investors!',
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
                        ],
                      ),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.search, color: Colors.white),
                      SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                      Text(
                        'Searching for investors...',
                        style: TextStyle(
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorNormal,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange.shade700,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              adManager.loadAd();
            }
          },
          borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.008)),
          child: Padding(
            padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorMedium),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDisabled ? Icons.block : Icons.play_circle_filled,
                  color: Colors.white.withOpacity(isDisabled ? 0.6 : 1.0),
                  size: ScreenUtils.relativeSizeClamped(
                    context,
                    0.05,
                    min: ScreenUtils.getSmallerDimension(context) * 0.04,
                    max: ScreenUtils.getSmallerDimension(context) * 0.06,
                  ),
                ),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Text(
                  'Get Funding',
                  style: TextStyle(
                    color: Colors.white.withOpacity(isDisabled ? 0.6 : 1.0),
                    fontWeight: FontWeight.bold,
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorLarge,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                  ),
                ),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                    vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isDisabled ? 0.2 : 0.3),
                    borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.01)),
                  ),
                  child: Text(
                    '\$1,000',
                    style: TextStyle(
                      color: Colors.white.withOpacity(isDisabled ? 0.6 : 1.0),
                      fontWeight: FontWeight.bold,
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorNormal,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  /// Section C: Staff Management - Centralized HQ Control
  Widget _buildStaffManagementSection(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final trucks = ref.watch(trucksProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    
    // Calculate assigned drivers
    final assignedDrivers = trucks.where((t) => t.hasDriver).length;
    final totalDrivers = gameState.driverPoolCount + assignedDrivers;

    return Card(
      elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor),
      color: Colors.blue.shade50,
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
                Icon(Icons.people, color: Colors.blue.shade700, size: ScreenUtils.relativeSizeClamped(
                  context,
                  0.04,
                  min: ScreenUtils.getSmallerDimension(context) * 0.03,
                  max: ScreenUtils.getSmallerDimension(context) * 0.05,
                )),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Text(
                  'Staff Management',
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
            
            // Drivers Section
            _buildStaffRow(
              context,
              'Truck Drivers',
              '$totalDrivers Drivers',
              '$assignedDrivers assigned, ${gameState.driverPoolCount} in pool',
              '\$50/day',
              totalDrivers, // Use total drivers (pool + assigned) for fire button enable/disable
              onHire: () => controller.hireDriver(),
              onFire: () => controller.fireDriver(),
            ),
            
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
            
            // Mechanics Section
            _buildStaffRow(
              context,
              'Mechanics',
              '${gameState.mechanicCount} Mechanics',
              'Auto-repairs 1 machine/hr',
              '\$50/day',
              gameState.mechanicCount,
              onHire: () => controller.hireMechanic(),
              onFire: () => controller.fireMechanic(),
            ),
            
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
            
            // Purchasing Agents Section (hiring only, settings in Market)
            _buildStaffRow(
              context,
              'Purchasing Agents',
              '${gameState.purchasingAgentCount} Agents',
              'Auto-buys 50 items/hr (configure in Market)',
              '\$50/day',
              gameState.purchasingAgentCount,
              onHire: () => controller.hirePurchasingAgent(),
              onFire: () => controller.firePurchasingAgent(),
            ),
            
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            
            // Payout Summary Section
            _buildPayoutSummarySection(context, ref),
          ],
        ),
      ),
    );
  }

  /// Build a staff row with hire/fire buttons
  Widget _buildStaffRow(
    BuildContext context,
    String title,
    String count,
    String subtitle,
    String salary,
    int currentCount,
    {required VoidCallback onHire, required VoidCallback onFire}
  ) {
    return Card(
      color: Colors.white,
      elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor * 0.5),
      child: Padding(
        padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorSmall),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
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
                      SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                      Text(
                        '—',
                        style: TextStyle(
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorNormal,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
                      Text(
                        count,
                        style: TextStyle(
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorNormal,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorSmall,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    salary,
                    style: TextStyle(
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorSmall,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle, color: currentCount > 0 ? Colors.red : Colors.grey),
                  onPressed: currentCount > 0 ? onFire : null,
                  iconSize: ScreenUtils.relativeSizeClamped(
                    context,
                    0.04,
                    min: ScreenUtils.getSmallerDimension(context) * 0.03,
                    max: ScreenUtils.getSmallerDimension(context) * 0.05,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: Colors.green),
                  onPressed: onHire,
                  iconSize: ScreenUtils.relativeSizeClamped(
                    context,
                    0.04,
                    min: ScreenUtils.getSmallerDimension(context) * 0.03,
                    max: ScreenUtils.getSmallerDimension(context) * 0.05,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build payout summary section showing hourly costs
  Widget _buildPayoutSummarySection(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final trucks = ref.watch(trucksProvider);
    
    // Calculate staff salaries per hour
    const double driverSalaryPerDay = 50.0;
    const double mechanicSalaryPerDay = 50.0;
    const double purchasingAgentSalaryPerDay = 50.0;
    const int hoursPerDay = 24;
    
    final assignedDrivers = trucks.where((t) => t.hasDriver).length;
    final totalDrivers = gameState.driverPoolCount + assignedDrivers;
    final driverSalaryPerHour = (totalDrivers * driverSalaryPerDay) / hoursPerDay;
    final mechanicSalaryPerHour = (gameState.mechanicCount * mechanicSalaryPerDay) / hoursPerDay;
    final purchasingAgentSalaryPerHour = (gameState.purchasingAgentCount * purchasingAgentSalaryPerDay) / hoursPerDay;
    final totalStaffSalaryPerHour = driverSalaryPerHour + mechanicSalaryPerHour + purchasingAgentSalaryPerHour;
    
    // Calculate gas costs per hour
    // Gas cost per tick = movementSpeed * gasPrice (when truck moves)
    // Per hour = per tick * ticksPerHour
    // We estimate based on trucks with drivers (they're the ones moving)
    const double movementSpeed = 0.15; // From AppConfig
    const double gasPrice = 0.05; // From AppConfig
    const int ticksPerHour = 125; // From AppConfig
    final trucksWithDrivers = trucks.where((t) => t.hasDriver).length;
    // Estimate: trucks move about 50% of the time when they have drivers
    final estimatedGasCostPerHour = trucksWithDrivers * movementSpeed * gasPrice * ticksPerHour * 0.5;
    
    final totalCostPerHour = totalStaffSalaryPerHour + estimatedGasCostPerHour;
    
    return Card(
      elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor),
      color: Colors.orange.shade50,
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
                Icon(Icons.account_balance_wallet, color: Colors.orange.shade700, size: ScreenUtils.relativeSizeClamped(
                  context,
                  0.04,
                  min: ScreenUtils.getSmallerDimension(context) * 0.03,
                  max: ScreenUtils.getSmallerDimension(context) * 0.05,
                )),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Text(
                  'Hourly Operating Costs',
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorLarge,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            
            // Staff Salaries
            _buildCostRow(
              context,
              'Staff Salaries',
              totalStaffSalaryPerHour,
              [
                if (totalDrivers > 0) 'Drivers: \$${(driverSalaryPerHour).toStringAsFixed(2)}/hr',
                if (gameState.mechanicCount > 0) 'Mechanics: \$${(mechanicSalaryPerHour).toStringAsFixed(2)}/hr',
                if (gameState.purchasingAgentCount > 0) 'Agents: \$${(purchasingAgentSalaryPerHour).toStringAsFixed(2)}/hr',
              ],
            ),
            
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
            
            // Gas Costs
            _buildCostRow(
              context,
              'Truck Gas Costs',
              estimatedGasCostPerHour,
              [
                if (trucksWithDrivers > 0) '${trucksWithDrivers} truck${trucksWithDrivers > 1 ? 's' : ''} with drivers',
                if (trucksWithDrivers == 0) 'No trucks with drivers',
              ],
            ),
            
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            
            Divider(),
            
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Cost/Hour',
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
                Text(
                  '\$${totalCostPerHour.toStringAsFixed(2)}/hr',
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorMedium,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a cost row for the payout summary
  Widget _buildCostRow(
    BuildContext context,
    String title,
    double cost,
    List<String> details,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    AppConfig.fontSizeFactorNormal,
                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (details.isNotEmpty) ...[
                SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny)),
                ...details.map((detail) => Text(
                  detail,
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorSmall,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                    color: Colors.grey.shade600,
                  ),
                )),
              ],
            ],
          ),
        ),
        Text(
          '\$${cost.toStringAsFixed(2)}/hr',
          style: TextStyle(
            fontSize: ScreenUtils.relativeFontSize(
              context,
              AppConfig.fontSizeFactorNormal,
              min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
              max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
            ),
            fontWeight: FontWeight.w600,
            color: Colors.orange.shade700,
          ),
        ),
      ],
    );
  }
}

