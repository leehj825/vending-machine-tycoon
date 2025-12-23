import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'route_planner_screen.dart';
import 'warehouse_screen.dart';
import 'tile_city_screen.dart';

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

/// Custom bottom navigation bar using image assets
class _CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CustomBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabItem(
              index: 0,
              pressAsset: 'assets/images/hq_tab_press.png',
              unpressAsset: 'assets/images/hq_tab_unpress.png',
            ),
            _buildTabItem(
              index: 1,
              pressAsset: 'assets/images/city_tab_press.png',
              unpressAsset: 'assets/images/city_tab_unpress.png',
            ),
            _buildTabItem(
              index: 2,
              pressAsset: 'assets/images/fleet_tab_press.png',
              unpressAsset: 'assets/images/fleet_tab_unpress.png',
            ),
            _buildTabItem(
              index: 3,
              pressAsset: 'assets/images/market_tab_press.png',
              unpressAsset: 'assets/images/market_tab_unpress.png',
            ),
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
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Image.asset(
            isSelected ? pressAsset : unpressAsset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icon if image fails to load
              return Icon(
                _getIconForIndex(index),
                color: isSelected ? Colors.green : Colors.grey,
                size: 24,
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

