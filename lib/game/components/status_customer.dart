import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/game.dart';
import '../../simulation/models/zone.dart';

/// Customer animation states for status card preview
enum StatusCustomerState {
  walkIn,   // Walking in from left
  idle,     // Facing the machine (idle)
  walkOut,  // Walking out (left or right)
}

/// Flame component that displays an animated customer in the machine status card
/// The customer walks in, faces the machine, then walks out
class StatusCustomer extends SpriteAnimationComponent with HasGameRef<FlameGame> {
  final ZoneType zoneType;
  final double cardWidth;
  final double cardHeight;
  
  // Zone-based person index (0-9)
  late final int personIndex;
  
  // Animations
  late SpriteAnimation _walkAnimation;
  late SpriteAnimation _faceAnimation;
  Vector2? _rawSpriteSize; // The original pixel size of the image
  
  // State machine
  StatusCustomerState _state = StatusCustomerState.walkIn;
  double _stateTimer = 0.0;
  
  // Movement
  double _targetX = 0.0;
  bool _walkingLeft = false; 
  late double _walkSpeed; // Will be calculated relative to width
  static const double _idleDuration = 2.0; 
  
  StatusCustomer({
    required this.zoneType,
    required this.cardWidth,
    required this.cardHeight,
  }) : super(anchor: Anchor.bottomCenter);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // 1. Select person index
    personIndex = _getPersonIndexForZone(zoneType);
    
    // 2. Build animations (loads the raw images)
    _walkAnimation = await _buildWalkAnimation();
    _faceAnimation = await _buildFaceAnimation();
    
    // 3. Set Size Relative to Card
    // We want the person to be 85% of the card's height
    final desiredHeight = cardHeight * 0.85;
    
    // Calculate width based on the image's aspect ratio
    double aspectRatio = 1.0;
    if (_rawSpriteSize != null) {
      aspectRatio = _rawSpriteSize!.x / _rawSpriteSize!.y;
    }
    
    // Apply the scale
    size = Vector2(desiredHeight * aspectRatio, desiredHeight);
    
    // 4. Position
    // Since anchor is BottomCenter, y = cardHeight puts the feet at the bottom edge
    position = Vector2(-size.x, cardHeight);
    
    // 5. Initialize Movement Logic
    _walkSpeed = cardWidth * 0.4; // Takes ~2.5 seconds to cross the card
    _targetX = cardWidth / 2;
    _walkingLeft = Random().nextBool();
    
