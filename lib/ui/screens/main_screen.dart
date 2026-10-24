
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
import '../theme/vex_theme.dart';
import '../theme/vex_widgets.dart';

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
        backgroundColor: VexColors.panel,
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

/// Height of the top status bar.
double _calculateStatusBarHeight(BuildContext context) => 56;

/// Status bar showing cash, reputation and time, with save and exit on the right.
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

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        color: VexColors.ink,
        border: Border(bottom: BorderSide(color: VexColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                VexStat(
                  icon: Icons.paid,
                  value: '\$${cash.toStringAsFixed(2)}',
                  color: VexColors.green,
                ),
                VexStat(
                  icon: Icons.star,
                  value: reputation.toString(),
                  color: VexColors.gold,
                ),
                VexStat(icon: Icons.schedule, value: timeString),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _SaveExitButtons(size: 40),
        ],
      ),
    );
  }
}

/// Vexmarch-style bottom navigation with four tabs.
class _CustomBottomNavigationBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CustomBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tabs = [
      (Icons.business, 'HQ'),
      (Icons.location_city, 'City'),
      (Icons.local_shipping, 'Fleet'),
      (Icons.storefront, 'Market'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: VexColors.panel,
          border: Border(top: BorderSide(color: VexColors.border)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              VexNavTab(
                icon: tabs[i].$1,
                label: tabs[i].$2,
                selected: currentIndex == i,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaveExitButtons extends ConsumerWidget {
  final double size;

  const _SaveExitButtons({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIcon(
          icon: Icons.save,
          color: VexColors.gold,
          size: size,
          onTap: () => _saveGame(context, ref),
        ),
        const SizedBox(width: 6),
        _ActionIcon(
          icon: Icons.logout,
          color: VexColors.red,
          size: size,
          onTap: () => _exitToMenu(context, ref),
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
                  backgroundColor: success ? VexColors.green : VexColors.red,
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


/// A square icon button in a bordered panel, used for save and exit.
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VexColors.panelSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: color, size: size * 0.55),
        ),
      ),
    );
  }
}
