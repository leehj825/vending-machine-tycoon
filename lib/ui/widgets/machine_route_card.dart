import 'package:flutter/material.dart';
import '../../simulation/models/machine.dart';
import '../../config.dart';
import '../theme/zone_ui.dart';
import '../utils/screen_utils.dart';

/// Card widget that displays a machine in a route list
class MachineRouteCard extends StatelessWidget {
  final Machine machine;
  final VoidCallback onRemove;

  const MachineRouteCard({
    super.key,
    required this.machine,
    required this.onRemove,
  });

  /// Get stock level color
  Color _getStockColor(int stock) {
    if (stock == 0) return Colors.red;
    if (stock < 5) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final zoneIcon = machine.zone.type.icon;
    final zoneColor = machine.zone.type.color;
    final stock = machine.totalInventory;
    final stockColor = _getStockColor(stock);
    
    final cardBorderRadius = ScreenUtils.relativeSize(context, AppConfig.machineRouteCardBorderRadiusFactor);
    final cardBorderWidth = ScreenUtils.relativeSize(context, AppConfig.machineRouteCardBorderWidthFactor);
    final cardShadowOffset = ScreenUtils.relativeSize(context, AppConfig.machineRouteCardShadowOffsetFactor);
    final cardShadowBlur = ScreenUtils.relativeSize(context, AppConfig.machineRouteCardShadowBlurFactor);
    final cardPadding = ScreenUtils.relativeSize(context, AppConfig.machineRouteCardPaddingFactor);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardMarginHorizontalFactor),
        vertical: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardMarginVerticalFactor),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(
          color: zoneColor.withOpacity(0.5),
          width: cardBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: zoneColor.withOpacity(0.1),
            offset: Offset(0, cardShadowOffset),
            blurRadius: cardShadowBlur,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        onTap: () {}, // Can be used for future tap actions
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            children: [
              // Zone Icon
              Container(
                width: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardIconContainerSizeFactor),
                height: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardIconContainerSizeFactor),
                decoration: BoxDecoration(
                  color: zoneColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: zoneColor.withOpacity(0.5),
                    width: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardIconContainerBorderWidthFactor),
                  ),
                ),
                child: Icon(
                  zoneIcon,
                  color: zoneColor,
                  size: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardIconSizeFactor),
                ),
              ),
              SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardIconSpacingFactor)),
              // Machine Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      machine.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardTitleFontSizeFactor),
                      ),
                    ),
                    SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardTextSpacingFactor)),
                    Text(
                      'Zone: ${machine.zone.type.name.toUpperCase()}',
                      style: TextStyle(
                        fontSize: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardZoneFontSizeFactor),
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardTextSpacingFactor)),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardInventoryIconSizeFactor),
                          color: stockColor,
                        ),
                        SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardInventoryIconSpacingFactor)),
                        Text(
                          'Stock: $stock items',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.w600,
                            fontSize: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardStockFontSizeFactor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Remove Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    ScreenUtils.relativeSize(context, AppConfig.machineRouteCardRemoveButtonBorderRadiusFactor),
                  ),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardRemoveButtonBorderWidthFactor),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: ScreenUtils.relativeSize(context, AppConfig.machineRouteCardRemoveIconSizeFactor),
                  ),
                  onPressed: onRemove,
                  tooltip: 'Remove from route',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


