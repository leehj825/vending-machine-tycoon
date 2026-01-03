import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/product.dart';
import '../../simulation/models/truck.dart';
import '../../state/providers.dart';
import '../../config.dart';
import '../widgets/market_product_card.dart';
import '../utils/screen_utils.dart';

/// Warehouse & Market Screen
class WarehouseScreen extends ConsumerStatefulWidget {
  const WarehouseScreen({super.key});

  @override
  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends ConsumerState<WarehouseScreen> with TickerProviderStateMixin {
  bool _showTutorial = false;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    
    // Flash animation - continuously flashing (same as machine interior tutorial)
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flashAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _flashController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Check if this is the first time opening market with cash
    _checkFirstTimeWithCash();
  }
  
  /// Check if this is the first time opening market with cash
  void _checkFirstTimeWithCash() {
    final gameState = ref.read(gameStateProvider);
    // Only show tutorial if cash is available
    if (gameState.cash <= 0) return;
    
    final hasSeenTutorial = gameState.hasSeenMarketTutorial;
    
    if (!hasSeenTutorial) {
      if (mounted) {
        setState(() {
          _showTutorial = true;
        });
        _flashController.repeat(reverse: true);
      }
    }
  }
  
  /// Mark the tutorial as seen
  void _markTutorialAsSeen() {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.state = controller.state.copyWith(hasSeenMarketTutorial: true);
    if (mounted) {
      setState(() {
        _showTutorial = false;
      });
      _flashController.stop();
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _showLoadTruckDialog() {
    final warehouse = ref.read(warehouseProvider);
    final trucks = ref.read(trucksProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    if (trucks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No trucks available',
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
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => _LoadTruckDialog(
        trucks: trucks,
        warehouse: warehouse,
        onLoad: (truckId, product, quantity) {
          Navigator.of(dialogContext).pop();
          controller.loadTruck(truckId, product, quantity);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouse = ref.watch(warehouseProvider);

    // Calculate warehouse capacity
    const maxCapacity = AppConfig.warehouseMaxCapacity;
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
              padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warehouse Status',
                    style: TextStyle(
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorLarge,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ScreenUtils.relativeSize(context, 0.02)),
                  // Capacity indicator
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Capacity: $currentTotal / $maxCapacity items',
                              style: TextStyle(
                                fontSize: ScreenUtils.relativeFontSize(
                                  context,
                                  AppConfig.fontSizeFactorNormal,
                                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                ),
                              ),
                            ),
                            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
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
                  SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
                  // Load Truck Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showLoadTruckDialog,
                      icon: Icon(
                        Icons.local_shipping,
                        size: ScreenUtils.relativeSizeClamped(
                          context,
                          0.06,
                          min: ScreenUtils.getSmallerDimension(context) * 0.04,
                          max: ScreenUtils.getSmallerDimension(context) * 0.08,
                        ),
                      ),
                      label: Text(
                        'Load Truck',
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
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge)),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
                  // Current stock grid
                  if (warehouse.inventory.isNotEmpty) ...[
                    Text(
                      'Current Stock',
                      style: TextStyle(
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          AppConfig.fontSizeFactorLarge,
                          min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                          max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: warehouse.inventory.entries.map((entry) {
                        return Chip(
                          label: Text(
                            '${entry.key.name}: ${entry.value}',
                            style: TextStyle(
                              fontSize: ScreenUtils.relativeFontSize(
                                context,
                                AppConfig.fontSizeFactorSmall,
                                min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                              ),
                            ),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                        );
                      }).toList(),
                    ),
                  ] else
                    Container(
                      padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorSmall)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: ScreenUtils.relativeSizeClamped(
                              context,
                              0.08, // Match dashboard icon size
                              min: ScreenUtils.getSmallerDimension(context) * 0.06,
                              max: ScreenUtils.getSmallerDimension(context) * 0.12,
                            ),
                          ),
                          SizedBox(width: ScreenUtils.relativeSize(context, 0.01)),
                          Text(
                            'Warehouse is empty',
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
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Divider(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny)),
          ),
          // Purchasing Agent Target Inventory Section
          SliverToBoxAdapter(
            child: _buildPurchasingAgentTargetSection(context, ref),
          ),
          SliverToBoxAdapter(
            child: Divider(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny)),
          ),
          // Market Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorXLarge)),
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
                          style: TextStyle(
                            fontSize: ScreenUtils.relativeFontSize(
                              context,
                              AppConfig.fontSizeFactorLarge,
                              min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                              max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Prices update automatically',
                          style: TextStyle(
                            fontSize: ScreenUtils.relativeFontSize(
                              context,
                              AppConfig.fontSizeFactorNormal,
                              min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                              max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                            ),
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
                        SnackBar(
                          content: Text(
                            'Prices update automatically',
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
                    },
                  ),
                ],
              ),
            ),
          ),
          // Tutorial message (similar to rush sell message)
          if (_showTutorial)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge)),
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenUtils.relativeSize(context, AppConfig.spacingFactorLarge),
                  vertical: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorMedium)),
                  border: Border.all(
                    color: Colors.white,
                    width: ScreenUtils.relativeSize(context, AppConfig.borderWidthFactorSmall * 2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.white,
                      size: ScreenUtils.relativeSize(context, 0.04),
                    ),
                    SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                    Flexible(
                      child: Text(
                        'Tap product cards to buy items for your warehouse!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorSmall,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
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
                final isFirstProduct = index == 0;
                return Stack(
                  children: [
                    MarketProductCard(
                      product: product,
                      onProductTapped: _showTutorial ? () => _markTutorialAsSeen() : null,
                    ),
                    // Blinking circle indicator on first product (first time only)
                    if (_showTutorial && isFirstProduct)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _flashAnimation,
                          builder: (context, child) {
                            final flashAlpha = _flashAnimation.value;
                            final screenWidth = MediaQuery.of(context).size.width;
                            final cardHeight = ScreenUtils.relativeSize(context, 0.15);
                            
                            return Center(
                              child: IgnorePointer(
                                child: Container(
                                  width: screenWidth * 0.9,
                                  height: cardHeight * 1.2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorMedium),
                                    ),
                                    border: Border.all(
                                      color: Colors.blue.withValues(alpha: flashAlpha),
                                      width: 4.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withValues(alpha: 0.5 * flashAlpha),
                                        blurRadius: 12.0 * flashAlpha,
                                        spreadRadius: 2.0 * flashAlpha,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
              childCount: Product.values.length,
            ),
          ),
        ],
      ),
    );
  }

  /// Build purchasing agent target inventory section
  Widget _buildPurchasingAgentTargetSection(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final agentCount = gameState.purchasingAgentCount;
    final targetInventory = gameState.purchasingAgentTargetInventory;

    if (agentCount == 0) {
      return Container(
        padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorMedium),
        child: Card(
          color: Colors.grey.shade100,
          child: Padding(
            padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorMedium),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600),
                SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                Expanded(
                  child: Text(
                    'Hire Purchasing Agents in HQ to enable auto-buying',
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
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorMedium),
      child: Card(
        elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor),
        color: Colors.purple.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, 0.012)),
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorMedium),
          childrenPadding: EdgeInsets.only(
            left: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
            right: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
            bottom: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium),
          ),
          leading: Icon(Icons.shopping_cart, color: Colors.purple.shade700, size: ScreenUtils.relativeSizeClamped(
            context,
            0.04,
            min: ScreenUtils.getSmallerDimension(context) * 0.03,
            max: ScreenUtils.getSmallerDimension(context) * 0.05,
          )),
          title: Text(
            'Purchasing Agent Settings',
            style: TextStyle(
              fontSize: ScreenUtils.relativeFontSize(
                context,
                AppConfig.fontSizeFactorLarge,
                min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
              ),
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade900,
            ),
          ),
          subtitle: Text(
            '$agentCount Agent${agentCount > 1 ? 's' : ''} - Auto-buys when inventory < 50% of target',
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
          children: [
            Text(
              'Target Inventory Levels',
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
            ...Product.values.map((product) {
              final currentTarget = targetInventory[product] ?? 0;
              return Padding(
                padding: EdgeInsets.only(bottom: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
                child: Card(
                  color: Colors.white,
                  elevation: ScreenUtils.relativeSize(context, AppConfig.cardElevationFactor * 0.5),
                  child: Padding(
                    padding: ScreenUtils.relativePadding(context, AppConfig.spacingFactorSmall),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
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
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, size: ScreenUtils.relativeSizeClamped(
                                context,
                                0.025,
                                min: ScreenUtils.getSmallerDimension(context) * 0.02,
                                max: ScreenUtils.getSmallerDimension(context) * 0.03,
                              )),
                              onPressed: currentTarget > 0 
                                ? () => controller.setPurchasingAgentTarget(product, currentTarget - 10)
                                : null,
                              padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny)),
                              constraints: BoxConstraints(),
                            ),
                            Container(
                              width: ScreenUtils.relativeSizeClamped(
                                context,
                                0.1,
                                min: ScreenUtils.getSmallerDimension(context) * 0.08,
                                max: ScreenUtils.getSmallerDimension(context) * 0.12,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$currentTarget',
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
                            ),
                            IconButton(
                              icon: Icon(Icons.add, size: ScreenUtils.relativeSizeClamped(
                                context,
                                0.025,
                                min: ScreenUtils.getSmallerDimension(context) * 0.02,
                                max: ScreenUtils.getSmallerDimension(context) * 0.03,
                              )),
                              onPressed: () => controller.setPurchasingAgentTarget(product, currentTarget + 10),
                              padding: EdgeInsets.all(ScreenUtils.relativeSize(context, AppConfig.spacingFactorTiny)),
                              constraints: BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
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
}

/// Dialog for loading cargo onto a truck from warehouse
class _LoadTruckDialog extends ConsumerStatefulWidget {
  final List<Truck> trucks;
  final Warehouse warehouse;
  final void Function(String truckId, Product product, int quantity) onLoad;

  const _LoadTruckDialog({
    required this.trucks,
    required this.warehouse,
    required this.onLoad,
  });

  @override
  ConsumerState<_LoadTruckDialog> createState() => _LoadTruckDialogState();
}

class _LoadTruckDialogState extends ConsumerState<_LoadTruckDialog> {
  Truck? _selectedTruck;
  Product? _selectedProduct;
  double _quantity = 0.0;

  @override
  Widget build(BuildContext context) {
    final availableProducts = _selectedTruck != null
        ? Product.values
            .where((p) => (widget.warehouse.inventory[p] ?? 0) > 0)
            .toList()
        : <Product>[];
    
    final availableCapacity = _selectedTruck != null
        ? _selectedTruck!.capacity - _selectedTruck!.currentLoad
        : 0;
    
    final maxQuantity = _selectedProduct != null && _selectedTruck != null
        ? [
            widget.warehouse.inventory[_selectedProduct] ?? 0,
            availableCapacity,
          ].reduce((a, b) => a < b ? a : b)
        : 0;
    
    final quantityInt = maxQuantity > 0 ? _quantity.round().clamp(1, maxQuantity) : 0;

    return AlertDialog(
      title: Text(
        'Load Truck',
        style: TextStyle(
          fontSize: ScreenUtils.relativeFontSize(
            context,
            AppConfig.fontSizeFactorMedium,
            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
          ),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Truck selection
              Text(
                'Select Truck:',
                style: TextStyle(
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    AppConfig.fontSizeFactorNormal,
                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                  ),
                ),
              ),
              SizedBox(
                height: ScreenUtils.relativeSize(
                  context,
                  AppConfig.spacingFactorMedium,
                ),
              ),
              DropdownButtonFormField<Truck>(
                value: _selectedTruck,
                style: TextStyle(
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    AppConfig.fontSizeFactorNormal,
                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                  ),
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Choose a truck',
                  hintStyle: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorNormal,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                    color: Colors.black,
                  ),
                ),
                items: widget.trucks.map((truck) {
                  final load = truck.currentLoad;
                  final capacity = truck.capacity;
                  return DropdownMenuItem(
                    value: truck,
                    child: Text(
                      '${truck.name} (Load: $load/$capacity)',
                      style: TextStyle(
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          AppConfig.fontSizeFactorNormal,
                          min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                          max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                        ),
                        color: Colors.black,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTruck = value;
                    _selectedProduct = null;
                    _quantity = 0.0;
                  });
                },
              ),
              if (_selectedTruck != null) ...[
                SizedBox(
                  height: ScreenUtils.relativeSize(
                    context,
                    AppConfig.spacingFactorXLarge,
                  ),
                ),
                Text(
                  'Available Capacity: $availableCapacity / ${_selectedTruck!.capacity}',
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorNormal,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                  ),
                ),
                SizedBox(
                  height: ScreenUtils.relativeSize(
                    context,
                    AppConfig.spacingFactorXLarge,
                  ),
                ),
                Text(
                  'Select Product:',
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorNormal,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                  ),
                ),
                SizedBox(
                  height: ScreenUtils.relativeSize(
                    context,
                    AppConfig.spacingFactorMedium,
                  ),
                ),
                DropdownButtonFormField<Product>(
                  value: _selectedProduct,
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorNormal,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: 'Choose a product',
                    hintStyle: TextStyle(
                      fontSize: ScreenUtils.relativeFontSize(
                        context,
                        AppConfig.fontSizeFactorNormal,
                        min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                        max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                      ),
                      color: Colors.black,
                    ),
                  ),
                  items: availableProducts.map((product) {
                    final stock = widget.warehouse.inventory[product] ?? 0;
                    return DropdownMenuItem(
                      value: product,
                      child: Text(
                        '${product.name} (Stock: $stock)',
                        style: TextStyle(
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            AppConfig.fontSizeFactorNormal,
                            min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                            max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                          ),
                          color: Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProduct = value;
                      _quantity = 0.0;
                    });
                  },
                ),
                if (_selectedProduct != null) ...[
                  SizedBox(
                    height: ScreenUtils.relativeSize(
                      context,
                      AppConfig.spacingFactorXLarge,
                    ),
                  ),
                  if (maxQuantity > 0) ...[
                    // Number pad input - reuse from route planner
                    _NumberPadInput(
                      value: quantityInt,
                      maxValue: maxQuantity,
                      onValueChanged: (value) {
                        setState(() {
                          _quantity = value.toDouble();
                        });
                      },
                      dialogWidth: null,
                      padding: null,
                    ),
                  ] else
                    Text(
                      'Cannot load: Truck is full or no stock available',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          AppConfig.fontSizeFactorNormal,
                          min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                          max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
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
            SizedBox(
              width: ScreenUtils.relativeSize(
                context,
                AppConfig.spacingFactorMedium,
              ),
            ),
            ElevatedButton(
              onPressed: _selectedTruck != null &&
                      _selectedProduct != null &&
                      quantityInt > 0 &&
                      _quantity > 0
                  ? () {
                      widget.onLoad(_selectedTruck!.id, _selectedProduct!, quantityInt);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Load',
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
          ],
        ),
      ],
    );
  }
}

/// Number pad input widget (reused from route planner)
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
