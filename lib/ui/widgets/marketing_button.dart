import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../config.dart';
import '../utils/screen_utils.dart';

/// Marketing Blitz button - appears randomly on the city map after Rush Hour
/// Allows rapid tapping to build hype and trigger Rush Hour
class MarketingButton extends ConsumerStatefulWidget {
  final int gridX;
  final int gridY;
  final Offset screenPosition;
  final double tileWidth;
  final double tileHeight;

  const MarketingButton({
    super.key,
    required this.gridX,
    required this.gridY,
    required this.screenPosition,
    required this.tileWidth,
    required this.tileHeight,
  });

  @override
  ConsumerState<MarketingButton> createState() => _MarketingButtonState();
}

class _MarketingButtonState extends ConsumerState<MarketingButton>
    with TickerProviderStateMixin {
  Timer? _decayTimer;
  Timer? _rushHourTimer;
  Timer? _autoHideTimer; // Timer to auto-hide button after 5 seconds
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  bool _rushHourTimerStarted = false;
  bool _autoHideTimerStarted = false; // Track if auto-hide timer is running

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Flash animation - continuously flashing
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flashAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _flashController,
        curve: Curves.easeInOut,
      ),
    );
    _flashController.repeat(reverse: true);
    
    _startDecayTimer();
    // Auto-hide timer will be started in build() when button is visible
  }

  void _startAutoHideTimer() {
    // Cancel any existing timer
    _autoHideTimer?.cancel();
    _autoHideTimerStarted = true;
    
    // Start 5-second timer to auto-hide button if not pressed
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _autoHideTimerStarted = false;
        final gameState = ref.read(gameStateProvider);
        // Only hide if not in rush hour
        if (!gameState.isRushHour) {
          final controller = ref.read(gameControllerProvider.notifier);
          controller.hideMarketingButton();
        }
      }
    });
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    _rushHourTimer?.cancel();
    _autoHideTimer?.cancel();
    _pulseController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  void _startDecayTimer() {
    _decayTimer?.cancel();
    _decayTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        final gameState = ref.read(gameStateProvider);
        if (!gameState.isRushHour && gameState.hypeLevel > 0.0) {
          final controller = ref.read(gameControllerProvider.notifier);
          final newHype = (gameState.hypeLevel - 0.01).clamp(0.0, 1.0);
          controller.updateHypeLevel(newHype);
        }
      },
    );
  }

  void _onTap() {
    final gameState = ref.read(gameStateProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    
    if (gameState.isRushHour) {
      // Rush Hour is active, don't allow tapping
      return;
    }
    
    // Reset auto-hide timer when button is pressed (resets to 5 seconds)
    _autoHideTimerStarted = false; // Reset flag so timer can restart
    _startAutoHideTimer();
    
    // Add 0.05 (5%) to hype level
    final newHype = (gameState.hypeLevel + 0.05).clamp(0.0, 1.0);
    controller.updateHypeLevel(newHype);
    
    // If hype reaches 100%, trigger Rush Hour
    if (newHype >= 1.0) {
      _startRushHour();
    }
  }

  void _startRushHour() {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.startRushHour();
    
    // Mark that timer is started
    _rushHourTimerStarted = true;
    
    // Start pulse animation
    _pulseController.repeat(reverse: true);
    
    // Cancel decay timer during rush hour
    _decayTimer?.cancel();
    
    // Set timer to end Rush Hour after 10 seconds
    _rushHourTimer?.cancel();
    _rushHourTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _endRushHour();
      }
    });
  }

  void _endRushHour() {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.endRushHour();
    
    // Reset flag
    _rushHourTimerStarted = false;
    
    // Stop pulse animation
    _pulseController.stop();
    _pulseController.reset();
    
    // Restart decay timer
    _startDecayTimer();
    
    // Start auto-hide timer when rush hour ends (button will appear after delay)
    // The timer will start when the button actually appears
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final hypeLevel = gameState.hypeLevel;
    final isRushHour = gameState.isRushHour;
    
    // Start auto-hide timer when button is visible and not in rush hour
    if (!isRushHour && gameState.marketingButtonGridX != null && gameState.marketingButtonGridY != null) {
      // Check if button is at our position (meaning it's visible)
      if (gameState.marketingButtonGridX == widget.gridX && gameState.marketingButtonGridY == widget.gridY) {
        // Start auto-hide timer only if not already started
        if (!_autoHideTimerStarted) {
          _startAutoHideTimer();
        }
      } else {
        // Button position changed, reset timer state
        _autoHideTimerStarted = false;
        _autoHideTimer?.cancel();
      }
    } else {
      // Cancel timer if button is hidden or rush hour is active
      _autoHideTimerStarted = false;
      _autoHideTimer?.cancel();
    }
    
    // Sync rush hour timer when state changes
    if (isRushHour) {
      // If rush hour is active but we don't have a timer, start it
      if (!_rushHourTimerStarted) {
        _rushHourTimerStarted = true;
        _pulseController.repeat(reverse: true);
        _decayTimer?.cancel();
        _rushHourTimer?.cancel();
        _rushHourTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            _endRushHour();
          }
        });
      }
      // Show fire button during Rush Hour
    } else {
      // If rush hour ended, reset flag for next time
      if (_rushHourTimerStarted) {
        _rushHourTimerStarted = false;
      }
    }
    
    // Button size relative to tile - make it smaller
    final buttonSize = widget.tileWidth * 0.5;
    
    // Calculate position on screen (center of the tile)
    final left = widget.screenPosition.dx + (widget.tileWidth - buttonSize) / 2;
    final top = widget.screenPosition.dy + (widget.tileHeight / 2) - buttonSize / 2;
    
    // Determine button appearance based on rush hour state
    final buttonColor = isRushHour ? Colors.orange : Colors.blue;
    final buttonIcon = isRushHour ? Icons.local_fire_department : Icons.campaign;
    final progressColor = isRushHour ? Colors.orange : Colors.blue;
    
    return Positioned(
      left: left,
      top: top,
      width: buttonSize,
      height: buttonSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _flashAnimation]),
        builder: (context, child) {
          final flashAlpha = _flashAnimation.value;
          final pulseScale = isRushHour ? _pulseAnimation.value : 1.0;
          
          return Transform.scale(
            scale: pulseScale,
            child: GestureDetector(
              onTap: _onTap,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: buttonColor.withValues(alpha: 0.5 * flashAlpha),
                      blurRadius: isRushHour ? 20.0 * flashAlpha : 12.0 * flashAlpha,
                      spreadRadius: isRushHour ? 5.0 * flashAlpha : 2.0 * flashAlpha,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Circular progress indicator (background) - only show when not in rush hour
                    if (!isRushHour)
                      SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: CircularProgressIndicator(
                          value: hypeLevel,
                          strokeWidth: ScreenUtils.relativeSize(context, AppConfig.borderWidthFactorMedium * 2),
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                        ),
                      ),
                    // Button background with flashing effect
                    Container(
                      width: buttonSize * 0.85,
                      height: buttonSize * 0.85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: buttonColor.shade400.withValues(alpha: flashAlpha),
                        border: Border.all(
                          color: Colors.white,
                          width: ScreenUtils.relativeSize(context, AppConfig.borderWidthFactorMedium),
                        ),
                      ),
                      child: Icon(
                        buttonIcon,
                        color: Colors.white.withValues(alpha: flashAlpha),
                        size: buttonSize * 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
