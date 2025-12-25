import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/product.dart';
import '../../state/market_provider.dart';
import '../../state/selectors.dart';
import '../../state/providers.dart';
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: priceColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: priceColor.withOpacity(0.1),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showBuyDialog(context, ref, product, price),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    _getProductImagePath(product),
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image fails to load
                      return Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[600],
                        size: 24,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Icon(trendIcon, size: 16, color: priceColor),
                        Text(
                          'Current: \$${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: priceColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BuyStockBottomSheet(
        product: product,
        unitPrice: unitPrice,
      ),
    );
  }
}

/// Bottom sheet for buying stock
class _BuyStockBottomSheet extends ConsumerStatefulWidget {
  final Product product;
  final double unitPrice;

  const _BuyStockBottomSheet({
    required this.product,
    required this.unitPrice,
  });

  @override
  ConsumerState<_BuyStockBottomSheet> createState() =>
      _BuyStockBottomSheetState();
}

class _BuyStockBottomSheetState extends ConsumerState<_BuyStockBottomSheet> {
  double _quantity = 1.0;
  static const int _maxCapacity = 1000;

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
    final availableCapacity = _maxCapacity - currentTotal;

    // Calculate max affordable quantity
    final maxAffordable = (cash / widget.unitPrice).floor();
    final maxQuantity = [maxAffordable, availableCapacity].reduce(
      (a, b) => a < b ? a : b,
    );

    final totalCost = widget.unitPrice * _quantity;
    final quantityInt = _quantity.round();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header with image
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      _getProductImagePath(widget.product),
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[600],
                          size: 28,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buy ${widget.product.name}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unit Price: \$${widget.unitPrice.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Quantity Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Quantity: ',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    '$quantityInt',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Slider for quantity selection
            Slider(
              value: _quantity.clamp(1.0, maxQuantity.toDouble()),
              min: 1.0,
              max: maxQuantity.toDouble(),
              divisions: maxQuantity > 1 ? maxQuantity - 1 : 1,
              label: quantityInt.toString(),
              onChanged: (value) {
                setState(() {
                  _quantity = value;
                });
              },
            ),
            const SizedBox(height: 16),
            // Quick increment buttons with GameButtons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildIncrementGameButton(context, 10, maxQuantity),
                _buildIncrementGameButton(context, 50, maxQuantity),
                _buildIncrementGameButton(context, 100, maxQuantity),
                _SmallGameButton(
                  onPressed: maxQuantity > 0
                      ? () {
                          setState(() {
                            _quantity = maxQuantity.toDouble();
                          });
                        }
                      : null,
                  label: 'Full ($maxQuantity)',
                  color: Colors.orange,
                  icon: Icons.maximize,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Cost:',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    '\$${totalCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
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
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Limited by warehouse capacity ($availableCapacity available)',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 12,
                  ),
                ),
              ),
            if (totalCost > cash)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Insufficient funds',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _SmallGameButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'Cancel',
                    color: Colors.grey,
                    icon: Icons.close,
                  ),
                ),
                const SizedBox(width: 12),
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
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncrementGameButton(BuildContext context, int increment, int maxQuantity) {
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
    );
  }
}

/// Smaller variant of GameButton for use in modals and tight spaces
class _SmallGameButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const _SmallGameButton({
    required this.label,
    this.onPressed,
    this.color = const Color(0xFF4CAF50),
    this.icon,
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
        margin: EdgeInsets.only(top: _isPressed ? 3 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isEnabled ? widget.color : Colors.grey,
          borderRadius: BorderRadius.circular(10),
          boxShadow: _isPressed || !isEnabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
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

