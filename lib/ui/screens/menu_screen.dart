import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_screen.dart';
import 'options_screen.dart';
import '../../state/save_load_service.dart';
import '../../state/providers.dart';
import '../../services/sound_service.dart';
import '../theme/vex_theme.dart';
import '../theme/vex_widgets.dart';

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
          backgroundColor: VexColors.red,
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
                      backgroundColor: VexColors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }

              // Load the game state into the controller
              ref
                  .read(gameControllerProvider.notifier)
                  .loadGameState(savedState);

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
                            backgroundColor: VexColors.green,
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
                    backgroundColor: VexColors.red,
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

  void _startNewGame(BuildContext context, WidgetRef ref) async {
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
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _MenuBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'VENDING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: VexDarkColors.gold,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                        ),
                      ),
                      const Text(
                        'TYCOON',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: VexDarkColors.cream,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 10,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Stock the machines. Win the city. Keep the change.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: VexDarkColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 36),
                      VexButton(
                        dark: true,
                        label: 'Start game',
                        icon: Icons.play_arrow,
                        primary: true,
                        expand: true,
                        onPressed: () => _startNewGame(context, ref),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<bool>(
                        future: SaveLoadService.hasSavedGame(),
                        builder: (context, snapshot) {
                          final hasSave = snapshot.data ?? false;
                          return VexButton(
                            dark: true,
                            label: 'Load game',
                            icon: Icons.folder_open,
                            expand: true,
                            onPressed: hasSave
                                ? () => _loadGame(context, ref)
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      VexButton(
                        dark: true,
                        label: 'Options',
                        icon: Icons.tune,
                        expand: true,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const OptionsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      VexButton(
                        dark: true,
                        label: 'Credits',
                        icon: Icons.info_outline,
                        expand: true,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Credits feature coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The menu background: an ink gradient with a faint gold grid, as in vexmarch's title.
class _MenuBackdrop extends StatelessWidget {
  const _MenuBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.4),
          radius: 1.2,
          colors: [Color(0xFF1E1620), VexDarkColors.ink],
        ),
      ),
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14F2D27A)
      ..strokeWidth = 1;
    const step = 36.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

/// Dialog for selecting save slot to load
class _LoadGameDialog extends StatelessWidget {
  final List<SaveSlot> slots;
  final void Function(int slotIndex) onLoad;

  const _LoadGameDialog({required this.slots, required this.onLoad});

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
                    ? Text(
                        'Day ${slot.gameState!.dayCount}, \$${slot.gameState!.cash.toStringAsFixed(2)}',
                      )
                    : const Text('No save data'),
                enabled: hasSave,
                onTap: hasSave
                    ? () {
                        // Close dialog first, then trigger load
                        Navigator.of(context).pop();
                        onLoad(index);
                      }
                    : null,
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
