import '../engine.dart';
import '../models/machine.dart';
import '../../state/game_log_entry.dart';
import 'simulation_system.dart';
import 'dart:math' as math;

class MaintenanceSystem implements SimulationSystem {
  @override
  SimulationState update(SimulationState state, GameTime time) {
    final result = _processRandomBreakdowns(state.machines, state.random, time);
    var updatedMachines = result.machines;

    final currentMessages = List<GameLogEntry>.from(state.pendingMessages);
    currentMessages.addAll(result.messages);

    if (time.minute == 0) {
      updatedMachines = _processMechanics(updatedMachines, state.mechanicCount);
    }

    return state.copyWith(
      machines: updatedMachines,
      pendingMessages: currentMessages,
    );
  }

  /// Process random breakdowns
  ({List<Machine> machines, List<GameLogEntry> messages}) _processRandomBreakdowns(
    List<Machine> machines,
    math.Random random,
    GameTime time,
  ) {
    final dailyProbability = 0.02; // 2% per day
    final breakdownChancePerTick = (1.0 - math.pow(1.0 - dailyProbability, 1.0 / SimulationConstants.ticksPerDay)).toDouble();
    var messages = <GameLogEntry>[];

    final updatedMachines = machines.map((machine) {
      if (machine.isBroken) {
        return machine;
      }

      final randomValue = random.nextDouble();

      if (randomValue < breakdownChancePerTick) {
        messages.add(GameLogEntry(
          type: LogType.machineBreakdown,
          timestamp: time,
          data: {'machineName': machine.name},
        ));

        return machine.copyWith(
          condition: MachineCondition.broken,
        );
      }

      return machine;
    }).toList();

    return (machines: updatedMachines, messages: messages);
  }

  /// Process mechanics - auto-repair broken machines
  List<Machine> _processMechanics(List<Machine> machines, int mechanicCount) {
    if (mechanicCount <= 0) return machines;

    var updatedMachines = List<Machine>.from(machines);
    int repairsRemaining = mechanicCount;

    final brokenMachines = <int>[];
    for (int i = 0; i < updatedMachines.length; i++) {
      if (updatedMachines[i].isBroken) {
        brokenMachines.add(i);
      }
    }

    for (int i = 0; i < brokenMachines.length && repairsRemaining > 0; i++) {
      final machineIndex = brokenMachines[i];
      updatedMachines[machineIndex] = updatedMachines[machineIndex].copyWith(
        condition: MachineCondition.good,
      );
      repairsRemaining--;
    }

    return updatedMachines;
  }
}
