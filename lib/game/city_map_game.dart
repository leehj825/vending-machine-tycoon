import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import 'components/map_machine.dart';
import 'components/map_truck.dart';
import '../simulation/models/machine.dart';

class CityMapGame extends FlameGame with TapDetector {
  final WidgetRef ref;
  
  // Entity Containers
  final Map<String, MapMachine> _machineComponents = {};
  final Map<String, MapTruck> _truckComponents = {};
  
  // Map Constants
  static const double mapWidth = 1000.0;
  static const double mapHeight = 1000.0;
  static final Vector2 mapCenter = Vector2(500.0, 500.0);

  // Legacy callback for backward compatibility
  final void Function(Machine)? onMachineTap;

  CityMapGame(this.ref, {this.onMachineTap});

  @override
  Color backgroundColor() => const Color(0xFF388E3C); // Grass Green

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 1. Setup Camera
    // Anchor to center is critical for "Fit to Screen" logic
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = mapCenter;

    // 2. Add Visuals
    add(GridComponent());

    // 3. Initial Sync
    _syncMachines();
    _syncTrucks();
    
    // 4. Initial Fit
    _fitMapToScreen();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Whenever the screen rotates or changes size, recalculate the zoom
    _fitMapToScreen();
  }

  /// Calculates the zoom level needed to fit the entire 1000x1000 map 
  /// into the current screen boundaries.
  void _fitMapToScreen() {
    if (size.x <= 0 || size.y <= 0) return;

    // Calculate the ratio for Width and Height
    final scaleX = size.x / mapWidth;
    final scaleY = size.y / mapHeight;

    // Choose the smaller scale. 
    // This ensures that the Dimension that is "tightest" (e.g. Width in Portrait mode) 
    // dictates the zoom, so the whole map is always visible.
    // We multiply by 0.95 to give a small 5% padding around the edges.
    final fitZoom = math.min(scaleX, scaleY) * 0.95;

    camera.viewfinder.zoom = fitZoom;
    camera.viewfinder.position = mapCenter;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncMachines();
    _syncTrucks();
  }

  // --- INTERACTION ---

  @override
  void onTapUp(TapUpInfo info) {
    // Check if we tapped a machine
    final touched = componentsAtPoint(info.eventPosition.widget);
    bool hit = false;
    
    for (final c in touched) {
      if (c is MapMachine) {
        hit = true; 
        break; // MapMachine handles its own logic via TapCallbacks
      }
    }
    
    // If we tapped empty grass, deselect everything
    if (!hit) {
      try {
        ref.read(selectedMachineIdProvider.notifier).state = null;
      } catch (_) {}
    }
  }

  // --- SYNC LOGIC (Unchanged) ---

  void _syncMachines() {
    try {
      final machines = ref.read(machinesProvider);
      final machineIds = machines.map((m) => m.id).toSet();
      
      // Cleanup
      _machineComponents.keys.where((id) => !machineIds.contains(id)).toList().forEach((id) {
         _machineComponents.remove(id)?.removeFromParent();
      });
      
      // Update/Add
      for (final m in machines) {
         final pos = Vector2(m.zone.x * 100, m.zone.y * 100);
         if (_machineComponents.containsKey(m.id)) {
            _machineComponents[m.id]!.updateMachine(m);
            _machineComponents[m.id]!.position = pos;
         } else {
            final c = MapMachine(machine: m, position: pos);
            _machineComponents[m.id] = c;
            add(c);
         }
      }
    } catch (_) {}
  }

  void _syncTrucks() {
    try {
      final trucks = ref.read(trucksProvider);
      final truckIds = trucks.map((t) => t.id).toSet();
      
      // Cleanup
      _truckComponents.keys.where((id) => !truckIds.contains(id)).toList().forEach((id) {
         _truckComponents.remove(id)?.removeFromParent();
      });
      
      // Update/Add
      for (final t in trucks) {
        final pos = Vector2(t.currentX * 100, t.currentY * 100);
        if (_truckComponents.containsKey(t.id)) {
           _truckComponents[t.id]!.updateTruck(t);
           _truckComponents[t.id]!.position = pos;
        } else {
           final c = MapTruck(truck: t, position: pos);
           _truckComponents[t.id] = c;
           add(c);
        }
      }
    } catch (_) {}
  }
}

class GridComponent extends PositionComponent {
  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF757575)..strokeWidth = 20;
    // Draw Border
    canvas.drawRect(Rect.fromLTWH(0,0,1000,1000), Paint()..style=PaintingStyle.stroke..color=Colors.white..strokeWidth=10);
    // Draw Grid
    for (double i = 0; i <= 1000; i += 100) {
      canvas.drawLine(Offset(i, 0), Offset(i, 1000), paint);
      canvas.drawLine(Offset(0, i), Offset(1000, i), paint);
    }
  }
}