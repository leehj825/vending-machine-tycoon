import '../engine.dart';

/// Interface for all simulation systems
abstract class SimulationSystem {
  /// Update the system state based on the current simulation state
  SimulationState update(SimulationState state, GameTime time);
}
