import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart'; // Import for PointerScrollInfo
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import 'components/map_machine.dart';
import 'components/map_truck.dart';
import '../simulation/models/machine.dart';

// 1. REMOVED PanDetector. It conflicts with ScaleDetector.
class CityMapGame extends FlameGame with ScaleDetector, ScrollDetector, TapDetector {
  final WidgetRef ref;
  
  final Map<String, MapMachine> _machineComponents = {};
  final Map<String, MapTruck> _truckComponents = {};
  
  static const double mapWidth = 1000.0;
  static const double mapHeight = 1000.0;
  static final Vector2 mapCenter = Vector2(500.0, 500.0);
  
  // Camera State
  double _minZoom = 0.1;
  double _maxZoom = 5.0;
  double _startZoom = 1.0;
  bool _hasInitialized = false;
  
  // Legacy callback
  final void Function(Machine)? onMachineTap;

  CityMapGame(this.ref, {this.onMachineTap});

  @override
  Color backgroundColor() => const Color(0xFF388E3C); // Grass Green

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Setup Camera
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = mapCenter;
    camera.viewfinder.zoom = 0.5;
    camera.stop(); // Manual control

    world.add(GridComponent());

    _syncMachines();
    _syncTrucks();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_hasInitialized) {
      _fitMapToScreen();
      _hasInitialized = true;
    }
  }

  void _fitMapToScreen() {
    if (size.x <= 0 || size.y <= 0) return;
    final scaleX = size.x / mapWidth;
    final scaleY = size.y / mapHeight;
    final fitZoom = math.min(scaleX, scaleY) * 0.9;
    camera.viewfinder.zoom = fitZoom;
    camera.viewfinder.position = mapCenter;
    _minZoom = fitZoom;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncMachines();
    _syncTrucks();
  }

  // --- GESTURES ---

  @override
  void onScaleStart(ScaleStartInfo info) {
    // Record current zoom when user puts fingers down
    _startZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // 1. Handle ZOOM (Pinch)
    // info.scale.global returns the scale factor since the start of the gesture
    final currentScale = info.scale.global;
    
    if (!currentScale.isIdentity()) {
      // Use the average of x and y scale for uniformity, or just y
      final scaleAmount = currentScale.y; 
      final newZoom = (_startZoom * scaleAmount).clamp(_minZoom, _maxZoom);
      camera.viewfinder.zoom = newZoom;
    }

    // 2. Handle PAN (Drag)
    // ScaleDetector provides 'delta' which is the movement of the focal point.
    // This works for 1 finger (pan) AND 2 fingers (pan while pinching).
    final delta = info.delta.global;
    
    // Divide delta by zoom to ensure movement stays 1:1 with finger
    final worldDelta = delta / camera.viewfinder.zoom;
    camera.viewfinder.position -= worldDelta;

    _clampCamera();
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    // No cleanup needed usually, but useful for debugging
  }

  // Mouse Wheel Zoom
  @override
  void onScroll(PointerScrollInfo info) {
    final scrollDelta = info.scrollDelta.global.y;
    final zoomFactor = 1.0 - (scrollDelta / 500.0);
    final oldZoom = camera.viewfinder.zoom;
    final newZoom = (oldZoom * zoomFactor).clamp(_minZoom, _maxZoom);
    
    if (newZoom != oldZoom) {
      camera.viewfinder.zoom = newZoom;
      _clampCamera();
    }
  }

  void _clampCamera() {
    const padding = 200.0;
    final x = camera.viewfinder.position.x;
    final y = camera.viewfinder.position.y;
    camera.viewfinder.position.x = x.clamp(-padding, mapWidth + padding);
    camera.viewfinder.position.y = y.clamp(-padding, mapHeight + padding);
  }

  @override
  void onTapUp(TapUpInfo info) {
    final touched = componentsAtPoint(info.eventPosition.widget);
    bool hit = false;
    for (final c in touched) {
      if (c is MapMachine) { hit = true; break; }
    }
    if (!hit) {
      try { ref.read(selectedMachineIdProvider.notifier).state = null; } catch (_) {}
    }
  }

  // --- SYNC LOGIC ---
  void _syncMachines() {
    try {
      final machines = ref.read(machinesProvider);
      final machineIds = machines.map((m) => m.id).toSet();
      
      // Iterate existing keys directly instead of creating a new list
      final keysToRemove = <String>[];
      for (final id in _machineComponents.keys) {
        if (!machineIds.contains(id)) {
          keysToRemove.add(id);
        }
      }
      for (final id in keysToRemove) {
        _machineComponents.remove(id)?.removeFromParent();
      }
      
      for (final m in machines) {
         final blockX = (m.zone.x - 1.0).floor();
         final blockY = (m.zone.y - 1.0).floor();
         final posX = blockX * 100.0 + 50.0;
         final posY = blockY * 100.0 + 50.0;
         final pos = Vector2(posX, posY);
         
         if (_machineComponents.containsKey(m.id)) {
            _machineComponents[m.id]!.updateMachine(m);
            _machineComponents[m.id]!.position = pos;
         } else {
            final c = MapMachine(machine: m, position: pos);
            _machineComponents[m.id] = c;
            world.add(c);
         }
      }
    } catch (e, stack) {
      debugPrint("Error syncing machines: $e");
      debugPrint("Stack trace: $stack");
    }
  }

  void _syncTrucks() {
    try {
      final trucks = ref.read(trucksProvider);
      final truckIds = trucks.map((t) => t.id).toSet();
      
      // Iterate existing keys directly instead of creating a new list
      final keysToRemove = <String>[];
      for (final id in _truckComponents.keys) {
        if (!truckIds.contains(id)) {
          keysToRemove.add(id);
        }
      }
      for (final id in keysToRemove) {
        _truckComponents.remove(id)?.removeFromParent();
      }
      
      for (final t in trucks) {
        // Trucks must always stay on roads (integer coordinates)
        // Round to road coordinates for all truck states
        final roadX = t.currentX.round().toDouble();
        final roadY = t.currentY.round().toDouble();
        final posX = roadX * 100;
        final posY = roadY * 100;
        final pos = Vector2(posX, posY);
        if (_truckComponents.containsKey(t.id)) {
           _truckComponents[t.id]!.updateTruck(t);
           _truckComponents[t.id]!.position = pos;
        } else {
           final c = MapTruck(truck: t, position: pos);
           _truckComponents[t.id] = c;
           world.add(c);
        }
      }
    } catch (e, stack) {
      debugPrint("Error syncing trucks: $e");
      debugPrint("Stack trace: $stack");
    }
  }
}

class GridComponent extends PositionComponent {
  GridComponent() : super(
    position: Vector2.zero(),
    size: Vector2(CityMapGame.mapWidth, CityMapGame.mapHeight),
  );

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF757575)..strokeWidth = 20;
    for (double i = 0; i <= 1000; i += 100) {
      canvas.drawLine(Offset(i, 0), Offset(i, 1000), paint);
      canvas.drawLine(Offset(0, i), Offset(1000, i), paint);
    }
  }
}