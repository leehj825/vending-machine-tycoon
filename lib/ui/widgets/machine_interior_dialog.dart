import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/machine.dart';
import '../../simulation/models/zone.dart';
import '../../state/providers.dart';
import '../../config.dart';
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

class _MachineInteriorDialogState extends ConsumerState<MachineInteriorDialog> {
  late Machine _currentMachine;
  bool _hasCash = false;

  @override
  void initState() {
    super.initState();
    _currentMachine = widget.machine;
    _hasCash = _currentMachine.currentCash > 0;
    
    // Set machine to under maintenance when dialog opens (after build completes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setMaintenanceStatus(true);
      }
    });
  }

  @override
  void dispose() {
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
    
    // TODO: When zone-specific interior images are added, uncomment and use this:
    // String zoneSpecificPath;
    // switch (zoneType) {
    //   case ZoneType.office:
    //     zoneSpecificPath = 'assets/images/machine_interior_office$cashSuffix.png';
    //     break;
    //   case ZoneType.gym:
    //     zoneSpecificPath = 'assets/images/machine_interior_gym$cashSuffix.png';
    //     break;
    //   case ZoneType.school:
    //     zoneSpecificPath = 'assets/images/machine_interior_school$cashSuffix.png';
    //     break;
    //   case ZoneType.shop:
    //     zoneSpecificPath = 'assets/images/machine_interior_shop$cashSuffix.png';
    //     break;
    // }
    // return zoneSpecificPath;
    
    // For now, use generic images until zone-specific ones are added
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

    // TODO: Play paper_cash.mp3 if Zone A tapped, play coin_rattle.mp3 if Zone B tapped
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
                                child: GestureDetector(
                                  onTap: () => _collectCash('A'),
                                  child: Container(
                                    color: Colors.transparent,
                                  ),
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
                                child: GestureDetector(
                                  onTap: () => _collectCash('B'),
                                  child: Container(
                                    color: Colors.transparent,
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
                                width: AppConfig.machineInteriorDialogCashDisplayBorderWidth,
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

