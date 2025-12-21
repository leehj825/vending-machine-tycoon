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
  double _blinkTimer = 0.0;
  static const double _blinkSpeed = 2.0; // Blinks per second

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
    if (machine.isEmpty) {
      _blinkTimer += dt * _blinkSpeed;
      if (_blinkTimer > 1.0) {
        _blinkTimer -= 1.0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw building based on zone type
    _drawBuilding(canvas, machine.zone.type);

    // Draw status indicator if empty
    if (machine.isEmpty) {
      _drawEmptyIndicator(canvas);
    }
  }

  /// Get size for different zone types
  Vector2 _getSizeForZone(ZoneType zoneType) {
    switch (zoneType) {
      case ZoneType.office:
        return Vector2(40, 60); // Tall rectangle
      case ZoneType.gym:
        return Vector2(50, 50); // Square
      case ZoneType.school:
        return Vector2(45, 45);
      case ZoneType.subway:
        return Vector2(35, 35);
      case ZoneType.park:
        return Vector2(50, 50); // Circle
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

      case ZoneType.subway:
        // Grey rectangle
        paint.color = const Color(0xFF757575);
        canvas.drawRect(rect, paint);
        // Add entrance
        paint.color = const Color(0xFF424242);
        final entranceRect = Rect.fromLTWH(
          size.x / 2 - 10,
          size.y - 15,
          20,
          15,
        );
        canvas.drawRect(entranceRect, paint);
        break;

      case ZoneType.park:
        // Green Circle
        paint.color = const Color(0xFF4CAF50);
        canvas.drawCircle(
          Offset(size.x / 2, size.y / 2),
          size.x / 2,
          paint,
        );
        // Add tree (simple)
        paint.color = const Color(0xFF2E7D32);
        canvas.drawCircle(
          Offset(size.x / 2, size.y / 2),
          size.x / 4,
          paint,
        );
        break;
    }
  }

  /// Draw blinking red exclamation mark indicator for empty machines
  void _drawEmptyIndicator(Canvas canvas) {
    // Only show when blinking (visible 50% of the time)
    if (_blinkTimer > 0.5) return;

    // Draw red circle background
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.x / 2, -20),
      12,
      paint,
    );

    // Draw white exclamation mark
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.x / 2 - textPainter.width / 2, -28),
    );
  }
}

