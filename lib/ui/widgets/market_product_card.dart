import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/product.dart';
import '../../state/market_provider.dart';
import '../../state/selectors.dart';
import '../../state/providers.dart';
import '../../config.dart';
import '../utils/screen_utils.dart';
import 'game_button.dart';

/// Card widget that displays a product in the market
class MarketProductCard extends ConsumerWidget {
  final Product product;

  const MarketProductCard({
    super.key,
    required this.product,
  });

  /// Get image asset path for product
  String _getProductImagePath(Product product) {
    switch (product) {
      case Product.soda:
        return 'assets/images/items/soda.png';
      case Product.chips:
        return 'assets/images/items/chips.png';
      case Product.proteinBar:
        return 'assets/images/items/protein_bar.png';
      case Product.coffee:
        return 'assets/images/items/coffee.png';
      case Product.techGadget:
        return 'assets/images/items/tech_gadget.png';
      case Product.sandwich:
        return 'assets/images/items/sandwich.png';
    }
  }

  /// Get color based on price trend
  Color _getPriceColor(PriceTrend trend) {
    switch (trend) {
      case PriceTrend.up:
        return Colors.red;
      case PriceTrend.down:
        return Colors.green;
      case PriceTrend.stable:
        return Colors.grey;
    }
  }

  /// Get trend icon
  IconData _getTrendIcon(PriceTrend trend) {
    switch (trend) {
      case PriceTrend.up:
        return Icons.trending_up;
      case PriceTrend.down:
        return Icons.trending_down;
      case PriceTrend.stable:
        return Icons.trending_flat;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = ref.watch(productMarketPriceProvider(product));
    final trend = ref.watch(priceTrendProvider(product));
    final priceColor = _getPriceColor(trend);
    final trendIcon = _getTrendIcon(trend);

    final cardBorderRadius = ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall) * 2;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge), vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(
          color: priceColor.withValues(alpha: 0.3),
          width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny),
        ),
        boxShadow: [
          BoxShadow(
            color: priceColor.withValues(alpha: 0.1),
            offset: Offset(0, ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 2),
            blurRadius: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 4,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        onTap: () => _showBuyDialog(context, ref, product, price),
        child: Padding(
          padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
          child: Row(
            children: [
              // Product Image
              Container(
                width: ScreenUtils.relativeSize(context, AppConfig.productCardImageSizeFactor),
                height: ScreenUtils.relativeSize(context, AppConfig.productCardImageSizeFactor),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 4),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 4),
                  child: Image.asset(
                    _getProductImagePath(product),
                    width: ScreenUtils.relativeSize(context, AppConfig.productCardImageSizeFactor),
                    height: ScreenUtils.relativeSize(context, AppConfig.productCardImageSizeFactor),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image fails to load
                      return Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[600],
                        size: ScreenUtils.relativeSize(context, AppConfig.productCardImageFallbackSizeFactor),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
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
                    SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 2,
                      children: [
                        Icon(trendIcon, size: ScreenUtils.relativeSize(context, AppConfig.productCardTrendIconSizeFactor), color: priceColor),
                        Text(
                          'Current: \$${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: priceColor,
                            fontWeight: FontWeight.w500,
                            fontSize: ScreenUtils.relativeFontSize(
                              context,
                              AppConfig.fontSizeFactorSmall,
                              min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                              max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
              // Buy Button
              GameButton(
                onPressed: () => _showBuyDialog(context, ref, product, price),
                label: 'Buy',
                color: Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBuyDialog(
    BuildContext context,
    WidgetRef ref,
    Product product,
    double unitPrice,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _BuyStockDialog(
        product: product,
        unitPrice: unitPrice,
      ),
    );
  }
}

/// Dialog for buying stock (similar to machine status popup)
class _BuyStockDialog extends ConsumerStatefulWidget {
  final Product product;
  final double unitPrice;

  const _BuyStockDialog({
    required this.product,
    required this.unitPrice,
  });

  @override
  ConsumerState<_BuyStockDialog> createState() =>
      _BuyStockDialogState();
}

class _BuyStockDialogState extends ConsumerState<_BuyStockDialog> {
  double _quantity = 1.0;

  /// Get image asset path for product
  String _getProductImagePath(Product product) {
    switch (product) {
      case Product.soda:
        return 'assets/images/items/soda.png';
      case Product.chips:
        return 'assets/images/items/chips.png';
      case Product.proteinBar:
        return 'assets/images/items/protein_bar.png';
      case Product.coffee:
        return 'assets/images/items/coffee.png';
      case Product.techGadget:
        return 'assets/images/items/tech_gadget.png';
      case Product.sandwich:
        return 'assets/images/items/sandwich.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cash = ref.watch(cashProvider);
    final warehouse = ref.watch(warehouseProvider);
    final currentTotal = warehouse.inventory.values.fold<int>(
      0,
      (sum, qty) => sum + qty,
    );
    final availableCapacity = AppConfig.warehouseMaxCapacity - currentTotal;

    // Calculate max affordable quantity
    final maxAffordable = (cash / widget.unitPrice).floor();
    final maxQuantity = [maxAffordable, availableCapacity].reduce(
      (a, b) => a < b ? a : b,
    );

    final totalCost = widget.unitPrice * _quantity;
    final quantityInt = _quantity.round();
    
    // Calculate dialog dimensions (compact, similar to bottom sheet)
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogMaxWidth = screenWidth * AppConfig.buyDialogWidthFactor;
    
    final imagePath = _getProductImagePath(widget.product);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.buyDialogInsetPaddingFactor)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use the actual constrained width for sizing
          final dialogWidth = constraints.maxWidth;
          final borderRadius = dialogWidth * AppConfig.buyDialogBorderRadiusFactor;
          final padding = dialogWidth * AppConfig.buyDialogPaddingFactor;
          
          return Container(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: screenHeight * AppConfig.buyDialogHeightFactor,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon, title, and close button
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: padding * AppConfig.buyDialogHeaderPaddingVerticalFactor,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon and title
                      Row(
                        children: [
                          Image.asset(
                            imagePath,
                            width: dialogWidth * AppConfig.buyDialogHeaderIconSizeFactor,
                            height: dialogWidth * AppConfig.buyDialogHeaderIconSizeFactor,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_not_supported,
                                size: dialogWidth * AppConfig.buyDialogHeaderIconSizeFactor,
                                color: Colors.grey[600],
                              );
                            },
                          ),
                          SizedBox(width: padding * AppConfig.buyDialogHeaderTitleSpacingFactor),
                          Text(
                            'Buy ${widget.product.name}',
                            style: TextStyle(
                              fontSize: dialogWidth * AppConfig.buyDialogHeaderTitleFontSizeFactor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Close button
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.black,
                          size: dialogWidth * AppConfig.buyDialogCloseButtonSizeFactor,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.all(padding * AppConfig.buyDialogCloseButtonPaddingFactor),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content section
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit Price: \$${widget.unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: dialogWidth * AppConfig.buyDialogUnitPriceFontSizeFactor,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: padding),
                          // Quantity Display
                          Container(
                            padding: EdgeInsets.all(padding * AppConfig.buyDialogQuantityContainerPaddingFactor),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(borderRadius * AppConfig.buyDialogQuantityBorderRadiusFactor),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                width: padding * AppConfig.buyDialogQuantityBorderWidthFactor,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Quantity: ',
                                  style: TextStyle(
                                    fontSize: dialogWidth * AppConfig.buyDialogQuantityLabelFontSizeFactor,
                                  ),
                                ),
                                Text(
                                  '$quantityInt',
                                  style: TextStyle(
                                    fontSize: dialogWidth * AppConfig.buyDialogQuantityValueFontSizeFactor,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: padding),
                          // Slider for quantity selection
                          Slider(
                            value: _quantity.clamp(AppConfig.buyDialogSliderMinValue, maxQuantity.toDouble()),
                            min: AppConfig.buyDialogSliderMinValue,
                            max: maxQuantity.toDouble(),
                            divisions: maxQuantity > 1 ? maxQuantity - 1 : 1,
                            label: quantityInt.toString(),
                            onChanged: (value) {
                              setState(() {
                                _quantity = value;
                              });
                            },
                          ),
                          SizedBox(height: padding * AppConfig.buyDialogSliderSpacingFactor),
                          // Quick increment buttons
                          Wrap(
                            spacing: padding * AppConfig.buyDialogIncrementButtonSpacingFactor,
                            runSpacing: padding * AppConfig.buyDialogIncrementButtonSpacingFactor,
                            alignment: WrapAlignment.center,
                            children: AppConfig.buyDialogIncrementValues.map((increment) =>
                              _buildIncrementGameButton(context, increment, maxQuantity, dialogWidth, padding),
                            ).toList(),
                          ),
                          SizedBox(height: padding),
                          Container(
                            padding: EdgeInsets.all(padding * AppConfig.buyDialogTotalCostContainerPaddingFactor),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(borderRadius * AppConfig.buyDialogTotalCostBorderRadiusFactor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Cost:',
                                  style: TextStyle(
                                    fontSize: dialogWidth * AppConfig.buyDialogTotalCostLabelFontSizeFactor,
                                  ),
                                ),
                                Text(
                                  '\$${totalCost.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: dialogWidth * AppConfig.buyDialogTotalCostValueFontSizeFactor,
                                    fontWeight: FontWeight.bold,
                                    color: totalCost > cash
                                        ? Colors.red
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (maxQuantity < maxAffordable)
                            Padding(
                              padding: EdgeInsets.only(top: padding * AppConfig.buyDialogWarningSpacingFactor),
                              child: Text(
                                'Limited by warehouse capacity ($availableCapacity available)',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: dialogWidth * AppConfig.buyDialogWarningFontSizeFactor,
                                ),
                              ),
                            ),
                          if (totalCost > cash)
                            Padding(
                              padding: EdgeInsets.only(top: padding * AppConfig.buyDialogWarningSpacingFactor),
                              child: Text(
                                'Insufficient funds',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: dialogWidth * AppConfig.buyDialogWarningFontSizeFactor,
                                ),
                              ),
                            ),
                          SizedBox(height: padding),
                          Row(
                            children: [
                              Expanded(
                                child: _SmallGameButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  label: 'Cancel',
                                  color: Colors.grey,
                                  icon: Icons.close,
                                  dialogWidth: dialogWidth,
                                  padding: padding,
                                ),
                              ),
                              SizedBox(width: padding * AppConfig.buyDialogActionButtonSpacingFactor),
                              Expanded(
                                flex: 2,
                                child: _SmallGameButton(
                                  onPressed: totalCost <= cash && quantityInt > 0
                                      ? () {
                                          ref
                                              .read(gameControllerProvider.notifier)
                                              .buyStock(
                                                widget.product, 
                                                quantityInt,
                                                unitPrice: widget.unitPrice,
                                              );
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Purchased $quantityInt ${widget.product.name}',
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  label: 'Confirm Purchase',
                                  color: Colors.green,
                                  icon: Icons.check_circle,
                                  dialogWidth: dialogWidth,
                                  padding: padding,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncrementGameButton(BuildContext context, int increment, int maxQuantity, double dialogWidth, double padding) {
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
      dialogWidth: dialogWidth,
      padding: padding,
    );
  }
}

/// Smaller variant of GameButton for use in modals and tight spaces
class _SmallGameButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final double? dialogWidth;
  final double? padding;

  const _SmallGameButton({
    required this.label,
    this.onPressed,
    this.color = const Color(0xFF4CAF50),
    this.icon,
    this.dialogWidth,
    this.padding,
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
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(top: _isPressed ? (widget.padding != null ? widget.padding! * AppConfig.buyDialogButtonPressedMarginFactor : ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny)) : 0),
        padding: EdgeInsets.symmetric(
          horizontal: widget.padding != null ? widget.padding! * AppConfig.buyDialogButtonPaddingHorizontalFactor : ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge),
          vertical: widget.padding != null ? widget.padding! * AppConfig.buyDialogButtonPaddingVerticalFactor : ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
        ),
        decoration: BoxDecoration(
          color: isEnabled ? widget.color : Colors.grey,
          borderRadius: BorderRadius.circular(widget.padding != null ? widget.padding! * AppConfig.buyDialogButtonBorderRadiusFactor : ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
          boxShadow: _isPressed || !isEnabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: Offset(0, widget.padding != null ? widget.padding! * AppConfig.buyDialogButtonShadowOffsetFactor : ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny)),
                    blurRadius: 0,
                  ),
                ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: widget.padding != null ? widget.padding! * AppConfig.buyDialogButtonBorderWidthFactor : ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny) * 0.75),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                color: Colors.white,
                size: widget.dialogWidth != null
                    ? widget.dialogWidth! * AppConfig.buyDialogButtonIconSizeFactor
                    : ScreenUtils.relativeSize(context, AppConfig.productCardTrendIconSizeFactor),
              ),
              SizedBox(width: widget.padding != null ? widget.padding! * AppConfig.buyDialogButtonIconSpacingFactor : ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            ],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.dialogWidth != null
                      ? widget.dialogWidth! * AppConfig.buyDialogButtonFontSizeFactor
                      : ScreenUtils.relativeFontSize(
                          context,
                          AppConfig.fontSizeFactorSmall,
                          min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                          max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                        ),
                  letterSpacing: AppConfig.buyDialogButtonLetterSpacing,
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

