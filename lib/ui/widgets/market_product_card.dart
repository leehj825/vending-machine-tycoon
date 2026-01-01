import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/product.dart';
import '../../state/market_provider.dart';
import '../../state/selectors.dart';
import '../../state/providers.dart';
import '../../config.dart';
import '../utils/screen_utils.dart';

/// Card widget that displays a product in the market
class MarketProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback? onProductTapped;

  const MarketProductCard({
    super.key,
    required this.product,
    this.onProductTapped,
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
      case Product.freshSalad:
        return 'assets/images/items/fresh_salad.png';
      case Product.newspaper:
        return 'assets/images/items/newspaper.png';
      case Product.energyDrink:
        return 'assets/images/items/energy_drink.png';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(marketPricesProvider);
    final unitPrice = market.getPrice(product);
    final trend = market.getPriceTrend(product);

    return GestureDetector(
      onTap: () => _showBuyDialog(context, ref, product, unitPrice, onProductTapped),
      child: Card(
        elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor * 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorMedium),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge),
          ),
          child: Row(
            children: [
              // Product image
              Container(
                width: ScreenUtils.relativeSize(
                  context,
                  AppConfig.productCardImageSizeFactor,
                ),
                height: ScreenUtils.relativeSize(
                  context,
                  AppConfig.productCardImageSizeFactor,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorSmall),
                  ),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: ScreenUtils.relativeSize(context, AppConfig.borderWidthFactorSmall),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorSmall),
                  ),
                  child: Image.asset(
                    _getProductImagePath(product),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.image_not_supported,
                        size: ScreenUtils.relativeSize(
                          context,
                          AppConfig.productCardImageFallbackSizeFactor,
                        ),
                        color: Colors.grey[600],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge),
              ),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          product.name,
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
                          width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                        ),
                        Icon(
                          trend == PriceTrend.up
                              ? Icons.trending_up
                              : trend == PriceTrend.down
                                  ? Icons.trending_down
                                  : Icons.trending_flat,
                          size: ScreenUtils.relativeSize(
                            context,
                            AppConfig.productCardTrendIconSizeFactor,
                          ),
                          color: trend == PriceTrend.up
                              ? Colors.green
                              : trend == PriceTrend.down
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ],
                    ),
                    SizedBox(
                      height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall),
                    ),
                    Text(
                      '\$${unitPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          AppConfig.fontSizeFactorNormal,
                          min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                          max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                        ),
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBuyDialog(BuildContext context, WidgetRef ref, Product product, double unitPrice, VoidCallback? onProductTapped) {
    // Notify parent if callback provided (for tutorial tracking)
    onProductTapped?.call();
    
    showDialog(
      context: context,
      builder: (dialogContext) => _BuyStockDialog(
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
  double _quantity = 0.0;

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
      case Product.freshSalad:
        return 'assets/images/items/fresh_salad.png';
      case Product.newspaper:
        return 'assets/images/items/newspaper.png';
      case Product.energyDrink:
        return 'assets/images/items/energy_drink.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final warehouse = ref.watch(warehouseProvider);
    final currentTotal = warehouse.inventory.values.fold<int>(
      0,
      (sum, qty) => sum + qty,
    );
    final availableCapacity = AppConfig.warehouseMaxCapacity - currentTotal;

    // Calculate max affordable quantity
    final cash = ref.watch(cashProvider);
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
      insetPadding: EdgeInsets.all(
        ScreenUtils.relativeSize(context, AppConfig.buyDialogInsetPaddingFactor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dialogWidth = dialogMaxWidth.clamp(
            screenWidth * AppConfig.buyDialogWidthMinFactor,
            screenWidth * AppConfig.buyDialogWidthMaxFactor,
          );
          final dialogHeight = (screenHeight * AppConfig.buyDialogHeightFactor).clamp(
            screenHeight * AppConfig.buyDialogHeightMinFactor,
            screenHeight * AppConfig.buyDialogHeightMaxFactor,
          );
          final padding = dialogWidth * AppConfig.buyDialogPaddingFactor;
          final borderRadius = dialogWidth * AppConfig.buyDialogBorderRadiusFactor;

          return Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: padding * AppConfig.buyDialogHeaderPaddingVerticalFactor,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(borderRadius),
                      topRight: Radius.circular(borderRadius),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Product icon and title
                      Row(
                        children: [
                          Image.asset(
                            imagePath,
                            width: dialogWidth * AppConfig.buyDialogHeaderIconSizeFactor,
                            height: dialogWidth * AppConfig.buyDialogHeaderIconSizeFactor,
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
                          // Number pad input
                          _NumberPadInput(
                            value: quantityInt,
                            maxValue: maxQuantity,
                            onValueChanged: (value) {
                              setState(() {
                                _quantity = value.toDouble();
                              });
                            },
                            dialogWidth: null, // Use screen-based sizing to match truck cargo loading screen
                            padding: null,
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
                                  onPressed: totalCost <= cash && quantityInt > 0 && _quantity > 0
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

  // Removed - replaced with number pad
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
