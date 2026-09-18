import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/config.dart';
import 'package:vending_empire/simulation/models/security.dart';
import 'package:vending_empire/simulation/models/zone.dart';

void main() {
  group('ZoneTypeCrimeRisk', () {
    test('the safest zones for pricing are also the safest for crime', () {
      // Hospital and Office are the two least price-sensitive zones
      // (pricing_test.dart); they should also be the two lowest-crime zones,
      // so a "good" zone is good on both axes rather than a hidden tradeoff.
      final risks = {
        for (final t in ZoneType.values) t: t.crimeRiskMultiplier,
      };
      final sorted = risks.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      expect(sorted.first.key, anyOf(ZoneType.hospital, ZoneType.office));
      expect(sorted[1].key, anyOf(ZoneType.hospital, ZoneType.office));
    });

    test('every zone type has a positive risk multiplier', () {
      for (final type in ZoneType.values) {
        expect(type.crimeRiskMultiplier, greaterThan(0.0));
      }
    });
  });

  group('SecurityMath.eventChance', () {
    const daytimeHour = 12;
    const nighttimeHour = 2;

    test('night hours are riskier than day hours, all else equal', () {
      final day = SecurityMath.eventChance(
        hour: daytimeHour,
        currentCash: 0,
        hasSecurityUpgrade: false,
        crimeRiskMultiplier: 1.0,
      );
      final night = SecurityMath.eventChance(
        hour: nighttimeHour,
        currentCash: 0,
        hasSecurityUpgrade: false,
        crimeRiskMultiplier: 1.0,
      );
      expect(night, greaterThan(day));
      expect(night, closeTo(day * AppConfig.securityEventNightMultiplier, 0.0001));
    });

    test('the night window boundaries are handled correctly', () {
      final chanceAt = (int hour) => SecurityMath.eventChance(
            hour: hour,
            currentCash: 0,
            hasSecurityUpgrade: false,
            crimeRiskMultiplier: 1.0,
          );
      // 22:00 is night, 21:00 is not; 04:00 is night, 05:00 is not
      expect(chanceAt(22), greaterThan(chanceAt(21)));
      expect(chanceAt(4), greaterThan(chanceAt(5)));
    });

    test('more cash sitting in the machine raises risk, up to the cap', () {
      final noCash = SecurityMath.eventChance(
        hour: daytimeHour,
        currentCash: 0,
        hasSecurityUpgrade: false,
        crimeRiskMultiplier: 1.0,
      );
      final someCash = SecurityMath.eventChance(
        hour: daytimeHour,
        currentCash: 200,
        hasSecurityUpgrade: false,
        crimeRiskMultiplier: 1.0,
      );
      final hugeCash = SecurityMath.eventChance(
        hour: daytimeHour,
        currentCash: 1000000,
        hasSecurityUpgrade: false,
        crimeRiskMultiplier: 1.0,
      );
      expect(someCash, greaterThan(noCash));
      // Capped: an enormous cash pile can't push risk past double the base
      expect(hugeCash, closeTo(noCash * (1.0 + AppConfig.securityEventCashRiskCap), 0.0001));
    });

    test('the Security upgrade meaningfully lowers risk', () {
      final unprotected = SecurityMath.eventChance(
        hour: daytimeHour,
        currentCash: 100,
        hasSecurityUpgrade: false,
        crimeRiskMultiplier: 1.0,
      );
      final protected = SecurityMath.eventChance(
        hour: daytimeHour,
        currentCash: 100,
        hasSecurityUpgrade: true,
        crimeRiskMultiplier: 1.0,
      );
      expect(protected, lessThan(unprotected));
      expect(
        protected,
        closeTo(unprotected * (1.0 - AppConfig.securityUpgradeRiskReduction), 0.0001),
      );
    });

    test('a riskier zone has a higher chance than a safer one, all else equal', () {
      final safe = SecurityMath.eventChance(
        hour: daytimeHour,
        currentCash: 0,
        hasSecurityUpgrade: false,
        crimeRiskMultiplier: ZoneType.hospital.crimeRiskMultiplier,
      );
      final risky = SecurityMath.eventChance(
        hour: daytimeHour,
        currentCash: 0,
        hasSecurityUpgrade: false,
        crimeRiskMultiplier: ZoneType.subway.crimeRiskMultiplier,
      );
      expect(risky, greaterThan(safe));
    });

    test('chance is always a valid probability', () {
      for (final hour in [0, 6, 12, 18, 23]) {
        for (final cash in [0.0, 500.0, 1e9]) {
          for (final upgrade in [true, false]) {
            final chance = SecurityMath.eventChance(
              hour: hour,
              currentCash: cash,
              hasSecurityUpgrade: upgrade,
              crimeRiskMultiplier: 1.6,
            );
            expect(chance, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });
  });

  group('SecurityMath.resolveEventType', () {
    test('a machine with no cash is always vandalized, never robbed', () {
      for (final roll in [0.0, 0.3, 0.5, 0.99]) {
        expect(
          SecurityMath.resolveEventType(currentCash: 0, roll: roll),
          SecurityEventType.vandalism,
        );
      }
    });

    test('a machine with cash splits between theft and vandalism by roll', () {
      final theftRoll = AppConfig.theftVsVandalismShareWithCash - 0.01;
      final vandalismRoll = AppConfig.theftVsVandalismShareWithCash + 0.01;
      expect(
        SecurityMath.resolveEventType(currentCash: 50, roll: theftRoll),
        SecurityEventType.theft,
      );
      expect(
        SecurityMath.resolveEventType(currentCash: 50, roll: vandalismRoll),
        SecurityEventType.vandalism,
      );
    });
  });

  group('SecurityMath.theftAmount', () {
    test('stays within the configured min/max share of cash on hand', () {
      const cash = 200.0;
      final atMin = SecurityMath.theftAmount(currentCash: cash, roll: 0.0);
      final atMax = SecurityMath.theftAmount(currentCash: cash, roll: 1.0);
      expect(atMin, closeTo(cash * AppConfig.theftCashShareMin, 0.0001));
      expect(atMax, closeTo(cash * AppConfig.theftCashShareMax, 0.0001));
    });

    test('never exceeds the cash actually in the machine', () {
      const cash = 75.0;
      for (final roll in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final amount = SecurityMath.theftAmount(currentCash: cash, roll: roll);
        expect(amount, lessThanOrEqualTo(cash));
      }
    });

    test('zero cash on hand yields zero theft', () {
      expect(SecurityMath.theftAmount(currentCash: 0, roll: 0.7), 0.0);
    });
  });
}
