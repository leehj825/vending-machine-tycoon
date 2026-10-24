import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/vex_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/models/machine.dart';
import '../../state/providers.dart';
import '../../config.dart';
import '../../services/sound_service.dart';
import '../theme/vex_widgets.dart';
import '../three_d/vending_machine_3d.dart';
import '../utils/screen_utils.dart';
import '../theme/zone_ui.dart';
import 'machine_upgrade_dialog.dart';

/// Dialog that shows the interior of a vending machine with interactive cash collection zones
class MachineInteriorDialog extends ConsumerStatefulWidget {
  final Machine machine;

  const MachineInteriorDialog({super.key, required this.machine});

  @override
  ConsumerState<MachineInteriorDialog> createState() =>
      _MachineInteriorDialogState();
}

class _MachineInteriorDialogState extends ConsumerState<MachineInteriorDialog>
    with TickerProviderStateMixin {
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
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
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

    print(
      '💰 Tutorial check: hasCash=$_hasCash, hasSeenTutorial=$hasSeenTutorial',
    );

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
    controller.state = controller.state.copyWith(
      hasSeenMoneyExtractionTutorial: true,
    );
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
        print(
          '🔧 Machine ${machine.name} maintenance status: $isUnderMaintenance',
        );

        // Update state
        controller.updateMachine(updatedMachine);
      }
    } catch (e) {
      // If we can't update (e.g., widget is disposed), log but don't crash
      print('Warning: Could not update maintenance status: $e');
    }
  }

  /// Get the interior image path based on zone type and cash status
  /// Open the machine upgrade dialog
  void _openUpgrades() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MachineUpgradeDialog(machine: _currentMachine),
    );
  }

  /// Collect cash from the machine
  void _collectCash(String zone) {
    if (!_hasCash) return;

    final controller = ref.read(gameControllerProvider.notifier);
    final cashToCollect = controller.collectMachineCash(_currentMachine.id);
    if (cashToCollect <= 0) return;

    // Update local state to reflect cash collection
    setState(() {
      _hasCash = false;
      _currentMachine = _currentMachine.copyWith(currentCash: 0.0);
    });

    // Hide tutorial if it was showing
    if (_showTutorial) {
      _markTutorialAsSeen();
    }

    // Play coin collect sound
    SoundService().playCoinCollectSound();
    print(
      'Collected \$${cashToCollect.toStringAsFixed(2)} from ${zone == 'A' ? 'Bill Validator' : 'Coin Bin'}',
    );
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
    // In landscape the screen is short, so the width also follows the height.
    final dialogMaxWidth = math.min(
      screenWidth * AppConfig.machineInteriorDialogWidthFactor,
      screenHeight * AppConfig.machineInteriorDialogLandscapeHeightFactor,
    );
    final dialogMaxHeight =
        screenHeight * AppConfig.machineInteriorDialogHeightFactor;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleClose();
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(
          ScreenUtils.relativeSize(
            context,
            AppConfig.machineInteriorDialogInsetPaddingFactor,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dialogWidth = constraints.maxWidth;
            final imageHeight =
                dialogWidth * AppConfig.machineInteriorDialogImageHeightFactor;
            final borderRadius =
                dialogWidth * AppConfig.machineInteriorDialogBorderRadiusFactor;
            final padding =
                dialogWidth * AppConfig.machineInteriorDialogPaddingFactor;

            return Container(
              constraints: BoxConstraints(
                maxWidth: dialogMaxWidth,
                maxHeight: dialogMaxHeight,
              ),
              decoration: BoxDecoration(
                color: VexColors.panel,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              // Scrolls if a short screen still cannot fit everything.
              child: SingleChildScrollView(
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
                              alpha: AppConfig
                                  .machineInteriorDialogZoneBackgroundAlpha,
                            ),
                            child: Stack(
                              children: [
                                // The machine in 3D. Drag to turn it.
                                VendingMachine3DView(
                                  machine: _currentMachine,
                                  height: imageHeight,
                                  showCaption: false,
                                ),
                                // One button collects the cash, shown while there is cash.
                                if (_hasCash)
                                  Positioned(
                                    right: padding,
                                    bottom: padding,
                                    child: VexButton(
                                      label: 'Collect cash',
                                      icon: Icons.payments,
                                      primary: true,
                                      onPressed: () => _collectCash('A'),
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
                                        color: Colors.green.shade700.withValues(
                                          alpha: 0.95,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          padding *
                                              AppConfig
                                                  .machineInteriorDialogCashDisplayBorderRadiusFactor,
                                        ),
                                        border: Border.all(
                                          color: Colors.white,
                                          width:
                                              dialogWidth *
                                              AppConfig
                                                  .machineInteriorDialogCashDisplayBorderWidthFactor *
                                              2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.touch_app,
                                            color: Colors.white,
                                            size:
                                                dialogWidth *
                                                AppConfig
                                                    .machineInteriorDialogCloseButtonSizeFactor *
                                                0.6,
                                          ),
                                          SizedBox(width: padding * 0.3),
                                          Flexible(
                                            child: Text(
                                              'Tap the green circles to collect cash!',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize:
                                                    ScreenUtils.relativeFontSize(
                                                      context,
                                                      AppConfig
                                                          .fontSizeFactorSmall,
                                                    ),
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
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
                        // Upgrade button (top-left)
                        Positioned(
                          top: padding,
                          left: padding,
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_circle_up,
                              color: Colors.white,
                              size:
                                  dialogWidth *
                                  AppConfig
                                      .machineInteriorDialogCloseButtonSizeFactor,
                            ),
                            onPressed: _openUpgrades,
                            tooltip: 'Upgrades',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withValues(
                                alpha: 0.7,
                              ),
                              padding: EdgeInsets.all(
                                padding *
                                    AppConfig
                                        .machineInteriorDialogCloseButtonPaddingFactor,
                              ),
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
                              size:
                                  dialogWidth *
                                  AppConfig
                                      .machineInteriorDialogCloseButtonSizeFactor,
                            ),
                            onPressed: _handleClose,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.5,
                              ),
                              padding: EdgeInsets.all(
                                padding *
                                    AppConfig
                                        .machineInteriorDialogCloseButtonPaddingFactor,
                              ),
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
                                  color: _hasCash
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    padding *
                                        AppConfig
                                            .machineInteriorDialogCashDisplayBorderRadiusFactor,
                                  ),
                                  border: Border.all(
                                    color: _hasCash
                                        ? Colors.green
                                        : Colors.grey,
                                    width:
                                        dialogWidth *
                                        AppConfig
                                            .machineInteriorDialogCashDisplayBorderWidthFactor,
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
                                        ),
                                        color: VexColors.muted,
                                      ),
                                    ),
                                    SizedBox(
                                      height:
                                          padding *
                                          AppConfig
                                              .machineInteriorDialogCashDisplaySpacingFactor,
                                    ),
                                    Text(
                                      '\$${_currentMachine.currentCash.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: ScreenUtils.relativeFontSize(
                                          context,
                                          AppConfig.fontSizeFactorLarge,
                                        ),
                                        fontWeight: FontWeight.bold,
                                        color: _hasCash
                                            ? Colors.green.shade700
                                            : VexColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height:
                                    padding *
                                    AppConfig
                                        .machineInteriorDialogContentSpacingFactor,
                              ),
                              if (_hasCash)
                                Text(
                                  'Tap on the bill validator or coin bin to collect cash',
                                  style: TextStyle(
                                    fontSize: ScreenUtils.relativeFontSize(
                                      context,
                                      AppConfig.fontSizeFactorSmall,
                                    ),
                                    color: VexColors.muted,
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
                                    ),
                                    color: VexColors.muted,
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
              ),
            );
          },
        ),
      ),
    );
  }
}
