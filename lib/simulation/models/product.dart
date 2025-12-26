/// Product types available in vending machines
enum Product {
  soda,
  chips,
  proteinBar,
  coffee,
  techGadget,
  sandwich, // Has spoilage (expires after 3 game days)
}

extension ProductExtension on Product {
  /// Display name for the product
  String get name {
    switch (this) {
      case Product.soda:
        return 'Soda';
      case Product.chips:
        return 'Chips';
      case Product.proteinBar:
        return 'Protein Bar';
      case Product.coffee:
        return 'Coffee';
      case Product.techGadget:
        return 'Tech Gadget';
      case Product.sandwich:
        return 'Sandwich';
    }
  }

  /// Base price for each product
  double get basePrice {
    switch (this) {
      case Product.soda:
        return 2.50;
      case Product.chips:
        return 1.75;
      case Product.proteinBar:
        return 3.00;
      case Product.coffee:
        return 3.50;
      case Product.techGadget:
        return 25.00;
      case Product.sandwich:
        return 5.50;
    }
  }

  /// Base demand probability (0.0 to 1.0) - increased by 30%
  double get baseDemand {
    switch (this) {
      case Product.soda:
        return 0.195; // 0.15 * 1.3
      case Product.chips:
        return 0.156; // 0.12 * 1.3
      case Product.proteinBar:
        return 0.104; // 0.08 * 1.3
      case Product.coffee:
        return 0.13; // 0.10 * 1.3
      case Product.techGadget:
        return 0.026; // 0.02 * 1.3
      case Product.sandwich:
        return 0.117; // 0.09 * 1.3
    }
  }

  /// Whether this product can spoil
  bool get canSpoil => this == Product.sandwich;

  /// Days until spoilage (only relevant for spoilable products)
  int get spoilageDays => canSpoil ? 3 : -1;
}

