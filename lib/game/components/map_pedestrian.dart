import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../city_map_game.dart';
import '../../state/providers.dart';
import '../../state/city_map_state.dart';

class MapPedestrian extends SpriteAnimationComponent with HasGameRef<CityMapGame> {
  final int personId; // 0-9
  final WidgetRef ref;
  Vector2? _targetPosition;
  
  late SpriteAnimation _walkFront;
  late SpriteAnimation _walkBack;
  Vector2? _spriteSize;
  
  static const double _speed = 35.0;
  static const double _worldScale = 100.0;

  MapPedestrian({
    required this.personId,
    required this.ref,
    required super.position,
  }) : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Build animations for front and back
    _walkFront = await _buildAnimation('front');
    _walkBack = await _buildAnimation('back');
    
    // Set initial animation
    animation = _walkFront;
    
    // Initialize size from stored sprite size
    if (_spriteSize != null) {
      size = _spriteSize!;
    }
  }

  /// Build animation by loading 10 frames and extracting the sprite for this personId
  Future<SpriteAnimation> _buildAnimation(String direction) async {
    final sprites = <Sprite>[];
    
    // Load each frame (0-9)
    for (int i = 0; i < 10; i++) {
      final image = await gameRef.images.load('pedestrian_walk/walk_${direction}_$i.png');
      
      // Calculate sprite size: 2 rows x 5 columns
      final spriteWidth = image.width / 5;
      final spriteHeight = image.height / 2;
      
      // Store sprite size on first frame (they should all be the same)
      if (_spriteSize == null) {
        _spriteSize = Vector2(spriteWidth, spriteHeight);
      }
      
      // Calculate grid position for this personId
      // Person 0: Row 0, Col 0
      // Person 1: Row 0, Col 1
      // ...
      // Person 4: Row 0, Col 4
      // Person 5: Row 1, Col 0
      // ...
      // Person 9: Row 1, Col 4
      final row = personId ~/ 5;
      final col = personId % 5;
      
      // Extract the specific sprite for this person
      final sprite = Sprite(
        image,
        srcPosition: Vector2(col * spriteWidth, row * spriteHeight),
        srcSize: Vector2(spriteWidth, spriteHeight),
      );
      
      sprites.add(sprite);
    }
    
    return SpriteAnimation.spriteList(sprites, stepTime: 0.1);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update priority for depth sorting (z-index)
    priority = position.y.toInt();
    
    // Get city map state to find road tiles
    final cityMapState = ref.read(gameControllerProvider).cityMapState;
    if (cityMapState == null || cityMapState.grid.isEmpty) return;
    
    // Convert world position to grid coordinates
    final gridX = (position.x / _worldScale).floor();
    final gridY = (position.y / _worldScale).floor();
    
    // Check if we've arrived at target or need a new target
    if (_targetPosition == null || 
        (position - _targetPosition!).length < 5.0) {
      // Find a new target: pick a random adjacent road tile
      final adjacentRoads = _getAdjacentRoadTiles(cityMapState, gridX, gridY);
      
      if (adjacentRoads.isNotEmpty) {
        final random = Random();
        final target = adjacentRoads[random.nextInt(adjacentRoads.length)];
        
        // Convert grid coordinates to world coordinates
        _targetPosition = Vector2(
          target.x * _worldScale + _worldScale / 2,
          target.y * _worldScale + _worldScale / 2,
        );
      } else {
        // No adjacent roads, try to find any nearby road
        final nearbyRoad = _findNearbyRoad(cityMapState, gridX, gridY);
        if (nearbyRoad != null) {
          _targetPosition = Vector2(
            nearbyRoad.x * _worldScale + _worldScale / 2,
            nearbyRoad.y * _worldScale + _worldScale / 2,
          );
        }
      }
    }
    
    // Move towards target
    if (_targetPosition != null) {
      final direction = _targetPosition! - position;
      final distance = direction.length;
      
      if (distance > 1.0) {
        final normalizedDirection = direction.normalized();
        
        // Update animation based on direction
        if (normalizedDirection.y > 0.5) {
          // Moving down (+Y): Use front animation
          animation = _walkFront;
          scale = Vector2(1, 1);
        } else if (normalizedDirection.y < -0.5) {
          // Moving up (-Y): Use back animation
          animation = _walkBack;
          scale = Vector2(1, 1);
        } else if (normalizedDirection.x < 0) {
          // Moving left (-X): Flip horizontally
          animation = _walkFront;
          scale = Vector2(-1, 1);
        } else {
          // Moving right (+X): Normal
          animation = _walkFront;
          scale = Vector2(1, 1);
        }
        
        // Move towards target
        final moveStep = _speed * dt;
        if (distance < moveStep) {
          position = _targetPosition!;
        } else {
          position += normalizedDirection * moveStep;
        }
      } else {
        position = _targetPosition!;
      }
    }
  }
  
  /// Get adjacent road tiles (4 directions: up, down, left, right)
  List<({int x, int y})> _getAdjacentRoadTiles(CityMapState cityMapState, int gridX, int gridY) {
    final adjacentRoads = <({int x, int y})>[];
    final grid = cityMapState.grid;
    
    // Check 4 directions
    final directions = [
      (x: gridX, y: gridY - 1), // Up
      (x: gridX, y: gridY + 1), // Down
      (x: gridX - 1, y: gridY), // Left
      (x: gridX + 1, y: gridY), // Right
    ];
    
    for (final dir in directions) {
      if (dir.y >= 0 && dir.y < grid.length &&
          dir.x >= 0 && dir.x < grid[dir.y].length &&
          grid[dir.y][dir.x] == 'road') {
        adjacentRoads.add(dir);
      }
    }
    
    return adjacentRoads;
  }
  
  /// Find a nearby road tile if current position is not on a road
  ({int x, int y})? _findNearbyRoad(CityMapState cityMapState, int gridX, int gridY) {
    final grid = cityMapState.grid;
    
    // Search in expanding radius
    for (int radius = 1; radius <= 5; radius++) {
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          // Only check tiles on the perimeter of the radius
          if (dx.abs() == radius || dy.abs() == radius) {
            final checkX = gridX + dx;
            final checkY = gridY + dy;
            
            if (checkY >= 0 && checkY < grid.length &&
                checkX >= 0 && checkX < grid[checkY].length &&
                grid[checkY][checkX] == 'road') {
              return (x: checkX, y: checkY);
            }
          }
        }
      }
    }
    
    return null;
  }
}

