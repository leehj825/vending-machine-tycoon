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
          anchor: Anchor.center, 
        );

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

    // 1. Ignore initialization glitches (0,0)
    if (targetPos.length2 < 1.0) return;

    final direction = targetPos - position;
    final distance = direction.length;

    // 2. Only move if distance is significant (> 1 pixel)
    if (distance > 1.0) { 
      
      // 3. Visual Smoothing: Don't rotate for tiny backward jitters
      // If the target is extremely close (< 5 pixels) but requires a 
      // sharp turn (> 90 degrees), it's likely a glitch. Ignore rotation.
      bool shouldRotate = true;
      if (distance < 5.0) {
        final currentDir = Vector2(cos(angle), sin(angle));
        final newDir = direction.normalized();
        final dot = currentDir.dot(newDir);
        if (dot < 0) { // Angle difference > 90 degrees (turning back)
          shouldRotate = false;
        }
      }

      if (shouldRotate) {
        final normalizedDirection = direction.normalized();
        _targetAngle = atan2(normalizedDirection.y, normalizedDirection.x);
        angle = _targetAngle; 
      }

      // Move
      final moveStep = (_speed * dt);
      if (distance < moveStep) {
         position = targetPos;
      } else {
         position += direction.normalized() * moveStep;
      }
    } else {
      // We are at the target
      position = targetPos;
    }
  }

  @override
  void render(Canvas canvas) {
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

    // Draw Cab (Front - Right Side)
    final cabPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;
    
    final cabWidth = size.x * 0.3; 
    final cabRect = Rect.fromLTWH(size.x - cabWidth, 2, cabWidth, size.y - 4);
    
    canvas.drawRect(cabRect, cabPaint);
    canvas.drawRect(cabRect, outlinePaint);

    _drawStatusIndicator(canvas);
  }

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

    final indicatorRadius = size.x * 0.06;
    final indicatorOffset = size.x * 0.1;
    canvas.drawCircle(
      Offset(size.x - indicatorOffset, indicatorOffset),
      indicatorRadius,
      paint,
    );
  }
}
