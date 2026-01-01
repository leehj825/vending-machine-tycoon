import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/game.dart';
import '../../simulation/models/zone.dart';

/// Customer animation states
enum CustomerState {
  walkIn,   // Walking in from left
  face,     // Facing the machine
  walkOut,  // Walking out (left or right)
}

/// Flame component that displays an animated customer in the machine interior dialog
/// The customer walks in, faces the machine, then walks out
class MachineStatusCustomer extends SpriteAnimationComponent with HasGameRef<FlameGame> {
  final ZoneType zoneType;
  final double dialogWidth;
  final double dialogHeight;
  
  // Zone-based person index (0-9)
  late final int personIndex;
  
  // Animations
  late SpriteAnimation _walkAnimation;
  late SpriteAnimation _faceAnimation;
  Vector2? _spriteSize;
  
  // State machine
  CustomerState _state = CustomerState.walkIn;
  double _stateTimer = 0.0;
  
  // Movement
  double _targetX = 0.0;
  bool _walkingLeft = false; // Direction for walkOut
  static const double _walkSpeed = 100.0; // pixels per second
  static const double _faceDuration = 3.0; // seconds to face machine
  
  MachineStatusCustomer({
    required this.zoneType,
    required this.dialogWidth,
    required this.dialogHeight,
  }) : super(anchor: Anchor.bottomCenter);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Select person index based on zone type
    personIndex = _getPersonIndexForZone(zoneType);
    
    // Build animations
    _walkAnimation = await _buildWalkAnimation();
    _faceAnimation = await _buildFaceAnimation();
    
    // Set initial animation
    animation = _walkAnimation;
    
    // Initialize size from sprite
    if (_spriteSize != null) {
      size = _spriteSize!;
    }
    
    // Start position: off-screen left
    position = Vector2(-size.x, dialogHeight - size.y);
    
    // Target position: center of dialog
    _targetX = dialogWidth / 2;
    
