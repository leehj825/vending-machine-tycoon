import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import '../simulation/models/product.dart';
import 'selectors.dart';

/// Price trend indicator
enum PriceTrend {
  up,
  down,
  stable,
}

/// Market prices state
class MarketPricesState {
  final Map<Product, double> prices;
  final Map<Product, double> previousPrices;
  final int lastUpdatedDay;

  const MarketPricesState({
    required this.prices,
    required this.previousPrices,
    required this.lastUpdatedDay,
  });

  MarketPricesState copyWith({
    Map<Product, double>? prices,
    Map<Product, double>? previousPrices,
    int? lastUpdatedDay,
  }) {
    return MarketPricesState(
      prices: prices ?? this.prices,
      previousPrices: previousPrices ?? this.previousPrices,
      lastUpdatedDay: lastUpdatedDay ?? this.lastUpdatedDay,
    );
  }
}

/// Base wholesale prices (cost to buy, not sell price)
class BaseMarketPrices {
  static const Map<Product, double> prices = {
    Product.soda: 0.50,
    Product.chips: 0.60,
    Product.coffee: 0.80,
    Product.proteinBar: 1.50,
    Product.techGadget: 8.00, // Wholesale price
    Product.sandwich: 2.00, // Wholesale price
    Product.freshSalad: 2.50, // Wholesale price
    Product.newspaper: 0.40, // Wholesale price
    Product.energyDrink: 1.20, // Wholesale price
  };

  static double getPrice(Product product) {
    return prices[product] ?? product.basePrice * 0.2; // Default to 20% of sell price
  }
}

/// Notifier for market prices with daily fluctuations
class MarketPricesNotifier extends StateNotifier<MarketPricesState> {
  final Ref ref;
  final Random _random = Random();

  MarketPricesNotifier(this.ref)
      : super(
          MarketPricesState(
            prices: _initializePrices(),
            previousPrices: {},
            lastUpdatedDay: 1,
          ),
        ) {
    // Listen to day changes
    ref.listen<int>(dayCountProvider, (previous, next) {
      if (previous != null && next > previous) {
        dailyUpdate();
      }
    });
  }

  /// Initialize prices from base prices
  static Map<Product, double> _initializePrices() {
    final prices = <Product, double>{};
    for (final product in Product.values) {
      prices[product] = BaseMarketPrices.getPrice(product);
    }
    return prices;
  }

  /// Update prices daily with random fluctuations
  void dailyUpdate() {
    final currentDay = ref.read(dayCountProvider);
    
    // Only update once per day
    if (state.lastUpdatedDay >= currentDay) {
      return;
    }

    // Save current prices as previous
    final previousPrices = Map<Product, double>.from(state.prices);
    
    // Generate new prices with +/- 20% fluctuation
    final newPrices = <Product, double>{};
    for (final entry in state.prices.entries) {
      final basePrice = BaseMarketPrices.getPrice(entry.key);
      // Fluctuate between 80% and 120% of base price
      final fluctuation = (_random.nextDouble() * 0.4) - 0.2; // -0.2 to +0.2
      final newPrice = basePrice * (1.0 + fluctuation);
      newPrices[entry.key] = newPrice;
    }

    state = state.copyWith(
      prices: newPrices,
      previousPrices: previousPrices,
      lastUpdatedDay: currentDay,
    );
  }

  /// Get price for a product
  double getPrice(Product product) {
    return state.prices[product] ?? BaseMarketPrices.getPrice(product);
  }

  /// Get price trend for a product
  PriceTrend getPriceTrend(Product product) {
    final currentPrice = state.prices[product] ?? BaseMarketPrices.getPrice(product);
    final previousPrice = state.previousPrices[product];
    
    if (previousPrice == null) return PriceTrend.stable;
    
    const threshold = 0.01; // 1% change threshold
    final change = currentPrice - previousPrice;
    
    if (change.abs() < threshold) return PriceTrend.stable;
    return change > 0 ? PriceTrend.up : PriceTrend.down;
  }

  /// Get current prices (public getter)
  Map<Product, double> get currentPrices => state.prices;
}

/// Provider for market prices notifier
final marketPricesProvider = Provider<MarketPricesNotifier>((ref) {
  return MarketPricesNotifier(ref);
});

/// Provider for current market prices
final marketPricesStateProvider = Provider<Map<Product, double>>((ref) {
  final notifier = ref.watch(marketPricesProvider);
  return notifier.currentPrices;
});

/// Provider for price trend
final priceTrendProvider = Provider.family<PriceTrend, Product>((ref, product) {
  final notifier = ref.watch(marketPricesProvider);
  return notifier.getPriceTrend(product);
});

/// Provider for a specific product's market price
final productMarketPriceProvider = Provider.family<double, Product>((ref, product) {
  final notifier = ref.watch(marketPricesProvider);
  return notifier.getPrice(product);
});

