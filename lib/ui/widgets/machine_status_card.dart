import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../../simulation/models/machine.dart';
import '../../state/providers.dart';
import '../../config.dart';
import '../theme/zone_ui.dart';
import '../utils/screen_utils.dart';
import 'game_button.dart';
import '../../game/mini_games/customer_preview_game.dart';

/// Widget that displays a machine's status in a card format
class MachineStatusCard extends ConsumerStatefulWidget {
  final Machine machine;

  const MachineStatusCard({
    super.key,
    required this.machine,
  });

  @override
  ConsumerState<MachineStatusCard> createState() => _MachineStatusCardState();
}

class _MachineStatusCardState extends ConsumerState<MachineStatusCard> {
  bool _isExpanded = false;

  /// Calculate stock level percentage (0.0 to 1.0)
  double _getStockLevel(Machine machine) {
    const maxCapacity = AppConfig.machineMaxCapacity;
    final currentStock = machine.totalInventory.toDouble();
    return (currentStock / maxCapacity).clamp(0.0, 1.0);
  }

  /// Get color for stock level indicator
  Color _getStockColor(Machine machine) {
    final level = _getStockLevel(machine);
    if (level > 0.5) return Colors.green;
    if (level > 0.2) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final machine = widget.machine;
    final stockLevel = _getStockLevel(machine);
    final stockColor = _getStockColor(machine);
    final zoneIcon = machine.zone.type.icon;
    final zoneColor = machine.zone.type.color;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge),
        vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorLarge)),
        border: Border.all(
          color: zoneColor.withValues(alpha: 0.5), // Colored border based on zone
          width: ScreenUtils.relativeSize(context, AppConfig.cardBorderWidthFactor),
        ),
        boxShadow: [
          BoxShadow(
            color: zoneColor.withValues(alpha: 0.1),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorLarge)), // ripple matches shape
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Machine image with customer animation
              LayoutBuilder(
                builder: (context, constraints) {
                  final imageHeight = ScreenUtils.relativeSize(context, 0.15);
                  final hasCash = machine.currentCash > 0;
                  final imagePath = 'assets/images/machine${hasCash ? '_with_money' : '_without_money'}.png';
                  
                  return Container(
                    height: imageHeight,
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge)),
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorMedium)),
                    ),
                    child: Stack(
                      children: [
                        // Machine image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorMedium)),
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: imageHeight,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: imageHeight,
                                color: Colors.grey[300],
                                child: Icon(
                                  zoneIcon,
                                  color: zoneColor,
                                  size: imageHeight * 0.5,
                                ),
                              );
                            },
                          ),
                        ),
                        // Customer animation overlay
                        Positioned.fill(
                          child: GameWidget<CustomerPreviewGame>.controlled(
                            gameFactory: () => CustomerPreviewGame(
                              zoneType: machine.zone.type,
                              cardWidth: constraints.maxWidth,
                              cardHeight: imageHeight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Main row with machine info
              Row(
                children: [
                  // Left: Zone Icon
                  Container(
                    width: ScreenUtils.relativeSize(context, 0.048),
                    height: ScreenUtils.relativeSize(context, 0.048),
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      zoneIcon,
                      color: zoneColor,
                      size: ScreenUtils.relativeSize(context, 0.024),
                    ),
                  ),
                  SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
                  // Center: Machine Info and Stock Level
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          machine.name,
                          style: TextStyle(
                            fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorNormal,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
                        // Stock Level Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stock: ${machine.totalInventory} items',
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
                            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                            LinearProgressIndicator(
                              value: stockLevel,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(stockColor),
                              minHeight: ScreenUtils.relativeSize(context, 0.006),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
                  // Right: Cash Display and Expand Icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge), vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.008)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cash',
                              style: TextStyle(
                                fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorTiny,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '\$${machine.currentCash.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorNormal,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),
              // Expanded section with detailed stock and retrieve button
              if (_isExpanded) ...[
                Divider(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge * 1.5)),
                // Stock details
                Text(
                  'Stock Details:',
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
                SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge)),
                if (machine.inventory.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
                    child: Text(
                      'Empty',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                else
                  ...machine.inventory.values.map((item) => Padding(
                    padding: EdgeInsets.only(bottom: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.product.name,
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
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium), vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.012)),
                              ),
                              child: Text(
                                '${item.quantity}',
                                style: TextStyle(
                                  fontSize: ScreenUtils.relativeFontSize(
                                    context,
                                    AppConfig.fontSizeFactorNormal,
                                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                        // Customer Interest Progress Bar
                        LinearProgressIndicator(
                          value: item.customerInterest,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            item.customerInterest > 0.7 
                              ? Colors.green 
                              : item.customerInterest > 0.4 
                                ? Colors.orange 
                                : Colors.blue,
                          ),
                          minHeight: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny * 8),
                        ),
                      ],
                    ),
                  )),
                SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
                // Retrieve cash button
                if (machine.currentCash > 0)
                  SizedBox(
                    width: double.infinity,
                    child: GameButton(
                      onPressed: () {
                        ref.read(gameControllerProvider.notifier).retrieveCash(machine.id);
                        // Optionally close the expanded view after retrieving
                        // setState(() {
                        //   _isExpanded = false;
                        // });
                      },
                      icon: Icons.account_balance_wallet,
                      label: 'Retrieve \$${machine.currentCash.toStringAsFixed(2)}',
                      color: Colors.green,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge)),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.008)),
                    ),
                    child: Center(
                      child: Text(
                        'No cash to retrieve',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorSmall,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