    // Set initial animation
    animation = _walkAnimation;
  }

  int _getPersonIndexForZone(ZoneType zoneType) {
    final random = Random();
    // 20% chance for "Any" people (Index 8-9)
    if (random.nextDouble() < 0.2) return 8 + random.nextInt(2);

    switch (zoneType) {
      case ZoneType.shop: return random.nextInt(2);
      case ZoneType.gym: return 2 + random.nextInt(2);
      case ZoneType.school: return 4 + random.nextInt(2);
      case ZoneType.office: return 6 + random.nextInt(2);
      case ZoneType.subway:
      case ZoneType.hospital:
      case ZoneType.university:
        // Use random zone-specific person (0-7) for these zones
        return random.nextInt(8);
    }
  }

  Future<SpriteAnimation> _buildWalkAnimation() async {
    final sprites = <Sprite>[];
    for (int i = 0; i < 10; i++) {
      final image = await gameRef.images.load('person_machine/person_machine_walk_$i.png');
      
      final spriteWidth = image.width / 5;
      final spriteHeight = image.height / 2;
      
      // Store raw size from the first frame
      if (_rawSpriteSize == null) {
        _rawSpriteSize = Vector2(spriteWidth, spriteHeight);
      }
      
      final row = personIndex ~/ 5;
      final col = personIndex % 5;
      
      sprites.add(Sprite(
        image,
        srcPosition: Vector2(col * spriteWidth, row * spriteHeight),
        srcSize: Vector2(spriteWidth, spriteHeight),
      ));
    }
    return SpriteAnimation.spriteList(sprites, stepTime: 0.1);
  }

  Future<SpriteAnimation> _buildFaceAnimation() async {
    final sprites = <Sprite>[];
    for (int i = 0; i < 4; i++) {
      try {
        final image = await gameRef.images.load('person_machine/person_machine_face_$i.png');
        final spriteWidth = image.width / 5;
        final spriteHeight = image.height / 2;
        final row = personIndex ~/ 5;
        final col = personIndex % 5;
        sprites.add(Sprite(
          image,
          srcPosition: Vector2(col * spriteWidth, row * spriteHeight),
          srcSize: Vector2(spriteWidth, spriteHeight),
        ));
      } catch (e) {
        // Fallback to back animation if face doesn't exist
        try {
          final backIndex = i + 1;
          final image = await gameRef.images.load('person_machine/person_machine_back_$backIndex.png');
          final spriteWidth = image.width / 5;
          final spriteHeight = image.height / 2;
          final row = personIndex ~/ 5;
          final col = personIndex % 5;
          sprites.add(Sprite(
             image, 
             srcPosition: Vector2(col * spriteWidth, row * spriteHeight),
             srcSize: Vector2(spriteWidth, spriteHeight)
          ));
        } catch (e2) {
           // If all else fails, use the first walk frame
           if (sprites.isNotEmpty) {
             sprites.add(sprites.last);
           } else {
             // Basic fallback prevents crash
             final image = await gameRef.images.load('person_machine/person_machine_walk_0.png');
             final spriteWidth = image.width / 5;
             final spriteHeight = image.height / 2;
             final row = personIndex ~/ 5;
             final col = personIndex % 5;
             sprites.add(Sprite(image, srcPosition: Vector2(col * spriteWidth, row * spriteHeight), srcSize: Vector2(spriteWidth, spriteHeight)));
           }
        }
      }
    }
    return SpriteAnimation.spriteList(sprites, stepTime: 0.15);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    _stateTimer += dt;
    
    switch (_state) {
      case StatusCustomerState.walkIn:
        // Walk right towards center
        if (position.x < _targetX) {
          position.x += _walkSpeed * dt;
          // Ensure facing right (positive scale)
          if (scale.x < 0) scale.x = scale.x.abs(); 
        } else {
          // Reached center
          position.x = _targetX;
          _state = StatusCustomerState.idle;
          _stateTimer = 0.0;
          animation = _faceAnimation;
        }
        break;
        
      case StatusCustomerState.idle:
        if (_stateTimer >= _idleDuration) {
          _state = StatusCustomerState.walkOut;
          animation = _walkAnimation;
          
          if (_walkingLeft) {
            _targetX = -size.x - 20; // Target is off-screen left
            if (scale.x > 0) scale.x = -scale.x; // Flip to face left
          } else {
            _targetX = cardWidth + size.x + 20; // Target is off-screen right
            if (scale.x < 0) scale.x = scale.x.abs(); // Face right
          }
        }
        break;
        
      case StatusCustomerState.walkOut:
        // Determine direction based on target
        double dir = (_targetX > position.x) ? 1 : -1;
        position.x += dir * _walkSpeed * dt;
        
        // Check if we arrived (passed the target point)
        bool arrived = (dir > 0 && position.x > _targetX) || (dir < 0 && position.x < _targetX);
        
        if (arrived) {
           // Reset and restart
           position.x = -size.x;
           _state = StatusCustomerState.walkIn;
           animation = _walkAnimation;
           if (scale.x < 0) scale.x = scale.x.abs(); // Reset face right
           _targetX = cardWidth / 2;
           _walkingLeft = Random().nextBool(); // Randomize next exit
           
           // Optional: Reshuffle person? (Requires reloading logic, easiest is just to keep same person)
        }
        break;
    }
  }
}

