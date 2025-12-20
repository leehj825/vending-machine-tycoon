import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import 'components/map_machine.dart';
import 'components/map_truck.dart';

import '../simulation/models/machine.dart';

/// Main game class for the city map visualization
class CityMapGame extends FlameGame with HasGameReference, PanDetector, ScaleDetector {
  final WidgetRef ref;
  final void Function(Machine)? onMachineTap;
  final Map<String, MapMachine> _machineComponents = {};
  final Map<String, MapTruck> _truckComponents = {};
  
  // Map bounds (1000x1000 grid)
  static const double mapWidth = 1000.0;
  static const double mapHeight = 1000.0;
  static final Vector2 mapCenter = Vector2(500.0, 500.0);
  
  // Camera constraints
  double _minZoom = 0.5;
  double _maxZoom = 3.0;
  double _currentZoom = 1.0;
  Vector2 _cameraPosition = mapCenter;
  Vector2? _panStartPosition;

  CityMapGame(this.ref, {this.onMachineTap});

  @override
  Color backgroundColor() => const Color(0xFF388E3C);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Setup camera for 1000x1000 grid
    camera.viewfinder.anchor = Anchor.center;
    // Don't use FixedResolutionViewport - let it be responsive

    // Center camera on map
    camera.viewfinder.position = mapCenter;
    
    // Calculate initial zoom to fit map width
    _updateZoom();

    // Add grid background
    add(GridComponent());

    // Initial load of machines and trucks
    _syncMachines();
    _syncTrucks();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Recalculate zoom when screen size changes
    _updateZoom();
  }

  /// Calculate zoom level to fit the map width on screen
  void _updateZoom() {
    if (size.x == 0 || size.y == 0) return;
    
    // Calculate zoom to fit width (portrait mode priority)
    final widthZoom = size.x / mapWidth;
    final heightZoom = size.y / mapHeight;
    
    // Use minimum to ensure entire map is visible
    _currentZoom = (widthZoom < heightZoom ? widthZoom : heightZoom) * 0.95; // 95% to add padding
    
    // Clamp zoom
    _currentZoom = _currentZoom.clamp(_minZoom, _maxZoom);
    
    // Apply zoom
    camera.viewfinder.zoom = _currentZoom;
    
    // Ensure camera stays centered on map
    _clampCameraPosition();
  }

  /// Clamp camera position to keep map visible
  void _clampCameraPosition() {
    final viewportSize = size / _currentZoom;
    final halfViewport = viewportSize / 2;
    
    // Calculate bounds
    final minX = halfViewport.x;
    final maxX = mapWidth - halfViewport.x;
    final minY = halfViewport.y;
    final maxY = mapHeight - halfViewport.y;
    
    // If viewport is larger than map, center the camera
    if (minX >= maxX || minY >= maxY) {
      _cameraPosition = mapCenter;
    } else {
      // Clamp position only if bounds are valid
      _cameraPosition.x = _cameraPosition.x.clamp(minX, maxX);
      _cameraPosition.y = _cameraPosition.y.clamp(minY, maxY);
    }
    
    camera.viewfinder.position = _cameraPosition;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Sync machines and trucks every frame to update positions
    _syncMachines();
    _syncTrucks();
  }

  // Pan (drag) handling
  @override
  bool onPanStart(DragStartInfo info) {
    _panStartPosition = camera.viewfinder.position.clone();
    return true;
  }

  @override
  bool onPanUpdate(DragUpdateInfo info) {
    if (_panStartPosition == null) return false;
    
    // Calculate pan delta in world coordinates
    // EventDelta.global gives us the delta in global coordinate space as Vector2
    final deltaScreen = info.delta.global;
    final delta = deltaScreen / _currentZoom;
    _cameraPosition = _panStartPosition! - delta;
    
    // Clamp camera position
    _clampCameraPosition();
    
    return true;
  }

  @override
  bool onPanEnd(DragEndInfo info) {
    _panStartPosition = null;
    return true;
  }

  // Zoom (pinch) handling
  @override
  bool onScaleStart(ScaleStartInfo info) {
    return true;
  }

  @override
  bool onScaleUpdate(ScaleUpdateInfo info) {
    // Calculate new zoom level
    // ScaleInfo.global is a Vector2, use the average of x and y
    final scaleVector = info.scale.global;
    final scaleFactor = (scaleVector.x + scaleVector.y) / 2.0;
    final newZoom = _currentZoom * scaleFactor;
    _currentZoom = newZoom.clamp(_minZoom, _maxZoom);
    
    // Apply zoom
    camera.viewfinder.zoom = _currentZoom;
    
    // Clamp camera position after zoom
    _clampCameraPosition();
    
    return true;
  }

  @override
  bool onScaleEnd(ScaleEndInfo info) {
    return true;
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

