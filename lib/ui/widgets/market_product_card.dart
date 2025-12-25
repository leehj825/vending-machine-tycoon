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

  /// Get icon for product
  IconData _getProductIcon(Product product) {
    switch (product) {
      case Product.soda:
        return Icons.local_drink;
      case Product.chips:
        return Icons.fastfood;
      case Product.proteinBar:
        return Icons.fitness_center;
      case Product.coffee:
        return Icons.local_cafe;
      case Product.techGadget:
        return Icons.devices;
      case Product.sandwich:
        return Icons.lunch_dining;
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
              // Product Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getProductIcon(product),
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 24,
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
            Text(
              'Buy ${widget.product.name}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Unit Price: \$${widget.unitPrice.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyLarge,
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
            // Custom quantity track (visual representation)
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (_quantity / maxQuantity).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Quick increment buttons with GameButtons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildIncrementGameButton(context, -10, maxQuantity),
                _buildIncrementGameButton(context, -1, maxQuantity),
                _buildIncrementGameButton(context, 1, maxQuantity),
                _buildIncrementGameButton(context, 10, maxQuantity),
                GameButton(
                  onPressed: maxQuantity > 0
                      ? () {
                          setState(() {
                            _quantity = maxQuantity.toDouble();
                          });
                        }
                      : null,
                  label: 'MAX ($maxQuantity)',
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
                  child: GameButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'Cancel',
                    color: Colors.grey,
                    icon: Icons.close,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: GameButton(
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
    final isEnabled = increment > 0 
        ? _quantity < maxQuantity 
        : _quantity > 1;
    
    return GameButton(
      onPressed: isEnabled
          ? () {
              setState(() {
                _quantity = newQuantity;
              });
            }
          : null,
      label: increment > 0 ? '+$increment' : '$increment',
      color: increment > 0 ? Colors.blue : Colors.red,
      icon: increment > 0 ? Icons.add : Icons.remove,
    );
  }
}

