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
  double _lastScale = 1.0;

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
    camera.viewfinder.zoom = 0.5; // Start zoomed out slightly

    // Add Content
    add(GridComponent());

    _syncMachines();
    _syncTrucks();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _fitMapToScreen();
  }

  void _fitMapToScreen() {
    if (size.x <= 0 || size.y <= 0) return;

    final scaleX = size.x / mapWidth;
    final scaleY = size.y / mapHeight;
    
    // Fit map to screen with margin
    final fitZoom = math.min(scaleX, scaleY) * 0.9;
    
    camera.viewfinder.zoom = fitZoom;
    camera.viewfinder.position = mapCenter;
    
    // Set minimum zoom so user can't zoom out past the full map
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
    // Reset scale tracker
    _lastScale = 1.0;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // 1. Zoom (Incremental)
    final currentScale = info.scale.global.x;
    if (!currentScale.isNaN && currentScale > 0) {
      final scaleDelta = currentScale / _lastScale;
      final newZoom = (camera.viewfinder.zoom * scaleDelta).clamp(_minZoom, _maxZoom);
      camera.viewfinder.zoom = newZoom;
      _lastScale = currentScale;
    }

    // 2. Pan
    // Divide by zoom so movement is 1:1
    final delta = info.delta.global / camera.viewfinder.zoom;
    camera.viewfinder.position -= delta;

    // 3. Clamp
    _clampCamera();
  }

  void _clampCamera() {
    // Basic clamping to keep map in view
    // Allow viewing slightly outside the map (padding)
    const padding = 200.0;
    
    final x = camera.viewfinder.position.x;
    final y = camera.viewfinder.position.y;
    
    camera.viewfinder.position.x = x.clamp(-padding, mapWidth + padding);
    camera.viewfinder.position.y = y.clamp(-padding, mapHeight + padding);
  }

  @override
  void onScroll(PointerScrollInfo info) {
    // Mouse wheel zoom
    final scrollDelta = info.scrollDelta.global.y;
    final zoomFactor = 1.0 - (scrollDelta / 1000.0);
    camera.viewfinder.zoom = (camera.viewfinder.zoom * zoomFactor).clamp(_minZoom, _maxZoom);
    _clampCamera();
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
      _machineComponents.keys.where((id) => !machineIds.contains(id)).toList().forEach((id) {
         _machineComponents.remove(id)?.removeFromParent();
      });
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
      _truckComponents.keys.where((id) => !truckIds.contains(id)).toList().forEach((id) {
         _truckComponents.remove(id)?.removeFromParent();
      });
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
    // Normal Grid
    final paint = Paint()..color = const Color(0xFF757575)..strokeWidth = 20;
    for (double i = 0; i <= 1000; i += 100) {
      canvas.drawLine(Offset(i, 0), Offset(i, 1000), paint);
      canvas.drawLine(Offset(0, i), Offset(1000, i), paint);
    }
  }
}