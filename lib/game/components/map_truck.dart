import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import '../../simulation/models/truck.dart';

class MapTruck extends PositionComponent {
  Truck truck;
  static const double _worldScale = 100.0;
  static const double _speed = 150.0; // Increased from 100.0 to 150.0 (50% faster) 

  double _targetAngle = 0.0;

  MapTruck({
    required this.truck,
    super.position,
  }) : super(size: Vector2(30, 20), anchor: Anchor.center);

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

    // Ignore (0,0) initialization glitches
    if (targetPos.length2 < 1.0) return;

    final direction = targetPos - position;
    final distance = direction.length;

    // Threshold increased to 3.0 pixels to ignore micro-jitters
    if (distance > 3.0) { 
      final normalizedDirection = direction.normalized();
      
      // Aggressive backward jitter prevention
      bool shouldRotate = true;
      final currentDir = Vector2(cos(angle), sin(angle));
      final dot = currentDir.dot(normalizedDirection);
      
      // If angle difference is > 90 degrees (dot < 0), it's likely a backward jitter
      // Only allow rotation if:
      // 1. Distance is significant (> 15 pixels) indicating a real turn, OR
      // 2. The angle change is reasonable (< 90 degrees)
      if (dot < 0 && distance < 15.0) {
        shouldRotate = false;
      }

      if (shouldRotate) {
        _targetAngle = atan2(normalizedDirection.y, normalizedDirection.x);
        // Smooth rotation instead of instant
        final angleDiff = _targetAngle - angle;
        // Normalize angle difference to [-PI, PI]
        final normalizedDiff = ((angleDiff + pi) % (2 * pi)) - pi;
        // Apply rotation smoothing (lerp factor)
        angle += normalizedDiff * 0.3; // 30% of angle difference per frame
      }

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
    // Draw body
    final bodyPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final bodyRect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(bodyRect, bodyPaint);

    // Draw outline
    final outlinePaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = size.x * 0.05;
    canvas.drawRect(bodyRect, outlinePaint);

    // Draw wheels
    final wheelPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final r = size.x * 0.1;
    final off = size.x * 0.2;
    canvas.drawCircle(Offset(off, size.y), r, wheelPaint);
    canvas.drawCircle(Offset(off, 0), r, wheelPaint);
    canvas.drawCircle(Offset(size.x - off, size.y), r, wheelPaint);
    canvas.drawCircle(Offset(size.x - off, 0), r, wheelPaint);

    // Draw Cab (Right side = Front)
    final cabPaint = Paint()..color = const Color(0xFFE0E0E0)..style = PaintingStyle.fill;
    final cabW = size.x * 0.3; 
    canvas.drawRect(Rect.fromLTWH(size.x - cabW, 2, cabW, size.y - 4), cabPaint);
    canvas.drawRect(Rect.fromLTWH(size.x - cabW, 2, cabW, size.y - 4), outlinePaint);

    // Status dot
    final dotPaint = Paint()..style = PaintingStyle.fill;
    switch (truck.status) {
      case TruckStatus.idle: dotPaint.color = Colors.grey; break;
      case TruckStatus.traveling: dotPaint.color = Colors.blue; break;
      case TruckStatus.restocking: dotPaint.color = Colors.orange; break;
    }
    canvas.drawCircle(Offset(size.x * 0.9, size.y * 0.1), size.x * 0.06, dotPaint);
  }
}
