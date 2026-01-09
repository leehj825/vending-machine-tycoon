import '../engine.dart';
import '../models/machine.dart';
import 'simulation_system.dart';
import '../../config.dart';

class ReputationSystem implements SimulationSystem {
  @override
  SimulationState update(SimulationState state, GameTime time) {
    // We need to calculate the penalty based on the CURRENT state of machines
    // (which might have been updated by other systems)
    final reputationPenalty = _calculateReputationPenalty(state.machines);

    // Note: SalesSystem calculated reputation gain and applied it to state.reputation.
    // However, SalesSystem was using a simple logic:
    // var updatedReputation = ((state.reputation - reputationPenalty + reputationGain).clamp(0, 1000)).round();
    // But SalesSystem didn't have the updated machine state from other systems (like if a machine broke down or was restocked).
    // Now that we moved penalty here, we need to apply the penalty.
    // The SalesSystem should ideally ONLY apply the gain.

    // BUT: SalesSystem calculates `totalSales` internally and uses it for gain.
    // If we split them, we need to know the sales gain.
    // SalesSystem updates the reputation with (Gain - Penalty).
    // If we remove Penalty from SalesSystem, it will update with (Gain).
    // Then ReputationSystem can update with (-Penalty).

    final updatedReputation = ((state.reputation - reputationPenalty).clamp(0, 1000)).round();

    return state.copyWith(
      reputation: updatedReputation,
    );
  }

  /// Calculate reputation penalty based on empty machines
  int _calculateReputationPenalty(List<Machine> machines) {
    int totalPenalty = 0;

    for (final machine in machines) {
      if (machine.isEmpty && machine.hoursEmpty >= SimulationConstants.emptyMachinePenaltyHours) {
        totalPenalty += 1;
      }
    }

    return totalPenalty;
  }
}
