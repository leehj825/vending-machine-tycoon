import '../../config.dart';
import 'zone.dart';

/// Price sensitivity of each zone type, and the pure math that turns a
/// player-set price into a demand effect.
///
/// A machine's price used to be fixed at the product's list price everywhere,
/// so pricing was never a decision. This lets the player set a per-product
/// price multiplier on each machine: raise it for more margin per sale, lower
/// it for more volume. How much demand a price change costs (or buys) depends
/// on the zone - a captive audience (a hospital) barely notices a markup,
/// while a price-sensitive one (a school) punishes it hard.
extension ZoneTypePriceElasticity on ZoneType {
  /// How strongly demand reacts to a price change in this zone type.
  /// Lower = more captive/price-insensitive, higher = more price-sensitive.
  double get priceElasticity {
    switch (this) {
      case ZoneType.hospital:
        return 0.5; // Captive audience, least price sensitive
      case ZoneType.office:
        return 0.6;
      case ZoneType.subway:
        return 0.7; // Commuters in a hurry, still fairly captive
      case ZoneType.university:
        return 0.8;
      case ZoneType.gym:
        return 0.9;
      case ZoneType.shop:
        return 1.0; // Baseline: neither captive nor especially sensitive
      case ZoneType.school:
        return 1.2; // Kids on a fixed allowance, most price sensitive
    }
  }
}

/// Pure pricing math, kept separate from the simulation engine so it can be
/// unit tested without spinning up a full tick.
class PricingMath {
  const PricingMath._();

  /// How much a [priceMultiplier] away from 1.0 (list price) shifts demand in
  /// a zone with the given [elasticity].
  ///
  /// A markup (multiplier > 1.0) reduces demand; a discount increases it. The
  /// result is clamped so overpricing can never fully kill demand and
  /// underpricing can't create an unbounded volume glitch.
  static double demandFactor(double priceMultiplier, double elasticity) {
    final priceDelta = priceMultiplier - 1.0;
    final factor = 1.0 - (priceDelta * elasticity);
    return factor.clamp(
      AppConfig.priceDemandFactorMin,
      AppConfig.priceDemandFactorMax,
    );
  }

  /// The price actually charged for one unit: list price scaled by the
  /// player's multiplier, plus any flat research bonus (e.g. Premium
  /// Branding) that is applied on top rather than through elasticity, since
  /// that bonus is explicitly "without losing customers".
  static double effectivePrice({
    required double basePrice,
    required double priceMultiplier,
    double flatBonusMultiplier = 1.0,
  }) {
    return basePrice * priceMultiplier * flatBonusMultiplier;
  }

  /// Revenue-maximizing multiplier for a zone of the given elasticity,
  /// derived from maximizing multiplier * demandFactor(multiplier). Not used
  /// by the simulation itself - useful for tuning and for showing the player
  /// a "suggested price" hint.
  static double revenueMaximizingMultiplier(double elasticity) {
    if (elasticity <= 0) return AppConfig.machinePriceMultiplierMax;
    final optimum = (1.0 + elasticity) / (2.0 * elasticity);
    return optimum.clamp(
      AppConfig.machinePriceMultiplierMin,
      AppConfig.machinePriceMultiplierMax,
    );
  }

  /// Clamp a requested multiplier to the range the UI allows.
  static double clampMultiplier(double multiplier) {
    return multiplier.clamp(
      AppConfig.machinePriceMultiplierMin,
      AppConfig.machinePriceMultiplierMax,
    );
  }
}