    // Randomly decide exit direction (will be set when transitioning to walkOut)
    _walkingLeft = Random().nextBool();
  }

  /// Get person index (0-9) based on zone type
  /// Zone Mapping (Row x Col):
  /// - Shop: Row 1, Col 1 & 2 (Index 0, 1)
  /// - Gym: Row 1, Col 3 & 4 (Index 2, 3)
  /// - School: Row 1, Col 5 & Row 2, Col 1 (Index 4, 5)
  /// - Office: Row 2, Col 2 & 3 (Index 6, 7)
  /// - Any/Other: Row 2, Col 4 & 5 (Index 8, 9)
  int _getPersonIndexForZone(ZoneType zoneType) {
    final random = Random();
    
    // 20% chance to pick the "Any/Common" people (Index 8 or 9)
    // who can appear at ANY machine.
    if (random.nextDouble() < 0.2) {
      return 8 + random.nextInt(2); // Returns 8 or 9
    }

    // Otherwise, pick the zone-specific person
    switch (zoneType) {
      case ZoneType.shop:
        return random.nextInt(2); // 0 or 1
      case ZoneType.gym:
        return 2 + random.nextInt(2); // 2 or 3
      case ZoneType.school:
        return 4 + random.nextInt(2); // 4 or 5
      case ZoneType.office:
        return 6 + random.nextInt(2); // 6 or 7
      case ZoneType.subway:
      case ZoneType.hospital:
      case ZoneType.university:
        // Use random zone-specific person (0-7) for these zones
        return random.nextInt(8);
    }
  }

  /// Build walk animation (10 frames)
  Future<SpriteAnimation> _buildWalkAnimation() async {
    final sprites = <Sprite>[];
    
    // Load each frame (0-9)
    for (int i = 0; i < 10; i++) {
      final image = await gameRef.images.load('person_machine/person_machine_walk_$i.png');
      
      // Calculate sprite size: 2 rows x 5 columns
      final spriteWidth = image.width / 5;
      final spriteHeight = image.height / 2;
      
      // Store sprite size on first frame
      if (_spriteSize == null) {
        _spriteSize = Vector2(spriteWidth, spriteHeight);
      }
      
      // Calculate grid position for this personIndex
      // Row 0: Index 0-4 (Col 0-4)
      // Row 1: Index 5-9 (Col 0-4)
      final row = personIndex ~/ 5;
      final col = personIndex % 5;
      
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

  /// Build face animation (4 frames)
  /// Note: If person_machine_face_ files don't exist, this will try to load them.
  /// If they fail, we can fall back to using the back animation files.
  Future<SpriteAnimation> _buildFaceAnimation() async {
    final sprites = <Sprite>[];
    
    // Try to load face animation frames (0-3)
    for (int i = 0; i < 4; i++) {
      try {
        final image = await gameRef.images.load('person_machine/person_machine_face_$i.png');
        
        // Calculate sprite size: 2 rows x 5 columns
        final spriteWidth = image.width / 5;
        final spriteHeight = image.height / 2;
        
        // Calculate grid position for this personIndex
        final row = personIndex ~/ 5;
        final col = personIndex % 5;
        
        // Extract the specific sprite for this person
        final sprite = Sprite(
          image,
          srcPosition: Vector2(col * spriteWidth, row * spriteHeight),
          srcSize: Vector2(spriteWidth, spriteHeight),
        );
        
        sprites.add(sprite);
      } catch (e) {
        // Fallback: If face files don't exist, try back files
        // This handles the case where files are named person_machine_back_1.png etc.
        try {
          final backIndex = i + 1; // back files are 1-4, not 0-3
          final image = await gameRef.images.load('person_machine/person_machine_back_$backIndex.png');
          
          final spriteWidth = image.width / 5;
          final spriteHeight = image.height / 2;
          
          final row = personIndex ~/ 5;
          final col = personIndex % 5;
          
          final sprite = Sprite(
            image,
            srcPosition: Vector2(col * spriteWidth, row * spriteHeight),
            srcSize: Vector2(spriteWidth, spriteHeight),
          );
          
          sprites.add(sprite);
        } catch (e2) {
          // If both fail, reuse the first walk frame as a placeholder
          if (sprites.isEmpty) {
            final image = await gameRef.images.load('person_machine/person_machine_walk_0.png');
            final spriteWidth = image.width / 5;
            final spriteHeight = image.height / 2;
            final row = personIndex ~/ 5;
            final col = personIndex % 5;
            final sprite = Sprite(
              image,
              srcPosition: Vector2(col * spriteWidth, row * spriteHeight),
              srcSize: Vector2(spriteWidth, spriteHeight),
            );
            sprites.add(sprite);
          } else {
            // Reuse last sprite if we can't load more
            sprites.add(sprites.last);
          }
        }
      }
    }
    
    // If we only have one sprite, duplicate it to make a 4-frame animation
    while (sprites.length < 4) {
      sprites.add(sprites.isNotEmpty ? sprites.last : sprites.first);
    }
    
    return SpriteAnimation.spriteList(sprites, stepTime: 0.15);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    _stateTimer += dt;
    
    switch (_state) {
      case CustomerState.walkIn:
        // Walk right towards center
        if (position.x < _targetX - 5.0) {
          position.x += _walkSpeed * dt;
          // Ensure we don't overshoot
          if (position.x > _targetX) {
            position.x = _targetX;
          }
          // Face right (normal scale)
          scale = Vector2(1, 1);
        } else {
          // Reached center, switch to face state
          position.x = _targetX;
          _state = CustomerState.face;
          _stateTimer = 0.0;
          animation = _faceAnimation;
        }
        break;
        
      case CustomerState.face:
        // Stay in place, face the machine
        if (_stateTimer >= _faceDuration) {
          // Switch to walkOut
          _state = CustomerState.walkOut;
          _stateTimer = 0.0;
          animation = _walkAnimation;
          
          // Set exit target based on random direction
          if (_walkingLeft) {
            _targetX = -size.x; // Off-screen left
            scale = Vector2(-1, 1); // Flip horizontally
          } else {
            _targetX = dialogWidth + size.x; // Off-screen right
            scale = Vector2(1, 1); // Normal
          }
        }
        break;
        
      case CustomerState.walkOut:
        // Walk towards exit
        if (_walkingLeft) {
          // Walking left
          if (position.x > _targetX + 5.0) {
            position.x -= _walkSpeed * dt;
            if (position.x < _targetX) {
              position.x = _targetX;
            }
          } else {
            // Reached exit, remove component
            removeFromParent();
          }
        } else {
          // Walking right
          if (position.x < _targetX - 5.0) {
            position.x += _walkSpeed * dt;
            if (position.x > _targetX) {
              position.x = _targetX;
            }
          } else {
            // Reached exit, remove component
            removeFromParent();
          }
        }
        break;
    }
  }
}

