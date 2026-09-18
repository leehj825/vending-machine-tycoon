import '../../config.dart';
import 'zone.dart';

/// How exposed a zone type is to theft and vandalism. Pairs with
/// ZoneTypePriceElasticity (pricing.dart): the safest zones (Hospital,
/// Office) are also the least price-sensitive, and the riskiest (Subway,
/// School) are the most price-sensitive - so a "good" zone is good on both
/// axes, and there's no single dominant zone type to always chase.
extension ZoneTypeCrimeRisk on ZoneType {
  double get crimeRiskMultiplier {
    switch (this) {
      case ZoneType.hospital:
        return 0.5; // Staffed around the clock, most secure
      case ZoneType.office:
        return 0.6; // Staffed, badge access, cameras
      case ZoneType.gym:
        return 1.0; // Baseline
      case ZoneType.university:
        return 1.2;
      case ZoneType.shop:
        return 1.1;
      case ZoneType.school:
        return 1.3; // Unsupervised after hours, mischief-prone
      case ZoneType.subway:
        return 1.6; // High foot traffic, easy to blend in and vanish
    }
  }
}

/// What happened to a machine during a security event.
enum SecurityEventType { theft, vandalism }

/// Pure security-event math, kept separate from the simulation engine so it
/// can be unit tested without a live [Machine] or [math.Random] - the engine
/// draws the randomness and hands in plain doubles.
class SecurityMath {
  const SecurityMath._();

  /// Probability (0.0-1.0) that a machine is targeted during this game hour.
  ///
  /// Scales with the zone's crime risk, spikes at night, and rises with how
  /// much cash is sitting uncollected in the machine (a bigger, more visible
  /// target). The Security upgrade cuts the whole thing down sharply.
  static double eventChance({
    required int hour,
    required double currentCash,
    required bool hasSecurityUpgrade,
    required double crimeRiskMultiplier,
  }) {
    final isNight = hour >= AppConfig.securityEventNightStartHour ||
        hour < AppConfig.securityEventNightEndHour;

    var chance = AppConfig.securityEventBaseHourlyChance * crimeRiskMultiplier;
    if (isNight) {
      chance *= AppConfig.securityEventNightMultiplier;
    }

    final cashRisk = (currentCash / 100.0) * AppConfig.securityEventCashRiskPer100;
    chance *= 1.0 + cashRisk.clamp(0.0, AppConfig.securityEventCashRiskCap);

    if (hasSecurityUpgrade) {
      chance *= (1.0 - AppConfig.securityUpgradeRiskReduction);
    }

    return chance.clamp(0.0, 1.0);
  }

  /// Which kind of event a targeted machine suffers.
  ///
  /// A machine with nothing in the till has nothing worth stealing, so an
  /// empty-handed target is always vandalized rather than robbed - that also
  /// guarantees theft can never fire against zero cash and silently do
  /// nothing.
  static SecurityEventType resolveEventType({
    required double currentCash,
    required double roll,
  }) {
    if (currentCash <= 0) return SecurityEventType.vandalism;
    return roll < AppConfig.theftVsVandalismShareWithCash
        ? SecurityEventType.theft
        : SecurityEventType.vandalism;
  }

  /// How much of the machine's stored cash a theft takes, as a random share
  /// within the configured range.
  static double theftAmount({
    required double currentCash,
    required double roll,
  }) {
    final share = AppConfig.theftCashShareMin +
        roll * (AppConfig.theftCashShareMax - AppConfig.theftCashShareMin);
    return currentCash * share;
  }
}
