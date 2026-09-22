import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/config.dart';
import 'package:vending_empire/simulation/models/pricing.dart';
import 'package:vending_empire/simulation/models/zone.dart';

void main() {
  group('ZoneTypePriceElasticity', () {
    test('captive zones are less price sensitive than price-sensitive ones', () {
      expect(ZoneType.hospital.priceElasticity, lessThan(ZoneType.shop.priceElasticity));
      expect(ZoneType.shop.priceElasticity, lessThan(ZoneType.school.priceElasticity));
    });

    test('every zone type has a positive elasticity', () {
      for (final type in ZoneType.values) {
        expect(type.priceElasticity, greaterThan(0.0));
      }
    });
  });

  group('PricingMath.demandFactor', () {
    test('list price (multiplier 1.0) never changes demand', () {
      for (final elasticity in [0.5, 1.0, 1.2]) {
        expect(PricingMath.demandFactor(1.0, elasticity), 1.0);
      }
    });

    test('a markup reduces demand', () {
      final factor = PricingMath.demandFactor(1.3, 1.0);
      expect(factor, lessThan(1.0));
      expect(factor, closeTo(0.7, 0.0001));
    });

    test('a discount increases demand', () {
      final factor = PricingMath.demandFactor(0.8, 1.0);
      expect(factor, greaterThan(1.0));
      expect(factor, closeTo(1.2, 0.0001));
    });

    test('a more price-sensitive zone loses more demand for the same markup', () {
      final sensitive = PricingMath.demandFactor(1.3, ZoneType.school.priceElasticity);
      final captive = PricingMath.demandFactor(1.3, ZoneType.hospital.priceElasticity);
      expect(sensitive, lessThan(captive));
    });

    test('extreme overpricing never fully kills demand', () {
      final factor = PricingMath.demandFactor(AppConfig.machinePriceMultiplierMax, 1.2);
      expect(factor, greaterThanOrEqualTo(AppConfig.priceDemandFactorMin));
      expect(factor, AppConfig.priceDemandFactorMin);
    });

    test('extreme underpricing is capped, not unbounded', () {
      final factor = PricingMath.demandFactor(AppConfig.machinePriceMultiplierMin, 1.2);
      expect(factor, lessThanOrEqualTo(AppConfig.priceDemandFactorMax));
      expect(factor, AppConfig.priceDemandFactorMax);
    });
  });

  group('PricingMath.effectivePrice', () {
    test('multiplier 1.0 and no bonus reproduces the old fixed-price behavior', () {
      final price = PricingMath.effectivePrice(
        basePrice: 3.00,
        priceMultiplier: 1.0,
      );
      expect(price, 3.00);
    });

    test('markup scales price directly', () {
      final price = PricingMath.effectivePrice(
        basePrice: 3.00,
        priceMultiplier: 1.5,
      );
      expect(price, closeTo(4.50, 0.0001));
    });

    test('Premium Branding bonus applies on top of the player price', () {
      final price = PricingMath.effectivePrice(
        basePrice: 3.00,
        priceMultiplier: 1.2,
        flatBonusMultiplier: 1.10,
      );
      expect(price, closeTo(3.00 * 1.2 * 1.10, 0.0001));
    });
  });

  group('PricingMath.revenueMaximizingMultiplier', () {
    test('a price-insensitive zone has a higher optimal markup than a sensitive one', () {
      final captiveOptimum =
          PricingMath.revenueMaximizingMultiplier(ZoneType.hospital.priceElasticity);
      final sensitiveOptimum =
          PricingMath.revenueMaximizingMultiplier(ZoneType.school.priceElasticity);
      expect(captiveOptimum, greaterThan(sensitiveOptimum));
    });

    test('the optimum actually maximizes multiplier * demandFactor', () {
      const elasticity = 0.6;
      final optimum = PricingMath.revenueMaximizingMultiplier(elasticity);
      double revenueAt(double m) => m * PricingMath.demandFactor(m, elasticity);

      final atOptimum = revenueAt(optimum);
      expect(atOptimum, greaterThan(revenueAt(optimum - 0.1)));
      expect(atOptimum, greaterThan(revenueAt(optimum + 0.1)));
    });

    test('result stays within the multiplier bounds the UI allows', () {
      for (final type in ZoneType.values) {
        final optimum = PricingMath.revenueMaximizingMultiplier(type.priceElasticity);
        expect(optimum, greaterThanOrEqualTo(AppConfig.machinePriceMultiplierMin));
        expect(optimum, lessThanOrEqualTo(AppConfig.machinePriceMultiplierMax));
      }
    });
  });

  group('PricingMath.clampMultiplier', () {
    test('clamps to the configured range', () {
      expect(PricingMath.clampMultiplier(10.0), AppConfig.machinePriceMultiplierMax);
      expect(PricingMath.clampMultiplier(-5.0), AppConfig.machinePriceMultiplierMin);
      expect(PricingMath.clampMultiplier(1.3), 1.3);
    });
  });
}
