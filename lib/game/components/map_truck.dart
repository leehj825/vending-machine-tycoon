import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import '../../simulation/models/truck.dart';

/// Component that represents a truck on the city map
class MapTruck extends PositionComponent {
  Truck truck;
  static const double _worldScale = 100.0;
  static const double _speed = 100.0; 

  // Add a smoothing factor for rotation
  double _targetAngle = 0.0;

  MapTruck({
    required this.truck,
    super.position,
  }) : super(
          size: Vector2(30, 20),
          anchor: Anchor.center, // Flame rotates around this anchor automatically
        );

  /// Update the truck reference (for when truck state changes)
  void updateTruck(Truck newTruck) {
    truck = newTruck;
  }

  @override
  void onLoad() {
    super.onLoad();
    position = Vector2(truck.currentX * _worldScale, truck.currentY * _worldScale);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final targetPos = Vector2(truck.currentX * _worldScale, truck.currentY * _worldScale);

    // SAFETY CHECK: Ignore (0,0) targets which occur during simulation init glitches
    if (targetPos == Vector2.zero()) return;

    final direction = targetPos - position;
    final distance = direction.length;

    // Only move/rotate if distance is significant
    if (distance > 0.5) { 
      final normalizedDirection = direction.normalized();
      
      // Calculate target angle based on movement vector
      _targetAngle = atan2(normalizedDirection.y, normalizedDirection.x);
      
      // Set angle directly. Flame's PositionComponent handles the rotation rendering!
      angle = _targetAngle; 

      final moveStep = (_speed * dt);
      if (distance < moveStep) {
         position = targetPos;
      } else {
         position += normalizedDirection * moveStep;
      }
    } else {
      position = targetPos;
    }
  }

  @override
  void render(Canvas canvas) {
    // NOTE: Do NOT call canvas.rotate() or canvas.translate() here.
    // PositionComponent has already handled rotation and positioning for you.
    // The (0,0) point here is the Top-Left of the truck's bounding box.

    // Draw truck body (white rectangle)
    final bodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final bodyRect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(bodyRect, bodyPaint);

    // Draw truck outline
    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.x * 0.05;
    canvas.drawRect(bodyRect, outlinePaint);

    // Draw wheels
    final wheelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final wheelRadius = size.x * 0.1;
    final wheelOffset = size.x * 0.2;
    
    // Top/Bottom relative to truck orientation
    canvas.drawCircle(Offset(wheelOffset, size.y), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(wheelOffset, 0), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(size.x - wheelOffset, size.y), wheelRadius, wheelPaint);
    canvas.drawCircle(Offset(size.x - wheelOffset, 0), wheelRadius, wheelPaint);

    // Draw Cab (Front)
    // FIX: Draw cab on the RIGHT side (positive X) because 0 radians = Right/East
    final cabPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;
    
    // Cab width is 30% of truck, placed at the far right
    final cabWidth = size.x * 0.3; 
    final cabRect = Rect.fromLTWH(size.x - cabWidth, 2, cabWidth, size.y - 4);
    
    canvas.drawRect(cabRect, cabPaint);
    canvas.drawRect(cabRect, outlinePaint);

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
