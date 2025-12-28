import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../../simulation/models/machine.dart';
import '../../simulation/models/zone.dart';
import '../city_map_game.dart';
import '../../state/providers.dart';

/// Component that represents a machine on the city map
class MapMachine extends PositionComponent with TapCallbacks, HasGameReference<CityMapGame> {
  Machine machine;

  MapMachine({
    required this.machine,
    super.position,
    super.size,
  }) : super(anchor: Anchor.center);

  @override
  void onTapUp(TapUpEvent event) {
    // Update the selected machine in the state
    try {
      // Access the ref through the game instance
      game.ref.read(selectedMachineIdProvider.notifier).state = machine.id;
    } catch (e) {
      print('Error selecting machine: $e');
    }
    
    // Call the legacy callback if it exists (for debugging/toast)
    game.onMachineTap?.call(machine);
  }

  /// Update the machine reference (for when machine state changes)
  void updateMachine(Machine newMachine) {
    machine = newMachine;
    // Update size if zone type changed
    final newSize = _getSizeForZone(machine.zone.type);
    if (size != newSize) {
      size = newSize;
    }
  }

  @override
  void onLoad() {
    super.onLoad();
    // Set size based on zone type
    size = _getSizeForZone(machine.zone.type);
  }

  @override
  void update(double dt) {
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw building based on zone type
    _drawBuilding(canvas, machine.zone.type);
  }

  /// Get size for different zone types
  Vector2 _getSizeForZone(ZoneType zoneType) {
    switch (zoneType) {
      case ZoneType.shop:
        return Vector2(50, 50); // Circle
      case ZoneType.office:
        return Vector2(40, 60); // Tall rectangle
      case ZoneType.gym:
        return Vector2(50, 50); // Square
      case ZoneType.school:
        return Vector2(45, 45);
    }
  }

  /// Draw building procedurally based on zone type
  void _drawBuilding(Canvas canvas, ZoneType zoneType) {
    final paint = Paint();
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    switch (zoneType) {
      case ZoneType.office:
        // Tall Blue Rectangle
        paint.color = const Color(0xFF2196F3); // Blue
        canvas.drawRect(rect, paint);
        // Add windows
        paint.color = const Color(0xFF1976D2);
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 4; j++) {
            final windowRect = Rect.fromLTWH(
              5 + j * 10,
              5 + i * 15,
              8,
              10,
            );
            canvas.drawRect(windowRect, paint);
          }
        }
        break;

      case ZoneType.gym:
        // Orange Square with roof
        paint.color = const Color(0xFFFF9800); // Orange
        canvas.drawRect(rect, paint);
        // Draw roof (triangle)
        final roofPath = Path()
          ..moveTo(0, 0)
          ..lineTo(size.x / 2, -15)
          ..lineTo(size.x, 0)
          ..close();
        paint.color = const Color(0xFFE65100);
        canvas.drawPath(roofPath, paint);
        // Add door
        paint.color = const Color(0xFF8D6E63);
        final doorRect = Rect.fromLTWH(
          size.x / 2 - 8,
          size.y - 20,
          16,
          20,
        );
        canvas.drawRect(doorRect, paint);
        break;

      case ZoneType.school:
        // Purple rectangle
        paint.color = const Color(0xFF9C27B0);
        canvas.drawRect(rect, paint);
        // Add bell on top
        paint.color = const Color(0xFFFFD700);
        canvas.drawCircle(
          Offset(size.x / 2, -10),
          8,
          paint,
        );
        break;

      case ZoneType.shop:
        // Blue Circle (shop)
        paint.color = const Color(0xFF2196F3);
        canvas.drawCircle(
          Offset(size.x / 2, size.y / 2),
          size.x / 2,
          paint,
        );
        // Add shopping cart icon (simple representation)
        paint.color = Colors.white;
        canvas.drawCircle(
          Offset(size.x / 2, size.y / 2),
          size.x / 4,
          paint,
        );
        break;
    }
  }
}

