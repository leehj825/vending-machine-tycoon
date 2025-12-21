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

class CityMapGame extends FlameGame with ScaleDetector, ScrollDetector, TapDetector, PanDetector {
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
  
  // Pan state for single-finger drag
  Vector2? _lastDragPosition;
  Vector2? _panStartPosition;
  bool _isPanning = false;
  static const double _panThreshold = 10.0; // Minimum movement to start panning
  
  // Scale state for pinch-to-zoom
  bool _isScaling = false;
  double _lastScaleFactor = 1.0;

  // Legacy callback
  final void Function(Machine)? onMachineTap;

  CityMapGame(this.ref, {this.onMachineTap});

  @override
  Color backgroundColor() => const Color(0xFF388E3C); // Grass Green

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Setup Camera - ensure it's properly configured
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = mapCenter;
    camera.viewfinder.zoom = 0.5; // Start zoomed out slightly
    
    // Stop any camera following to allow manual control
    camera.stop();
    
    debugPrint('[Camera Setup] position: ${camera.viewfinder.position}, zoom: ${camera.viewfinder.zoom}, anchor: ${camera.viewfinder.anchor}');
    debugPrint('[Camera Setup] viewport: ${camera.viewport.size}');

    // Add Content to world (camera will automatically transform them)
    world.add(GridComponent());

    _syncMachines();
    _syncTrucks();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Only fit to screen on first resize, not on every resize
    // This prevents interfering with user gestures
    if (!_hasInitialized) {
      _fitMapToScreen();
      _hasInitialized = true;
    }
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
    // Pinch-to-zoom gesture started (2 fingers)
    // Cancel any active pan gesture immediately
    _isPanning = false;
    _lastDragPosition = null;
    _panStartPosition = null;
    
    _isScaling = true;
    _startZoom = camera.viewfinder.zoom;
    _lastScaleFactor = 1.0;
    
    debugPrint('[Scale] Started - initial zoom: $_startZoom');
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // Always cancel pan when scale is detected
    _isPanning = false;
    _lastDragPosition = null;
    _panStartPosition = null;
    
    // Always process scale updates - if scale gesture is happening, prioritize it
    if (!_isScaling) {
      _isScaling = true;
      _startZoom = camera.viewfinder.zoom;
      _lastScaleFactor = 1.0;
    }
    
    // Handle pinch-to-zoom (2 fingers)
    // The scale.global represents cumulative scale from gesture start
    // Use .y component which is typically used for pinch gestures
    final scaleFactor = info.scale.global.y;
    
    // Process zoom if scale factor is valid and different from last
    if (!scaleFactor.isNaN && scaleFactor > 0 && scaleFactor != _lastScaleFactor) {
      final newZoom = (_startZoom * scaleFactor).clamp(_minZoom, _maxZoom);
      camera.viewfinder.zoom = newZoom;
      _lastScaleFactor = scaleFactor;
      debugPrint('[Scale] Update - scale: $scaleFactor, zoom: $newZoom (from $_startZoom)');
    }

    // Also handle panning during pinch (when fingers move while pinching)
    final delta = info.delta.global;
    if (delta.x != 0 || delta.y != 0) {
      final worldDelta = delta / camera.viewfinder.zoom;
      camera.viewfinder.position -= worldDelta;
    }
    
    // Clamp camera position
    _clampCamera();
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _isScaling = false;
    _lastScaleFactor = 1.0;
    debugPrint('[Scale] Ended - final zoom: ${camera.viewfinder.zoom}');
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
    
    // Invert scroll direction: scroll up (negative) zooms in, scroll down (positive) zooms out
    // Use a smaller divisor for more responsive zoom
    final zoomFactor = 1.0 - (scrollDelta / 500.0);
    final oldZoom = camera.viewfinder.zoom;
    final newZoom = (oldZoom * zoomFactor).clamp(_minZoom, _maxZoom);
    
    if (newZoom != oldZoom) {
      camera.viewfinder.zoom = newZoom;
      debugPrint('[Mouse Wheel Zoom] scrollDelta: $scrollDelta, zoomFactor: $zoomFactor, oldZoom: $oldZoom, newZoom: $newZoom');
      _clampCamera();
    }
  }

  @override
  void onPanStart(DragStartInfo info) {
    // Only handle pan if not currently scaling (single finger drag)
    // If scale is active, don't start pan
    if (_isScaling) {
      _isPanning = false;
      _lastDragPosition = null;
      _panStartPosition = null;
      debugPrint('[Pan] Start cancelled - scale is active');
      return;
    }
    
    // Store initial position but don't activate pan yet
    // Wait for threshold movement to distinguish from potential pinch
    _panStartPosition = info.eventPosition.widget;
    _lastDragPosition = info.eventPosition.widget;
    _isPanning = false; // Not active until threshold is met
    debugPrint('[Pan] Start detected - waiting for threshold');
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    // If scale is active, cancel pan immediately
    // This is the key: scale gesture takes priority
    if (_isScaling) {
      _isPanning = false;
      _lastDragPosition = null;
      _panStartPosition = null;
      return;
    }
    
    final currentPosition = info.eventPosition.widget;
    
    // If pan hasn't been activated yet, check if we've moved enough
    if (!_isPanning && _panStartPosition != null) {
      final movement = (currentPosition - _panStartPosition!).length;
      if (movement >= _panThreshold) {
        // Enough movement - this is a pan, not a pinch
        _isPanning = true;
        _lastDragPosition = _panStartPosition;
        debugPrint('[Pan] Activated after threshold');
      } else {
        // Not enough movement yet - might be starting a pinch
        _lastDragPosition = currentPosition;
        return;
      }
    }
    
    // Only handle pan if it's active and we have a valid last position
    if (!_isPanning || _lastDragPosition == null) {
      return;
    }
    
    // Calculate drag delta (incremental from last position)
    final delta = currentPosition - _lastDragPosition!;
    
    // Skip if delta is too small (avoid jitter)
    if (delta.length < 0.5) return;
    
    // Convert screen delta to world space for panning
    // Divide by zoom so movement is 1:1 with screen
    final worldDelta = delta / camera.viewfinder.zoom;
    camera.viewfinder.position -= worldDelta;
    
    _lastDragPosition = currentPosition;
    
    // Clamp camera to keep map in view
    _clampCamera();
  }

  @override
  void onPanEnd(DragEndInfo info) {
    _isPanning = false;
    _lastDragPosition = null;
    _panStartPosition = null;
  }

  @override
  void onPanCancel() {
    _isPanning = false;
    _lastDragPosition = null;
    _panStartPosition = null;
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
         // Zone coordinates are in 1.0-9.0 range, map is 1000x1000 with 100px grid cells
         // Grid cells: cell 1 (0-100) center at 50, cell 2 (100-200) center at 150, etc.
         // Zone x=1.0 should map to cell 1 (0-100), zone x=2.0 to cell 2 (100-200), etc.
         // Formula: (zone.x - 1) * 100 + 50 centers in the correct cell
         final pos = Vector2((m.zone.x - 1) * 100 + 50, (m.zone.y - 1) * 100 + 50);
         if (_machineComponents.containsKey(m.id)) {
            _machineComponents[m.id]!.updateMachine(m);
            _machineComponents[m.id]!.position = pos;
         } else {
            final c = MapMachine(machine: m, position: pos);
            _machineComponents[m.id] = c;
            world.add(c);
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
           world.add(c);
        }
      }
    } catch (_) {}
  }
}

class GridComponent extends PositionComponent {
  GridComponent() : super(
    position: Vector2.zero(),
    size: Vector2(CityMapGame.mapWidth, CityMapGame.mapHeight),
  );

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