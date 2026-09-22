import '../../config.dart';

/// Pure rival-company math, kept separate from the simulation engine so it
/// can be unit tested without a live [Machine] list or engine tick.
///
/// A rival vending company competes for the same zone-type markets the
/// player does. Every game day, its presence in each zone type grows toward
/// a cap - faster where the player has few or no machines of their own
/// (an uncontested market), slower where the player already has a strong
/// foothold. Rival presence never fully disappears on its own; the player
/// has to actively push it back with a counter-attack.
class RivalMath {
  const RivalMath._();

  /// New rival presence (0.0-[AppConfig.rivalMaxPresence]) after one day of
  /// growth, given the player's current machine count in that zone type.
  ///
  /// More player machines raise "saturation resistance" and slow growth, but
  /// growth never drops to exactly zero - a rival that's been fully pushed
  /// out will always start creeping back in, so counter-attacks stay a
  /// recurring decision rather than a one-time chore.
  static double dailyGrowth(double currentPresence, int playerMachineCount) {
    final rawResistance =
        1.0 / (1.0 + playerMachineCount * AppConfig.rivalResistancePerMachine);
    final resistance = rawResistance.clamp(
      AppConfig.rivalMinResistanceFloor,
      1.0,
    );
    final growthRate = AppConfig.rivalBaseDailyGrowthRate * resistance;
    final next = currentPresence +
        growthRate * (AppConfig.rivalMaxPresence - currentPresence);
    return next.clamp(0.0, AppConfig.rivalMaxPresence);
  }

  /// Multiplier applied to the player's sale chance in a zone type with the
  /// given rival presence - a more entrenched rival siphons off more
  /// customers before they ever reach the player's machine.
  static double demandMultiplier(double presence) {
    final multiplier = 1.0 - presence * AppConfig.rivalDemandImpactMax;
    return multiplier.clamp(1.0 - AppConfig.rivalDemandImpactMax, 1.0);
  }

  /// Cash cost of a counter-attack campaign against a rival at the given
  /// presence - the more entrenched they are, the more it costs to dislodge
  /// them.
  static double counterAttackCost(double presence) {
    return AppConfig.rivalCounterAttackBaseCost +
        presence * AppConfig.rivalCounterAttackCostPerPresence;
  }

  /// Rival presence remaining after a successful counter-attack.
  static double counterAttackResult(double presence) {
    return (presence - AppConfig.rivalCounterAttackReduction).clamp(
      0.0,
      AppConfig.rivalMaxPresence,
    );
  }
}
