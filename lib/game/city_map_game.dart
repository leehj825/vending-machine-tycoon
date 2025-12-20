import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import 'components/map_machine.dart';
import 'components/map_truck.dart';

/// Main game class for the city map visualization
class CityMapGame extends FlameGame with HasGameReference {
  final WidgetRef ref;
  final Map<String, MapMachine> _machineComponents = {};
  final Map<String, MapTruck> _truckComponents = {};

  CityMapGame(this.ref);

  @override
  Color backgroundColor() => const Color(0xFF388E3C);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Setup camera for 1000x1000 grid
    camera.viewfinder.anchor = Anchor.center;
    camera.viewport = FixedResolutionViewport(resolution: Vector2(1000, 1000));

    // Add grid background
    add(GridComponent());

    // Initial load of machines and trucks
    _syncMachines();
    _syncTrucks();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Sync machines and trucks every frame to update positions
    _syncMachines();
    _syncTrucks();
  }

  /// Sync machine components with provider state
  void _syncMachines() {
    try {
      final machines = ref.read(machinesProvider);

      // Remove machines that no longer exist
      final machineIds = machines.map((m) => m.id).toSet();
      final componentsToRemove = _machineComponents.keys
          .where((id) => !machineIds.contains(id))
          .toList();

      for (final id in componentsToRemove) {
        final component = _machineComponents.remove(id);
        component?.removeFromParent();
      }

      // Add or update machines
      for (final machine in machines) {
        if (_machineComponents.containsKey(machine.id)) {
          // Update existing component
          final component = _machineComponents[machine.id]!;
          component.updateMachine(machine);
          // Update position if zone changed
          final newPosition = Vector2(machine.zone.x * 100, machine.zone.y * 100);
          if (component.position != newPosition) {
            component.position = newPosition;
          }
        } else {
          // Create new component at machine's zone position
          final component = MapMachine(
            machine: machine,
            position: Vector2(machine.zone.x * 100, machine.zone.y * 100),
          );
          _machineComponents[machine.id] = component;
          add(component);
        }
      }
    } catch (e) {
      // Provider might not be available yet
      // Ignore for now
    }
  }

  /// Sync truck components with provider state
  void _syncTrucks() {
    try {
      final trucks = ref.read(trucksProvider);

      // Remove trucks that no longer exist
      final truckIds = trucks.map((t) => t.id).toSet();
      final componentsToRemove = _truckComponents.keys
          .where((id) => !truckIds.contains(id))
          .toList();

      for (final id in componentsToRemove) {
        final component = _truckComponents.remove(id);
        component?.removeFromParent();
      }

      // Add or update trucks
      for (final truck in trucks) {
        if (_truckComponents.containsKey(truck.id)) {
          // Update existing component
          final component = _truckComponents[truck.id]!;
          component.updateTruck(truck);
        } else {
          // Create new component at truck's current position
          final component = MapTruck(
            truck: truck,
            position: Vector2(truck.currentX * 100, truck.currentY * 100),
          );
          _truckComponents[truck.id] = component;
          add(component);
        }
      }
    } catch (e) {
      // Provider might not be available yet
      // Ignore for now
    }
  }
}

/// Grid component that draws grid lines
class GridComponent extends PositionComponent {
  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF757575)..strokeWidth = 20;
    for (double i = 0; i <= 1000; i += 100) {
      canvas.drawLine(Offset(i, 0), Offset(i, 1000), paint);
      canvas.drawLine(Offset(0, i), Offset(1000, i), paint);
    }
  }
}

