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
        return 0.40; // 40% per hour (+10 percentage points from 30%)
      case Product.chips:
        return 0.35; // 35% per hour (+10 percentage points from 25%)
      case Product.proteinBar:
        return 0.26; // 26% per hour (+10 percentage points from 16%)
      case Product.coffee:
        return 0.30; // 30% per hour (+10 percentage points from 20%)
      case Product.techGadget:
        return 0.14; // 14% per hour (+10 percentage points from 4%)
      case Product.sandwich:
        return 0.28; // 28% per hour (+10 percentage points from 18%)
      case Product.freshSalad:
        return 0.25; // 25% per hour
      case Product.newspaper:
        return 0.20; // 20% per hour
      case Product.energyDrink:
        return 0.32; // 32% per hour
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

