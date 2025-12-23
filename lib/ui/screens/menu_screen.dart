import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_screen.dart';
import '../../state/save_load_service.dart';
import '../../state/providers.dart';

/// Main menu screen shown at app startup
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  Future<void> _loadGame(BuildContext context, WidgetRef ref) async {
    final savedState = await SaveLoadService.loadGame();
    
    if (savedState == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No saved game found'),
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

    // Navigate to main game screen
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainScreen(),
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game loaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final isPortrait = screenHeight > screenWidth;
            
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight,
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.05,
                      vertical: screenHeight * 0.05,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Game Title Image - width relative to screen
                        SizedBox(
                          width: screenWidth * 0.85,
                          child: Image.asset(
                            'assets/images/title.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        
                        SizedBox(height: isPortrait ? screenHeight * 0.05 : screenHeight * 0.08),
                        
                        // Start Game Button - width relative to screen
                        SizedBox(
                          width: screenWidth * 0.7,
                          child: GestureDetector(
                            onTap: () {
                              // Start simulation before navigating
                              ref.read(gameControllerProvider.notifier).startSimulation();
                              // Navigate to main game screen
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const MainScreen(),
                                ),
                              );
                            },
                            child: Image.asset(
                              'assets/images/start_button.png',
                              fit: BoxFit.fitWidth,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: screenWidth * 0.7,
                                  height: 80,
                                  color: Colors.red,
                                  child: const Center(
                                    child: Text(
                                      'START GAME',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        SizedBox(height: isPortrait ? screenHeight * 0.08 : screenHeight * 0.12),
                        
                        // Bottom Buttons Row - width relative to screen
                        SizedBox(
                          width: screenWidth * 0.85,
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
                                              height: 60,
                                              color: Colors.yellow,
                                              child: const Center(
                                                child: Text(
                                                  'LOAD GAME',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
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
                              
                              SizedBox(width: screenWidth * 0.02),
                              
                              // Options Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    // TODO: Implement options screen
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Options feature coming soon!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Image.asset(
                                    'assets/images/options_button.png',
                                    fit: BoxFit.fitWidth,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 60,
                                        color: Colors.yellow,
                                        child: const Center(
                                          child: Text(
                                            'OPTIONS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              
                              SizedBox(width: screenWidth * 0.02),
                              
                              // Credits Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    // TODO: Implement credits screen
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
                                        height: 60,
                                        color: Colors.yellow,
                                        child: const Center(
                                          child: Text(
                                            'CREDITS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
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
