import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'route_planner_screen.dart';
import 'warehouse_screen.dart';
import 'tile_city_screen.dart';
import '../../state/providers.dart';
import '../../state/save_load_service.dart';
import '../../state/selectors.dart';
import 'menu_screen.dart';

/// Main navigation screen with bottom navigation bar
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  /// List of screens for the IndexedStack
  final List<Widget> _screens = const [
    DashboardScreen(),
    TileCityScreen(),
    RoutePlannerScreen(),
    WarehouseScreen(),
  ];

  /// App bar titles for each tab
  final List<String> _appBarTitles = const [
    'Vending Machine Tycoon',
    'City View',
    'Fleet Manager',
    'Wholesale Market',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: _StatusBar(),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

/// Status bar showing cash, reputation, and time - always visible
class _StatusBar extends ConsumerWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = ref.watch(cashProvider);
    final reputation = ref.watch(reputationProvider);
    final dayCount = ref.watch(dayCountProvider);
    final timeString = 'Day $dayCount';
    
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Size similar to tab buttons: (screenWidth * 0.25).clamp(90.0, 180.0)
    // Each status card gets similar width calculation, but with max size limit
    // Make width 1.2x larger
    final cardWidth = ((screenWidth * 0.25) * 1.2).clamp(108.0, 144.0);
    final cardHeight = (cardWidth * 0.714).clamp(77.0, 103.0);
    
    // Icon size scales with card width - 2x larger, clamped
    final iconSize = (cardWidth * 0.36).clamp(32.0, 43.0);
    
    // Font size for value - scales with card width
    final valueFontSize = (cardWidth * 0.1).clamp(9.0, 12.0);
    
    // Padding scales with card size
    final padding = (cardWidth * 0.071).clamp(6.0, 8.0);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatusCard(
            iconAsset: 'assets/images/cash_icon.png',
            value: '\$${cash.toStringAsFixed(2)}',
            valueColor: Colors.green,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            iconSize: iconSize,
            valueFontSize: valueFontSize,
            padding: padding,
          ),
          _StatusCard(
            iconAsset: 'assets/images/star_icon.png',
            value: reputation.toString(),
            valueColor: Colors.amber,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            iconSize: iconSize,
            valueFontSize: valueFontSize,
            padding: padding,
          ),
          _StatusCard(
            iconAsset: 'assets/images/clock_icon.png',
            value: timeString,
            valueColor: Colors.blue,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            iconSize: iconSize,
            valueFontSize: valueFontSize,
            padding: padding,
          ),
        ],
      ),
    );
  }
}

/// Compact status card for main screen status bar
class _StatusCard extends StatelessWidget {
  final String iconAsset;
  final String value;
  final Color valueColor;
  final double cardWidth;
  final double cardHeight;
  final double iconSize;
  final double valueFontSize;
  final double padding;

  const _StatusCard({
    required this.iconAsset,
    required this.value,
    required this.valueColor,
    required this.cardWidth,
    required this.cardHeight,
    required this.iconSize,
    required this.valueFontSize,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Stack(
        children: [
          // Background icon
          Image.asset(
            'assets/images/status_icon.png',
            width: cardWidth,
            height: cardHeight,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
          // Content overlay - icons at center top, values at center bottom
          Positioned.fill(
            child: Stack(
              children: [
                // Icon positioned at center upper part
                Positioned(
                  left: (cardWidth - iconSize) / 2,
                  top: padding,
                  child: Image.asset(
                    iconAsset,
                    width: iconSize,
                    height: iconSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return SizedBox(
                        width: iconSize,
                        height: iconSize,
                      );
                    },
                  ),
                ),
                // Value positioned at center bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: padding,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.bold,
                          color: valueColor,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom bottom navigation bar using image assets
class _CustomBottomNavigationBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CustomBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: kBottomNavigationBarHeight * 1.5,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTabItem(
                index: 0,
                pressAsset: 'assets/images/hq_tab_press.png',
                unpressAsset: 'assets/images/hq_tab_unpress.png',
              ),
            ),
            Expanded(
              child: _buildTabItem(
                index: 1,
                pressAsset: 'assets/images/city_tab_press.png',
                unpressAsset: 'assets/images/city_tab_unpress.png',
              ),
            ),
            Expanded(
              child: _buildTabItem(
                index: 2,
                pressAsset: 'assets/images/fleet_tab_press.png',
                unpressAsset: 'assets/images/fleet_tab_unpress.png',
              ),
            ),
            Expanded(
              child: _buildTabItem(
                index: 3,
                pressAsset: 'assets/images/market_tab_press.png',
                unpressAsset: 'assets/images/market_tab_unpress.png',
              ),
            ),
            // Save and Exit buttons on the right - no margin
            _buildActionButtons(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String pressAsset,
    required String unpressAsset,
  }) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Limit tab width to a maximum of 180 pixels (50% larger) or 25% of screen width, whichever is smaller
            // Minimum width increased to 90 pixels (50% larger)
            final maxWidth = (constraints.maxWidth * 0.25).clamp(90.0, 180.0);
            return Center(
              child: SizedBox(
                width: maxWidth,
                child: Image.asset(
                  isSelected ? pressAsset : unpressAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image fails to load
                    return Icon(
                      _getIconForIndex(index),
                      color: isSelected ? Colors.green : Colors.grey,
                      size: 36, // Increased from 24 to 36 (50% larger)
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate button width: half of tab button width
        // Tab buttons: (constraints.maxWidth * 0.25).clamp(90.0, 180.0)
        final buttonWidth = ((constraints.maxWidth * 0.25) * 0.5).clamp(45.0, 90.0);
        
        // Calculate button height: half of tab button height
        // Tab buttons are in a container with vertical padding of 8, so available height is constraints.maxHeight - 16
        // Tab button height would be approximately the available height
        // Action button height should be half of that
        final tabButtonHeight = constraints.maxHeight - 16; // Account for tab button's vertical padding
        final buttonHeight = (tabButtonHeight * 0.5).clamp(20.0, 60.0);
        
        return Container(
          // Anchor the container by aligning buttons
          // The Column will be centered vertically, with save button bottom and exit button top as anchors
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Save Button - bottom anchor point
              GestureDetector(
                onTap: () => _saveGame(context, ref),
                child: SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: Image.asset(
                    'assets/images/save_button.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: buttonWidth,
                        height: buttonHeight,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.save,
                          color: Colors.white,
                          size: buttonHeight * 0.5,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Exit Button - top anchor point
              GestureDetector(
                onTap: () => _exitToMenu(context, ref),
                child: SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: Image.asset(
                    'assets/images/exit_button.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: buttonWidth,
                        height: buttonHeight,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.exit_to_app,
                          color: Colors.white,
                          size: buttonHeight * 0.5,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveGame(BuildContext context, WidgetRef ref) async {
    final gameState = ref.read(gameControllerProvider);
    final success = await SaveLoadService.saveGame(gameState);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? 'Game saved successfully!' 
            : 'Failed to save game'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _exitToMenu(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit to Menu'),
        content: const Text('Are you sure you want to exit to the main menu? Your progress will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Stop simulation before exiting
              ref.read(gameControllerProvider.notifier).stopSimulation();
              // Navigate back to menu screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MenuScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard_rounded;
      case 1:
        return Icons.map_rounded;
      case 2:
        return Icons.local_shipping_rounded;
      case 3:
        return Icons.store_rounded;
      default:
        return Icons.circle;
    }
  }
}

