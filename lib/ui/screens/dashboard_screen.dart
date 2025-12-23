import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/selectors.dart';
import '../../state/providers.dart';
import '../widgets/machine_status_card.dart';

/// Main dashboard screen displaying simulation state and machine status
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-start simulation when screen loads (if not already running)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(gameControllerProvider.notifier);
      if (!controller.isSimulationRunning) {
        controller.startSimulation();
      }
    });
  }




  @override
  Widget build(BuildContext context) {
    final cash = ref.watch(cashProvider);
    final reputation = ref.watch(reputationProvider);
    final dayCount = ref.watch(dayCountProvider);
    final alertCount = ref.watch(alertCountProvider);
    final machines = ref.watch(machinesProvider);
    
    // Format time as "Day X"
    final timeString = 'Day $dayCount';

    return Scaffold(
      // AppBar removed - managed by MainScreen
      body: CustomScrollView(
        slivers: [
          // Top Section: Status Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Cash Card
                    _StatusCard(
                      iconAsset: 'assets/images/cash_icon.png',
                      label: 'Cash',
                      value: '\$${cash.toStringAsFixed(2)}',
                      valueColor: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    // Reputation Card
                    _StatusCard(
                      iconAsset: 'assets/images/star_icon.png',
                      label: 'Reputation',
                      value: reputation.toString(),
                      valueColor: Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    // Time Card
                    _StatusCard(
                      iconAsset: 'assets/images/clock_icon.png',
                      label: 'Time',
                      value: timeString,
                      valueColor: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Middle Section: Alerts
          if (alertCount > 0)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.red,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Warning: $alertCount Machine${alertCount > 1 ? 's' : ''} Empty!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom Section: Machine List
          if (machines.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No machines yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Go to the Map to purchase machines',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return MachineStatusCard(
                    machine: machines[index],
                  );
                },
                childCount: machines.length,
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable status card widget for the top status bar
class _StatusCard extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String value;
  final Color valueColor;

  const _StatusCard({
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate responsive sizes based on screen width
    // Base card width scales with screen, but clamped between 120 and 180
    final cardWidth = (screenWidth * 0.35).clamp(120.0, 180.0);
    // Card height scales proportionally
    final cardHeight = (cardWidth * 0.714).clamp(85.0, 128.0);
    
    // Icon size scales with card width, clamped between 24 and 40
    final iconSize = (cardWidth * 0.23).clamp(24.0, 40.0);
    
    // Font sizes scale with card width
    final labelFontSize = (cardWidth * 0.086).clamp(10.0, 14.0);
    final valueFontSize = (cardWidth * 0.129).clamp(14.0, 24.0);
    
    // Padding scales with card size
    final padding = (cardWidth * 0.086).clamp(10.0, 14.0);
    
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Stack(
        children: [
          // Background icon - show the whole thing without squashing
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
          // Content overlay
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
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
                      SizedBox(width: padding * 0.67),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: labelFontSize,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: padding * 0.67),
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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

