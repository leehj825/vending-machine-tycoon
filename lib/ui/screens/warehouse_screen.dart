import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/product.dart';
import '../../simulation/models/truck.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../widgets/market_product_card.dart';

/// Warehouse & Market Screen
class WarehouseScreen extends ConsumerWidget {
  const WarehouseScreen({super.key});

  void _showLoadTruckDialog(BuildContext context, WidgetRef ref) {
    final trucks = ref.read(trucksProvider);
    final warehouse = ref.read(warehouseProvider);
    
    if (trucks.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Trucks Available'),
          content: const Text(
              'You need to purchase a truck before you can load cargo. Go to the Route Planner to manage your fleet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    if (warehouse.inventory.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Warehouse is empty')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _LoadTruckDialog(
        trucks: trucks,
        warehouse: warehouse,
        onLoad: (truckId, product, quantity) {
          ref.read(gameControllerProvider.notifier).loadTruck(
            truckId,
            product,
            quantity,
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouse = ref.watch(warehouseProvider);
    final cash = ref.watch(cashProvider);

    // Calculate warehouse capacity
    const maxCapacity = 1000;
    final currentTotal = warehouse.inventory.values.fold<int>(
      0,
      (sum, qty) => sum + qty,
    );
    final capacityPercent = (currentTotal / maxCapacity).clamp(0.0, 1.0);

    return Scaffold(
      // AppBar removed - managed by MainScreen
      body: CustomScrollView(
        slivers: [
          // Top Section: Warehouse Status
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Warehouse Status',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showLoadTruckDialog(context, ref),
                        icon: const Icon(Icons.local_shipping),
                        label: const Text('Load Truck'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Capacity indicator
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Capacity: $currentTotal / $maxCapacity items',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: capacityPercent,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                capacityPercent > 0.9
                                    ? Colors.red
                                    : capacityPercent > 0.7
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                              minHeight: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Cash',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '\$${cash.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Current stock grid
                  if (warehouse.inventory.isNotEmpty) ...[
                    Text(
                      'Current Stock',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: warehouse.inventory.entries.map((entry) {
                        return Chip(
                          label: Text(
                            '${entry.key.name}: ${entry.value}',
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                        );
                      }).toList(),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 24),
                          SizedBox(width: 8),
                          Text('Warehouse is empty'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 1),
          ),
          // Market Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Prices',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Prices update automatically',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Prices update automatically',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Prices update automatically',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Market Product List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = Product.values[index];
                return MarketProductCard(product: product);
              },
              childCount: Product.values.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadTruckDialog extends StatefulWidget {
  final List<Truck> trucks;
  final Warehouse warehouse;
  final Function(String, Product, int) onLoad;

  const _LoadTruckDialog({
    required this.trucks,
    required this.warehouse,
    required this.onLoad,
  });

  @override
  State<_LoadTruckDialog> createState() => _LoadTruckDialogState();
}

class _LoadTruckDialogState extends State<_LoadTruckDialog> {
  late String _selectedTruckId;
  Product? _selectedProduct;
  double _quantity = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedTruckId = widget.trucks.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTruck = widget.trucks.firstWhere((t) => t.id == _selectedTruckId);
    
    // Filter products that are actually in the warehouse
    final availableProducts = Product.values
        .where((p) => (widget.warehouse.inventory[p] ?? 0) > 0)
        .toList();
        
    final availableCapacity = selectedTruck.capacity - selectedTruck.currentLoad;
    
    final maxQuantity = _selectedProduct != null
        ? [
            widget.warehouse.inventory[_selectedProduct] ?? 0,
            availableCapacity,
          ].reduce((a, b) => a < b ? a : b)
        : 0;
        
    final quantityInt = _quantity.round().clamp(1, maxQuantity > 0 ? maxQuantity : 1);

    return AlertDialog(
      title: const Text('Load Truck from Warehouse'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Truck Selector
            DropdownButtonFormField<String>(
              value: _selectedTruckId,
              decoration: const InputDecoration(
                labelText: 'Select Truck',
                border: OutlineInputBorder(),
              ),
              items: widget.trucks.map((truck) {
                final load = truck.currentLoad;
                return DropdownMenuItem(
                  value: truck.id,
                  child: Text('${truck.name} (${load}/${truck.capacity})'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTruckId = value;
                    _quantity = 1.0;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Product Selector
            if (availableProducts.isEmpty)
              const Text('Warehouse is empty!', style: TextStyle(color: Colors.red))
            else
              DropdownButtonFormField<Product>(
                value: _selectedProduct,
                decoration: const InputDecoration(
                  labelText: 'Select Product',
                  border: OutlineInputBorder(),
                ),
                items: availableProducts.map((product) {
                  final stock = widget.warehouse.inventory[product] ?? 0;
                  return DropdownMenuItem(
                    value: product,
                    child: Text('${product.name} (In Stock: $stock)'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProduct = value;
                    _quantity = 1.0;
                  });
                },
              ),
              
            if (_selectedProduct != null) ...[
              const SizedBox(height: 16),
              Text('Quantity: $quantityInt'),
              if (maxQuantity > 0)
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
                )
              else
                 const Text('No capacity or stock available', style: TextStyle(color: Colors.red)),
              if (maxQuantity > 0) ...[
                const SizedBox(height: 8),
                // Quick increment buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildIncrementButton(-10, maxQuantity),
                    _buildIncrementButton(-5, maxQuantity),
                    _buildIncrementButton(-1, maxQuantity),
                    _buildIncrementButton(1, maxQuantity),
                    _buildIncrementButton(5, maxQuantity),
                    _buildIncrementButton(10, maxQuantity),
                  ],
                ),
              ],
            ],
            
             if (selectedTruck.status != TruckStatus.idle && selectedTruck.status != TruckStatus.restocking)
               Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text(
                   'Warning: Truck is currently ${selectedTruck.status.name}',
                   style: const TextStyle(color: Colors.orange, fontSize: 12),
                 ),
               ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedProduct != null && quantityInt > 0 && maxQuantity > 0
              ? () => widget.onLoad(_selectedTruckId, _selectedProduct!, quantityInt)
              : null,
          child: const Text('Load'),
        ),
      ],
    );
  }

  Widget _buildIncrementButton(int increment, int maxQuantity) {
    final newQuantity = (_quantity + increment).clamp(1.0, maxQuantity.toDouble());
    final isEnabled = increment > 0 
        ? _quantity < maxQuantity 
        : _quantity > 1;
    
    return SizedBox(
      width: 50,
      child: OutlinedButton(
        onPressed: isEnabled
            ? () {
                setState(() {
                  _quantity = newQuantity;
                });
              }
            : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          minimumSize: const Size(40, 36),
        ),
        child: Text(
          increment > 0 ? '+$increment' : '$increment',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
