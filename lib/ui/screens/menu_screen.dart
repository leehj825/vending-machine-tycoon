import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_screen.dart';
import 'options_screen.dart';
import '../../state/save_load_service.dart';
import '../../state/providers.dart';
import '../../services/sound_service.dart';
import '../utils/screen_utils.dart';

/// Main menu screen shown at app startup
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  @override
  void initState() {
    super.initState();
    // Play menu background music when screen is shown
    // Use a longer delay to ensure any previous music has stopped and screen is fully loaded
    // This is especially important when navigating from game screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        // Only start music if we're still on this screen (not already navigated away)
        if (mounted) {
          SoundService().playBackgroundMusic('sound/game_menu.m4a');
        }
      });
    });
  }

  @override
  void dispose() {
    // Stop menu music when leaving the screen
    // Use forceStop to ensure it stops even if just started
    SoundService().stopBackgroundMusic(forceStop: true);
    super.dispose();
  }

  Future<void> _loadGame(BuildContext context, WidgetRef ref) async {
    final slots = await SaveLoadService.getSaveSlots();
    
    if (!context.mounted) return;
    
    // Check if any slot has a save
    final hasAnySave = slots.any((slot) => slot.gameState != null);
    
    if (!hasAnySave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved games found'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Show load dialog
    showDialog(
      context: context,
      builder: (dialogContext) => _LoadGameDialog(
        slots: slots,
        onLoad: (slotIndex) {
          // Close dialog first
          Navigator.of(dialogContext).pop();
          
          // Schedule load and navigation after current frame
          SchedulerBinding.instance.addPostFrameCallback((_) async {
            try {
              final savedState = await SaveLoadService.loadGame(slotIndex);
              
              if (savedState == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to load game'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }

              // Load the game state into the controller
              ref.read(gameControllerProvider.notifier).loadGameState(savedState);
              
              // Start simulation after loading
              ref.read(gameControllerProvider.notifier).startSimulation();

              // Stop menu music before navigating
              await SoundService().stopBackgroundMusic();
              // Small delay to ensure music stops
              await Future.delayed(const Duration(milliseconds: 100));

              // Navigate to main game screen in next frame
              // Use pushAndRemoveUntil instead of pushReplacement to handle case when no routes exist
              if (context.mounted) {
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(),
                      ),
                      (route) => false, // Remove all previous routes
                    );
                    
                    // Show success message after navigation
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Game loaded successfully!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    });
                  }
                });
              }
            } catch (e) {
              print('Error loading game: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading game: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final smallerDim = ScreenUtils.getSmallerDimension(context);
            final screenHeight = constraints.maxHeight;
            
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight,
                ),
                child: Center(
                  child: Padding(
                    padding: ScreenUtils.relativePaddingSymmetric(
                      context,
                      horizontal: 0.043,
                      vertical: 0.021,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Game Title Image - width relative to smaller dimension
                        SizedBox(
                          width: smallerDim * 0.85,
                          child: Image.asset(
                            'assets/images/title.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        
                        SizedBox(
                          height: screenHeight * 0.1, // 10% of screen height
                        ),
                        
                        // Start Game Button - width relative to smaller dimension
                        SizedBox(
                          width: smallerDim * 0.7,
                          child: GestureDetector(
                            onTap: () async {
                              // Stop menu music before navigating
                              await SoundService().stopBackgroundMusic();
                              // Small delay to ensure music stops
                              await Future.delayed(const Duration(milliseconds: 100));
                              // Reset game to initial state
                              ref.read(gameControllerProvider.notifier).resetGame();
                              // Start simulation before navigating
                              ref.read(gameControllerProvider.notifier).startSimulation();
                              // Navigate to main game screen
                              if (context.mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const MainScreen(),
                                  ),
                                );
                              }
                            },
                            child: Image.asset(
                              'assets/images/start_button.png',
                              fit: BoxFit.fitWidth,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: smallerDim * 0.7,
                                  height: ScreenUtils.relativeSize(context, 0.034),
                                  color: Colors.red,
                                  child: Center(
                                    child: Text(
                                      'START GAME',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: ScreenUtils.relativeFontSize(
                                          context,
                                          0.01,
                                          min: smallerDim * 0.01,
                                          max: smallerDim * 0.015,
                                        ),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        SizedBox(
                          height: screenHeight * 0.1, // 10% of screen height
                        ),
                        
                        // Bottom Buttons Row - width relative to smaller dimension
                        SizedBox(
                          width: smallerDim * 0.85,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Load Game Button
                              Expanded(
                                child: FutureBuilder<bool>(
                                  future: SaveLoadService.hasSavedGame(),
                                  builder: (context, snapshot) {
                                    final hasSave = snapshot.data ?? false;
                                    return GestureDetector(
                                      onTap: hasSave ? () => _loadGame(context, ref) : null,
                                      child: Opacity(
                                        opacity: hasSave ? 1.0 : 0.5,
                                        child: Image.asset(
                                          'assets/images/load_game_button.png',
                                          fit: BoxFit.fitWidth,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              height: ScreenUtils.relativeSize(context, 0.026),
                                              color: Colors.yellow,
                                              child: Center(
                                                child: Text(
                                                  'LOAD GAME',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: ScreenUtils.relativeFontSize(
                                                      context,
                                                      0.007,
                                                      min: smallerDim * 0.007,
                                                      max: smallerDim * 0.01,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              SizedBox(
                                width: ScreenUtils.relativeSize(context, 0.0085),
                              ),
                              
                              // Options Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const OptionsScreen(),
                                      ),
                                    );
                                  },
                                  child: Image.asset(
                                    'assets/images/options_button.png',
                                    fit: BoxFit.fitWidth,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: ScreenUtils.relativeSize(context, 0.026),
                                        color: Colors.yellow,
                                        child: Center(
                                          child: Text(
                                            'OPTIONS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: ScreenUtils.relativeFontSize(
                                                context,
                                                0.007,
                                                min: smallerDim * 0.007,
                                                max: smallerDim * 0.01,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              
                              SizedBox(
                                width: ScreenUtils.relativeSize(context, 0.0085),
                              ),
                              
                              // Credits Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Credits feature coming soon!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Image.asset(
                                    'assets/images/credits_button.png',
                                    fit: BoxFit.fitWidth,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: ScreenUtils.relativeSize(context, 0.026),
                                        color: Colors.yellow,
                                        child: Center(
                                          child: Text(
                                            'CREDITS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: ScreenUtils.relativeFontSize(
                                                context,
                                                0.007,
                                                min: smallerDim * 0.007,
                                                max: smallerDim * 0.01,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Dialog for selecting save slot to load
class _LoadGameDialog extends StatelessWidget {
  final List<SaveSlot> slots;
  final void Function(int slotIndex) onLoad;

  const _LoadGameDialog({
    required this.slots,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Load Game'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(3, (index) {
              final slot = slots[index];
              final hasSave = slot.gameState != null;
              final displayName = slot.name.isEmpty ? 'Empty' : slot.name;
              
              return ListTile(
                title: Text('Slot ${index + 1}: $displayName'),
                subtitle: hasSave 
                    ? Text('Day ${slot.gameState!.dayCount}, \$${slot.gameState!.cash.toStringAsFixed(2)}')
                    : const Text('No save data'),
                enabled: hasSave,
                onTap: hasSave ? () {
                  // Close dialog first, then trigger load
                  Navigator.of(context).pop();
                  onLoad(index);
                } : null,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
