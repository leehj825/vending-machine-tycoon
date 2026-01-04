import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/machine.dart';
import '../../simulation/models/zone.dart';
import '../../state/providers.dart';
import '../../config.dart';
import '../../services/sound_service.dart';
import '../utils/screen_utils.dart';
import '../theme/zone_ui.dart';

/// Dialog that shows the interior of a vending machine with interactive cash collection zones
class MachineInteriorDialog extends ConsumerStatefulWidget {
  final Machine machine;

  const MachineInteriorDialog({
    super.key,
    required this.machine,
  });

  @override
  ConsumerState<MachineInteriorDialog> createState() => _MachineInteriorDialogState();
}

class _MachineInteriorDialogState extends ConsumerState<MachineInteriorDialog> with TickerProviderStateMixin {
  late Machine _currentMachine;
  bool _hasCash = false;
  bool _showTutorial = false;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _currentMachine = widget.machine;
    _hasCash = _currentMachine.currentCash > 0;
    
    // Flash animation - continuously flashing (same as rush sell button)
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
    
    // Check if this is the first time opening with money
    _checkFirstTimeWithMoney();
    
    // Set machine to under maintenance when dialog opens (after build completes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setMaintenanceStatus(true);
      }
    });
  }
  
  /// Check if this is the first time opening machine interior with money
  void _checkFirstTimeWithMoney() {
    // Only show tutorial if money is available
    if (!_hasCash) {
      print('💰 Tutorial check: No cash available, skipping tutorial');
      return;
    }
    
    final gameState = ref.read(gameStateProvider);
    final hasSeenTutorial = gameState.hasSeenMoneyExtractionTutorial;
    
    print('💰 Tutorial check: hasCash=$_hasCash, hasSeenTutorial=$hasSeenTutorial');
    
    if (!hasSeenTutorial) {
      print('💰 Tutorial: Showing blinking circles for first time');
      if (mounted) {
        setState(() {
          _showTutorial = true;
        });
        _flashController.repeat(reverse: true);
      }
      // Tutorial will stay until user collects cash (no auto-hide)
    } else {
      print('💰 Tutorial: Already seen, not showing');
    }
  }
  
  /// Mark the tutorial as seen
  void _markTutorialAsSeen() {
    final controller = ref.read(gameControllerProvider.notifier);
    controller.state = controller.state.copyWith(hasSeenMoneyExtractionTutorial: true);
    if (mounted) {
      setState(() {
        _showTutorial = false;
      });
      _flashController.stop();
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    // Note: Maintenance status is cleared in _handleClose() before dispose is called
    // This is just a safety fallback
    super.dispose();
  }

  /// Handle dialog close - clear maintenance status before popping
  void _handleClose() {
    // Clear maintenance status before closing
    _setMaintenanceStatus(false);
    Navigator.of(context).pop();
  }

  /// Update the machine's maintenance status
  void _setMaintenanceStatus(bool isUnderMaintenance) {
    try {
      final controller = ref.read(gameControllerProvider.notifier);
      final machines = ref.read(machinesProvider);
      final machineId = _currentMachine.id;
      final machineIndex = machines.indexWhere((m) => m.id == machineId);
      
      if (machineIndex != -1) {
        final machine = machines[machineIndex];
        final updatedMachine = machine.copyWith(
          isUnderMaintenance: isUnderMaintenance,
        );
        
        // Debug log
        print('🔧 Machine ${machine.name} maintenance status: $isUnderMaintenance');
        
        // Update state
        controller.updateMachine(updatedMachine);
      }
    } catch (e) {
      // If we can't update (e.g., widget is disposed), log but don't crash
      print('Warning: Could not update maintenance status: $e');
    }
  }

  /// Get the interior image path based on zone type and cash status
  /// Falls back to generic images if zone-specific images don't exist
  String _getInteriorImagePath(ZoneType zoneType, bool hasCash) {
    final cashSuffix = hasCash ? '_with_money' : '_without_money';
    return 'assets/images/machine$cashSuffix.png';
  }

  /// Collect cash from the machine
  void _collectCash(String zone) {
    if (!_hasCash) return;

    final controller = ref.read(gameControllerProvider.notifier);
    final machines = ref.read(machinesProvider);
    final machineIndex = machines.indexWhere((m) => m.id == _currentMachine.id);
    
    if (machineIndex == -1) return;

    final machine = machines[machineIndex];
    final cashToCollect = machine.currentCash;

    if (cashToCollect <= 0) return;

    // Update machine (set cash to 0, preserve maintenance status)
    final updatedMachine = machine.copyWith(
      currentCash: 0.0,
      isUnderMaintenance: machine.isUnderMaintenance, // Preserve maintenance status
    );

    // Add cash to player's wallet
    final currentCash = ref.read(gameStateProvider).cash;
    final newCash = currentCash + cashToCollect;

    // Update state via controller
    controller.updateMachine(updatedMachine);
    controller.updateCash(newCash);

    // Update local state to reflect cash collection
    setState(() {
      _hasCash = false;
      _currentMachine = updatedMachine;
    });
    
    // Hide tutorial if it was showing
    if (_showTutorial) {
      _markTutorialAsSeen();
    }

    // Play coin collect sound
    SoundService().playCoinCollectSound();
    print('Collected \$${cashToCollect.toStringAsFixed(2)} from ${zone == 'A' ? 'Bill Validator' : 'Coin Bin'}');
  }

  @override
  Widget build(BuildContext context) {
    // Get the latest machine state
    final machines = ref.watch(machinesProvider);
    final latestMachine = machines.firstWhere(
      (m) => m.id == widget.machine.id,
      orElse: () => _currentMachine,
    );
    
    // Update local state if machine changed externally
    if (latestMachine.currentCash != _currentMachine.currentCash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentMachine = latestMachine;
            _hasCash = latestMachine.currentCash > 0;
          });
        }
      });
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogMaxWidth = screenWidth * AppConfig.machineInteriorDialogWidthFactor;
    final dialogMaxHeight = screenHeight * AppConfig.machineInteriorDialogHeightFactor;

    // Determine which image to show based on zone type and cash status
    final imagePath = _getInteriorImagePath(widget.machine.zone.type, _hasCash);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleClose();
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(
          ScreenUtils.relativeSize(context, AppConfig.machineInteriorDialogInsetPaddingFactor),
        ),
        child: LayoutBuilder(
        builder: (context, constraints) {
          final dialogWidth = constraints.maxWidth;
          final imageHeight = dialogWidth * AppConfig.machineInteriorDialogImageHeightFactor;
          final borderRadius = dialogWidth * AppConfig.machineInteriorDialogBorderRadiusFactor;
          final padding = dialogWidth * AppConfig.machineInteriorDialogPaddingFactor;

          return Container(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: dialogMaxHeight,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Stack(
                  children: [
                    // Image with interactive zones
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(borderRadius),
                        topRight: Radius.circular(borderRadius),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: imageHeight,
                        // Zone-specific background color
                        color: widget.machine.zone.type.color.withValues(
                          alpha: AppConfig.machineInteriorDialogZoneBackgroundAlpha,
                        ),
                        child: Stack(
                          children: [
                            // Background image
                            Image.asset(
                              imagePath,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: imageHeight,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: imageHeight,
                                  color: Colors.grey[800],
                                  child: Center(
                                    child: Text(
                                      'Machine interior image not found',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: dialogWidth * AppConfig.machineInteriorDialogErrorTextFontSizeFactor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Zone A: Bill Validator/Cash Stack area (top-right area)
                            // Positioned approximately in the upper-right portion
                            if (_hasCash)
                              Positioned(
                                left: dialogWidth * AppConfig.machineInteriorDialogZoneALeftFactor,
                                top: imageHeight * AppConfig.machineInteriorDialogZoneATopFactor,
                                width: dialogWidth * AppConfig.machineInteriorDialogZoneAWidthFactor,
                                height: imageHeight * AppConfig.machineInteriorDialogZoneAHeightFactor,
                                child: Stack(
                                  children: [
                                    // Touchable area (behind the circle)
                                    GestureDetector(
                                      onTap: () => _collectCash('A'),
                                      child: Container(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                    // Blinking circle indicator (first time only) - on top
                                    if (_showTutorial)
                                      Positioned.fill(
                                        child: AnimatedBuilder(
                                          animation: _flashAnimation,
                                          builder: (context, child) {
                                            final flashAlpha = _flashAnimation.value;
                                            final zoneWidth = dialogWidth * AppConfig.machineInteriorDialogZoneAWidthFactor;
                                            final zoneHeight = imageHeight * AppConfig.machineInteriorDialogZoneAHeightFactor;
                                            final circleSize = (zoneWidth > zoneHeight ? zoneWidth : zoneHeight) * 1.7;
                                            
                                            return Center(
                                              child: IgnorePointer(
                                                child: Container(
                                                  width: circleSize,
                                                  height: circleSize,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.green.withValues(alpha: flashAlpha),
                                                      width: 4.0,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.green.withValues(alpha: 0.5 * flashAlpha),
                                                        blurRadius: 12.0 * flashAlpha,
                                                        spreadRadius: 2.0 * flashAlpha,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            // Zone B: Coin Drop/Bin area (bottom area)
                            // Positioned approximately in the lower portion
                            if (_hasCash)
                              Positioned(
                                left: dialogWidth * AppConfig.machineInteriorDialogZoneBLeftFactor,
                                top: imageHeight * AppConfig.machineInteriorDialogZoneBTopFactor,
                                width: dialogWidth * AppConfig.machineInteriorDialogZoneBWidthFactor,
                                height: imageHeight * AppConfig.machineInteriorDialogZoneBHeightFactor,
                                child: Stack(
                                  children: [
                                    // Touchable area (behind the circle)
                                    GestureDetector(
                                      onTap: () => _collectCash('B'),
                                      child: Container(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                    // Blinking circle indicator (first time only) - on top
                                    if (_showTutorial)
                                      Positioned.fill(
                                        child: AnimatedBuilder(
                                          animation: _flashAnimation,
                                          builder: (context, child) {
                                            final flashAlpha = _flashAnimation.value;
                                            final zoneWidth = dialogWidth * AppConfig.machineInteriorDialogZoneBWidthFactor;
                                            final zoneHeight = imageHeight * AppConfig.machineInteriorDialogZoneBHeightFactor;
                                            final circleSize = (zoneWidth > zoneHeight ? zoneWidth : zoneHeight) * 1.7;
                                            
                                            return Center(
                                              child: IgnorePointer(
                                                child: Container(
                                                  width: circleSize,
                                                  height: circleSize,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.green.withValues(alpha: flashAlpha),
                                                      width: 4.0,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.green.withValues(alpha: 0.5 * flashAlpha),
                                                        blurRadius: 12.0 * flashAlpha,
                                                        spreadRadius: 2.0 * flashAlpha,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            // Tutorial message (similar to rush sell message)
                            if (_showTutorial)
                              Positioned(
                                left: dialogWidth * 0.1,
                                top: imageHeight * 0.1,
                                right: dialogWidth * 0.1,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: dialogWidth * 0.8,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: padding * 0.5,
                                    vertical: padding * 0.3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(padding * AppConfig.machineInteriorDialogCashDisplayBorderRadiusFactor),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: dialogWidth * AppConfig.machineInteriorDialogCashDisplayBorderWidthFactor * 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.touch_app,
                                        color: Colors.white,
                                        size: dialogWidth * AppConfig.machineInteriorDialogCloseButtonSizeFactor * 0.6,
                                      ),
                                      SizedBox(width: padding * 0.3),
                                      Flexible(
                                        child: Text(
                                          'Tap the green circles to collect cash!',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: ScreenUtils.relativeFontSize(
                                              context,
                                              AppConfig.fontSizeFactorSmall,
                                              min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                              max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                            ),
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Close button
                    Positioned(
                      top: padding,
                      right: padding,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: dialogWidth * AppConfig.machineInteriorDialogCloseButtonSizeFactor,
                        ),
                        onPressed: _handleClose,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          padding: EdgeInsets.all(padding * AppConfig.machineInteriorDialogCloseButtonPaddingFactor),
                        ),
                      ),
                    ),
                  ],
                ),
                // Info section - scrollable
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Cash amount display
                          Container(
                            padding: EdgeInsets.all(padding),
                            decoration: BoxDecoration(
                              color: _hasCash ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(padding * AppConfig.machineInteriorDialogCashDisplayBorderRadiusFactor),
                              border: Border.all(
                                color: _hasCash ? Colors.green : Colors.grey,
                                width: dialogWidth * AppConfig.machineInteriorDialogCashDisplayBorderWidthFactor,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Cash Available',
                                  style: TextStyle(
                                    fontSize: ScreenUtils.relativeFontSize(
                                      context,
                                      AppConfig.fontSizeFactorSmall,
                                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                    ),
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: padding * AppConfig.machineInteriorDialogCashDisplaySpacingFactor),
                                Text(
                                  '\$${_currentMachine.currentCash.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: ScreenUtils.relativeFontSize(
                                      context,
                                      AppConfig.fontSizeFactorLarge,
                                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    color: _hasCash ? Colors.green.shade700 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: padding * AppConfig.machineInteriorDialogContentSpacingFactor),
                          if (_hasCash)
                            Text(
                              'Tap on the bill validator or coin bin to collect cash',
                              style: TextStyle(
                                fontSize: ScreenUtils.relativeFontSize(
                                  context,
                                  AppConfig.fontSizeFactorSmall,
                                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                ),
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            )
                          else
                            Text(
                              'No cash available',
                              style: TextStyle(
                                fontSize: ScreenUtils.relativeFontSize(
                                  context,
                                  AppConfig.fontSizeFactorSmall,
                                  min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                                  max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                                ),
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

