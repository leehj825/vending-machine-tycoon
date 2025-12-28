import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import '../../simulation/models/truck.dart';

/// Component that represents a truck on the city map
class MapTruck extends PositionComponent {
  Truck truck;
  // Simulation coordinates appear to be in "grid units" (e.g., 0-10),
  // while the map renders on a 1000x1000 world with grid lines every 100.
  // Keep the map in pixel/world space by scaling simulation coords.
  static const double _worldScale = 100.0;
  static const double _speed = 100.0; // FIX: Match simulation speed (1 tile/sec * 100 world scale)
  static const double _arrivalThreshold = 2.0; // Distance to consider "arrived"

  MapTruck({
    required this.truck,
    super.position,
  }) : super(
          size: Vector2(30, 20),
          anchor: Anchor.center,
        );

  /// Update the truck reference (for when truck state changes)
  void updateTruck(Truck newTruck) {
    truck = newTruck;
  }

  @override
  void onLoad() {
    super.onLoad();
    // Initialize position from truck's current position
    position = Vector2(truck.currentX * _worldScale, truck.currentY * _worldScale);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update position from truck's current position (synced from simulation)
    final targetPos = Vector2(truck.currentX * _worldScale, truck.currentY * _worldScale);
    
    // Move towards target position
    final direction = targetPos - position;
    final distance = direction.length;

    if (distance > _arrivalThreshold) {
      // Normalize direction and move
      final normalizedDirection = direction.normalized();
      final moveDistance = (_speed * dt).clamp(0.0, distance);
      position += normalizedDirection * moveDistance;
    } else {
      // Snap to target if close enough
      position = targetPos;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw truck body (white rectangle)
    final bodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final bodyRect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(bodyRect, bodyPaint);

    // Draw truck outline (black)
    // Stroke width relative to component size (2% of component width)
    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.x * 0.02; // 2% of component width
    canvas.drawRect(bodyRect, outlinePaint);

    // Draw wheels (black circles)
    final wheelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Front wheels (size relative to component - 8% of width)
    final wheelRadius = size.x * 0.08;
    final wheelOffset = size.x * 0.16;
    canvas.drawCircle(Offset(wheelOffset, size.y), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(wheelOffset, 0), wheelRadius, wheelPaint);

    // Back wheels
    canvas.drawCircle(Offset(size.x - wheelOffset, size.y), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(size.x - wheelOffset, 0), wheelRadius, wheelPaint);

    // Draw cab (smaller rectangle on front)
    final cabPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;
    final cabRect = Rect.fromLTWH(0, 2, size.x * 0.4, size.y - 4);
    canvas.drawRect(cabRect, cabPaint);
    canvas.drawRect(cabRect, outlinePaint);

    // Draw status indicator based on truck status
    _drawStatusIndicator(canvas);
  }

  /// Draw status indicator (small colored dot)
  void _drawStatusIndicator(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;

    switch (truck.status) {
      case TruckStatus.idle:
        paint.color = Colors.grey;
        break;
      case TruckStatus.traveling:
        paint.color = Colors.blue;
        break;
      case TruckStatus.restocking:
        paint.color = Colors.orange;
        break;
    }

    // Draw small circle in top-right corner (size relative to component)
    final indicatorRadius = size.x * 0.06; // 6% of component width
    final indicatorOffset = size.x * 0.1; // 10% offset from edges
    canvas.drawCircle(
      Offset(size.x - indicatorOffset, indicatorOffset),
      indicatorRadius,
      paint,
    );
  }
}

