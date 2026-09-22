import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/config.dart';
import 'package:vending_empire/simulation/models/rival.dart';

void main() {
  group('RivalMath.dailyGrowth', () {
    test('grows fastest when the player has zero machines in the zone', () {
      final uncontested = RivalMath.dailyGrowth(0.0, 0);
      final defended = RivalMath.dailyGrowth(0.0, 10);
      expect(uncontested, greaterThan(defended));
      expect(uncontested, greaterThan(0.0));
    });

    test('growth never fully stops, even with many player machines', () {
      final next = RivalMath.dailyGrowth(0.0, 1000);
      expect(next, greaterThan(0.0));
    });

    test('presence never exceeds the configured max', () {
      var presence = 0.0;
      for (var day = 0; day < 500; day++) {
        presence = RivalMath.dailyGrowth(presence, 0);
      }
      expect(presence, lessThanOrEqualTo(AppConfig.rivalMaxPresence));
      // With enough days uncontested, it should get very close to the cap
      expect(presence, greaterThan(AppConfig.rivalMaxPresence * 0.95));
    });

    test('growth is monotonically non-decreasing day over day (uncontested)', () {
      var presence = 0.0;
      for (var day = 0; day < 30; day++) {
        final next = RivalMath.dailyGrowth(presence, 0);
        expect(next, greaterThanOrEqualTo(presence));
        presence = next;
      }
    });

    test('presence never goes negative', () {
      final next = RivalMath.dailyGrowth(0.0, 5);
      expect(next, greaterThanOrEqualTo(0.0));
    });
  });

  group('RivalMath.demandMultiplier', () {
    test('is 1.0 (no impact) at zero presence', () {
      expect(RivalMath.demandMultiplier(0.0), 1.0);
    });

    test('decreases as presence rises', () {
      final low = RivalMath.demandMultiplier(0.2);
      final high = RivalMath.demandMultiplier(0.6);
      expect(high, lessThan(low));
      expect(low, lessThan(1.0));
    });

    test('never drops below the configured floor even at max presence', () {
      final multiplier = RivalMath.demandMultiplier(AppConfig.rivalMaxPresence);
      expect(multiplier, greaterThanOrEqualTo(1.0 - AppConfig.rivalDemandImpactMax));
    });
  });

  group('RivalMath.counterAttackCost / counterAttackResult', () {
    test('cost rises with how entrenched the rival is', () {
      final cheap = RivalMath.counterAttackCost(0.1);
      final expensive = RivalMath.counterAttackCost(0.7);
      expect(expensive, greaterThan(cheap));
    });

    test('a counter-attack reduces presence', () {
      final result = RivalMath.counterAttackResult(0.6);
      expect(result, lessThan(0.6));
    });

    test('presence never drops below zero from a counter-attack', () {
      final result = RivalMath.counterAttackResult(0.05);
      expect(result, greaterThanOrEqualTo(0.0));
    });
  });
}
