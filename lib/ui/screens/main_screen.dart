import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'route_planner_screen.dart';
import 'warehouse_screen.dart';
import 'tile_city_screen.dart';
import '../../state/providers.dart';
import '../../state/save_load_service.dart';
import '../../state/selectors.dart';
import '../../config.dart';
import '../../services/sound_service.dart';
import 'menu_screen.dart';
import '../utils/screen_utils.dart';
import '../widgets/admob_banner.dart';

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

  @override
  void initState() {
    super.initState();
    // Play game background music when screen is shown
    // Use a delay to ensure menu music has stopped, screen is fully loaded, and ads have initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        // Only start music if we're still on this screen (not already navigated away)
        if (mounted) {
          SoundService().playBackgroundMusic('sound/game_background.m4a');
        }
      });
    });
  }

  @override
  void dispose() {
    // Stop background music when leaving the screen
    // Use forceStop to bypass protection mechanism when navigating away
    SoundService().stopBackgroundMusic(forceStop: true);
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // No need to call playBackgroundMusic here - it's already playing
    // The IndexedStack keeps the MainScreen alive, so music persists naturally
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0, // AppBar elevation is typically 0
        toolbarHeight: 0,
      ),
      body: Column(
        children: [
          // AdMob banner at the very top
          const AdMobBanner(),
          // Status bar below the banner
          PreferredSize(
            preferredSize: Size.fromHeight(_calculateStatusBarHeight(context)),
            child: _StatusBar(),
          ),
          // Game content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

/// Calculate the required height for the status bar
double _calculateStatusBarHeight(BuildContext context) {
  // Calculate card dimensions (same logic as in _StatusBar)
  final cardHeight = ScreenUtils.barHeight(
    context,
    AppConfig.statusCardHeightFactor,
    AppConfig.statusBarMaxHeightFraction,
  );
  
  // Container padding
  final containerPadding = ScreenUtils.relativeSize(context, AppConfig.statusBarContainerPaddingFactor);
  
  // Total height needed: card height + vertical padding on both sides
  return cardHeight + (containerPadding * 2);
}

/// Status bar showing cash, reputation, and time - always visible
class _StatusBar extends ConsumerWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = ref.watch(cashProvider);
    final reputation = ref.watch(reputationProvider);
    final dayCount = ref.watch(dayCountProvider);
    final hourOfDay = ref.watch(hourOfDayProvider);
    
    // Format hour as 12-hour format with AM/PM (hour only, no minutes)
    final hour12 = hourOfDay == 0 ? 12 : (hourOfDay > 12 ? hourOfDay - 12 : hourOfDay);
    final amPm = hourOfDay < 12 ? 'AM' : 'PM';
    final timeString = 'Day $dayCount, $hour12$amPm';
    
    // Card height drives the size; width follows the frame artwork's aspect
    final cardHeight = ScreenUtils.barHeight(
      context,
      AppConfig.statusCardHeightFactor,
      AppConfig.statusBarMaxHeightFraction,
    );
    final cardWidth = cardHeight * AppConfig.statusCardAspectRatio;
    
    // Padding is a fraction of the card itself, so it stays in proportion
    // with it on every screen
    // Font size for value - use status card specific size
    final valueFontSize = ScreenUtils.relativeFontSize(context, AppConfig.statusCardTextSizeFactor);
    
    final padding = cardWidth * AppConfig.statusCardPaddingFactor;
    
    final containerPadding = ScreenUtils.relativeSize(context, AppConfig.statusBarContainerPaddingFactor);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: containerPadding,
        vertical: containerPadding,
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Save/Exit sit in the space the status cards leave free on the right
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _SaveExitButtons(
                size: cardHeight * AppConfig.saveExitButtonSizeRatio,
              ),
            ),
          ),
          Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: containerPadding * 4,
        children: [
          _StatusCard(
            iconAsset: 'assets/images/cash_icon.png',
            value: '\$${cash.toStringAsFixed(2)}',
            valueColor: Colors.green,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            valueFontSize: valueFontSize,
            padding: padding,
          ),
          _StatusCard(
            iconAsset: 'assets/images/star_icon.png',
            value: reputation.toString(),
            valueColor: Colors.amber,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            valueFontSize: valueFontSize,
            padding: padding,
          ),
          _StatusCard(
            iconAsset: 'assets/images/clock_icon.png',
            value: timeString,
            valueColor: Colors.blue,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            valueFontSize: valueFontSize,
            padding: padding,
          ),
            ],
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
  final double valueFontSize;
  final double padding;

  const _StatusCard({
    required this.iconAsset,
    required this.value,
    required this.valueColor,
    required this.cardWidth,
    required this.cardHeight,
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
          // Content overlay - icon above, value below.
          // Laid out in a Column rather than absolutely positioned so the icon
          // and the value can never overlap, whatever the card size works out
          // to on a given screen.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: cardHeight * 0.08,
              ),
              child: Column(
                children: [
                  // The icon takes whatever height is left after the value
                  Expanded(
                    child: Image.asset(
                      iconAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  SizedBox(height: cardHeight * 0.04),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
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
    // The four tab buttons share the full width of the row, so size them from
    // the width each one actually gets and let the bar be as tall as those
    // buttons need. Driving the bar from a height factor alone left the buttons
    // far smaller than the space available to them.
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabSlotWidth =
            (constraints.maxWidth - AppConfig.tabButtonCount * _tabGap(context)) /
                AppConfig.tabButtonCount;
        // Tab artwork is wider than it is tall, so width decides the height
        final tabHeightForWidth = tabSlotWidth / AppConfig.tabButtonAspectRatio;
        final maxBarHeight = ScreenUtils.barHeight(
          context,
          AppConfig.bottomNavBarHeightFactor,
          AppConfig.bottomNavBarMaxHeightFraction,
        );
        final tabHeight = math.min(
          tabHeightForWidth,
          maxBarHeight * AppConfig.tabButtonHeightRatio,
        );
        final barHeight = tabHeight / AppConfig.tabButtonHeightRatio;

        return Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: ScreenUtils.relativeSize(context, 0.0017),
                offset: Offset(0, -ScreenUtils.relativeSize(context, 0.00085)),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabItem(
                  context,
                  tabHeight: tabHeight,
                  index: 0,
                  pressAsset: 'assets/images/hq_tab_press.png',
                  unpressAsset: 'assets/images/hq_tab_unpress.png',
                ),
                _buildTabItem(
                  context,
                  tabHeight: tabHeight,
                  index: 1,
                  pressAsset: 'assets/images/city_tab_press.png',
                  unpressAsset: 'assets/images/city_tab_unpress.png',
                ),
                _buildTabItem(
                  context,
                  tabHeight: tabHeight,
                  index: 2,
                  pressAsset: 'assets/images/fleet_tab_press.png',
                  unpressAsset: 'assets/images/fleet_tab_unpress.png',
                ),
                _buildTabItem(
                  context,
                  tabHeight: tabHeight,
                  index: 3,
                  pressAsset: 'assets/images/market_tab_press.png',
                  unpressAsset: 'assets/images/market_tab_unpress.png',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _tabGap(BuildContext context) =>
      ScreenUtils.relativeSize(context, AppConfig.paddingSmallFactor);

  Widget _buildTabItem(
    BuildContext context, {
    required double tabHeight,
    required int index,
    required String pressAsset,
    required String unpressAsset,
  }) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: tabHeight,
        width: tabHeight * AppConfig.tabButtonAspectRatio,
        child: Center(
          child: Image.asset(
            isSelected ? pressAsset : unpressAsset,
            fit: BoxFit.contain, // Prevents distortion - image grows as big as possible without distorting
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icon if image fails to load
              return Icon(
                _getIconForIndex(index),
                color: isSelected ? Colors.green : Colors.grey,
                size: ScreenUtils.relativeSize(
                  context,
                  AppConfig.tabButtonIconSizeFactor,
                ),
              );
            },
          ),
        ),
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

/// Save and Exit buttons.
///
/// These live in the status bar rather than the bottom navigation row: they are
/// utility actions, not navigation, and taking them out of that row gives the
/// four tab buttons the whole width to grow into.
class _SaveExitButtons extends ConsumerWidget {
  final double size;

  const _SaveExitButtons({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
        final buttonHeight = size;
        final sideBySideButtonWidth = size;
        
        return Row(
          mainAxisSize: MainAxisSize.min, // Keep compact on the right side
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Save Button
            GestureDetector(
              onTap: () => _saveGame(context, ref),
              child: Container(
                width: sideBySideButtonWidth,
                height: buttonHeight,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/save_button.png',
                  fit: BoxFit.contain, // Keeps button shape correct
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: sideBySideButtonWidth,
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
            SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.paddingSmallFactor)), // Spacing between buttons
            // Exit Button
            GestureDetector(
              onTap: () {
                _exitToMenu(context, ref);
              },
              child: Container(
                width: sideBySideButtonWidth,
                height: buttonHeight,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/exit_button.png',
                  fit: BoxFit.contain, // Keeps button shape correct
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: sideBySideButtonWidth,
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
        );
  }

  Future<void> _saveGame(BuildContext context, WidgetRef ref) async {
    final gameState = ref.read(gameControllerProvider);
    final slots = await SaveLoadService.getSaveSlots();
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => _SaveGameDialog(
        slots: slots,
        onSave: (slotIndex, name) async {
          final success = await SaveLoadService.saveGame(slotIndex, gameState, name);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success 
                    ? 'Game saved successfully!' 
                    : 'Failed to save game'),
                  backgroundColor: success ? Colors.green : Colors.red,
                  duration: AppConfig.snackbarDurationShort,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _exitToMenu(BuildContext context, WidgetRef ref) {
    // Capture the main screen context before showing dialog
    final mainScreenContext = context;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit to Menu'),
        content: const Text('Are you sure you want to exit to the main menu? Your progress will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close dialog first
              Navigator.of(dialogContext).pop();
              
              // Stop simulation before exiting
              ref.read(gameControllerProvider.notifier).stopSimulation();
              
              // Stop game background music before navigating (force stop to bypass protection)
              await SoundService().stopBackgroundMusic(forceStop: true);
              
              // Small delay to ensure music stops before starting menu music
              await Future.delayed(const Duration(milliseconds: 200));
              
              // Navigate back to menu screen using the main screen context
              if (mainScreenContext.mounted) {
                Navigator.of(mainScreenContext).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MenuScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

}

/// Dialog for selecting save slot and entering name
class _SaveGameDialog extends StatefulWidget {
  final List<SaveSlot> slots;
  final void Function(int slotIndex, String name) onSave;

  const _SaveGameDialog({
    required this.slots,
    required this.onSave,
  });

  @override
  State<_SaveGameDialog> createState() => _SaveGameDialogState();
}

class _SaveGameDialogState extends State<_SaveGameDialog> {
  int? _selectedSlot;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-select first slot if available
    if (widget.slots.isNotEmpty) {
      _selectedSlot = 0;
      _nameController.text = widget.slots[0].name.isEmpty ? '' : widget.slots[0].name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Game'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Slot selection
            ...List.generate(3, (index) {
              final slot = widget.slots[index];
              final hasSave = slot.gameState != null;
              final displayName = slot.name.isEmpty ? 'Empty' : slot.name;
              
              return RadioListTile<int>(
                title: Text('Slot ${index + 1}: $displayName'),
                subtitle: hasSave ? Text('Day ${slot.gameState!.dayCount}, \$${slot.gameState!.cash.toStringAsFixed(2)}') : null,
                value: index,
                groupValue: _selectedSlot,
                onChanged: (value) {
                  setState(() {
                    _selectedSlot = value;
                    _nameController.text = slot.name.isEmpty ? '' : slot.name;
                  });
                },
              );
            }),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.paddingMediumFactor)),
            // Name input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Save Name (max 10 characters)',
                border: OutlineInputBorder(),
              ),
              maxLength: 10,
              onChanged: (value) {
                setState(() {}); // Update to enable/disable save button
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedSlot != null && _nameController.text.trim().isNotEmpty
              ? () {
                  widget.onSave(_selectedSlot!, _nameController.text.trim());
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

