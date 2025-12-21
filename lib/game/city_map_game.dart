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
  
  final Map<String, MapMachine> _machineComponents = {};
  final Map<String, MapTruck> _truckComponents = {};
  
  static const double mapWidth = 1000.0;
  static const double mapHeight = 1000.0;
  static final Vector2 mapCenter = Vector2(500.0, 500.0);
  
  // FIX: Make nullable to prevent crash if accessed before onLoad finishes
  TextComponent? debugText;
  double _timeSinceLastResize = 0;

  // Legacy callback
  final void Function(Machine)? onMachineTap;

  CityMapGame(this.ref, {this.onMachineTap});

  @override
  Color backgroundColor() => const Color(0xFF222222); // Dark Grey

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 1. Setup Camera
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = mapCenter;
    
    // Default start zoom (Safe value)
    camera.viewfinder.zoom = 0.4;

    // 2. Add Content
    add(GridComponent());
    
    // 3. Add Debug HUD (Attached to HUD so it stays on screen)
    debugText = TextComponent(
      text: "Loading...",
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 20, backgroundColor: Colors.red),
      ),
      position: Vector2(20, 50),
      priority: 100, // Draw on top
    );
    // Add to camera.viewport to make it a HUD (sticks to screen)
    camera.viewport.add(debugText!);

    _syncMachines();
    _syncTrucks();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _forceFit();
  }

  void _forceFit() {
    if (size.x <= 0 || size.y <= 0) return;

    final scaleX = size.x / mapWidth;
    final scaleY = size.y / mapHeight;
    
    // FIX: Multiply by a factor if the screen is high density?
    // Flame uses logical pixels, so size.x should already be correct.
    // If it's zoomed in, it means fitZoom is too large.
    // Let's print out the values to debug on device.
    
    // Use 0.8 to be VERY safe (20% padding)
    final fitZoom = math.min(scaleX, scaleY) * 0.8;

    camera.viewfinder.zoom = fitZoom;
    camera.viewfinder.position = mapCenter;
    
    // FIX: Safe access using '?'
    // If debugText hasn't been created yet, this line is simply skipped
    final dpr = window.devicePixelRatio;
    debugText?.text = "Screen: ${size.x.toStringAsFixed(0)}x${size.y.toStringAsFixed(0)}\nDPR: ${dpr.toStringAsFixed(2)}\nZoom: ${fitZoom.toStringAsFixed(3)}";
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Force a re-check every 1 second to catch any layout bugs
    _timeSinceLastResize += dt;
    if (_timeSinceLastResize > 1.0) {
      _forceFit();
      _timeSinceLastResize = 0;
    }

    _syncMachines();
    _syncTrucks();
  }

  @override
  void onTapUp(TapUpInfo info) {
    // Basic Tap Logic
    final touched = componentsAtPoint(info.eventPosition.widget);
    bool hit = false;
    for (final c in touched) {
      if (c is MapMachine) { hit = true; break; }
    }
    if (!hit) {
      try { ref.read(selectedMachineIdProvider.notifier).state = null; } catch (_) {}
    }
  }

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
    // Draw 1000x1000 Box with RED BORDER
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1000, 1000), 
      Paint()..style = PaintingStyle.stroke..color = Colors.red..strokeWidth = 20
    );
    
    final paint = Paint()..color = const Color(0xFF444444)..strokeWidth = 5;
    for (double i = 0; i <= 1000; i += 100) {
      canvas.drawLine(Offset(i, 0), Offset(i, 1000), paint);
      canvas.drawLine(Offset(0, i), Offset(1000, i), paint);
    }
  }
}