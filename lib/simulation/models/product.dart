/// Product types available in vending machines
enum Product {
  soda,
  chips,
  proteinBar,
  coffee,
  techGadget,
  sandwich, // Has spoilage (expires after 3 game days)
  freshSalad, // Healthy product for hospitals
  newspaper, // For transit stations
  energyDrink, // For universities
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
      case Product.freshSalad:
        return 'Fresh Salad';
      case Product.newspaper:
        return 'Newspaper';
      case Product.energyDrink:
        return 'Energy Drink';
    }
  }

  /// Base price for each product (increased for better revenue)
  double get basePrice {
    switch (this) {
      case Product.soda:
        return 3.00; // Increased from 2.50
      case Product.chips:
        return 2.25; // Increased from 1.75
      case Product.proteinBar:
        return 3.75; // Increased from 3.00
      case Product.coffee:
        return 4.50; // Increased from 3.50
      case Product.techGadget:
        return 30.00; // Increased from 25.00
      case Product.sandwich:
        return 6.50; // Increased from 5.50
      case Product.freshSalad:
        return 7.00; // Increased from 6.00
      case Product.newspaper:
        return 2.50; // Increased from 2.00
      case Product.energyDrink:
        return 5.50; // Increased from 4.50
    }
  }

  /// Base demand probability (0.0 to 1.0) - increased for better game pacing
  double get baseDemand {
    switch (this) {
      case Product.soda:
        return 0.50; // 50% per hour (increased from 40% for faster progression)
      case Product.chips:
        return 0.45; // 45% per hour (increased from 35% for faster progression)
      case Product.proteinBar:
        return 0.35; // 35% per hour (increased from 26% for faster progression)
      case Product.coffee:
        return 0.40; // 40% per hour (increased from 30% for faster progression)
      case Product.techGadget:
        return 0.18; // 18% per hour (increased from 14% for faster progression)
      case Product.sandwich:
        return 0.38; // 38% per hour (increased from 28% for faster progression)
      case Product.freshSalad:
        return 0.33; // 33% per hour (increased from 25% for faster progression)
      case Product.newspaper:
        return 0.28; // 28% per hour (increased from 20% for faster progression)
      case Product.energyDrink:
        return 0.42; // 42% per hour (increased from 32% for faster progression)
    }
  }

  /// Whether this product can spoil
  bool get canSpoil => this == Product.sandwich || this == Product.freshSalad;

  /// Days until spoilage (only relevant for spoilable products)
  int get spoilageDays {
    if (!canSpoil) return -1;
    if (this == Product.sandwich) return 3;
    if (this == Product.freshSalad) return 2; // Fresh salad spoils faster
    return -1;
  }
}

