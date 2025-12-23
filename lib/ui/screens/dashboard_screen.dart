import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/selectors.dart';
import '../../state/providers.dart';
import '../widgets/machine_status_card.dart';
import '../utils/screen_utils.dart';

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
    final alertCount = ref.watch(alertCountProvider);
    final machines = ref.watch(machinesProvider);

    return Scaffold(
      // AppBar removed - managed by MainScreen
      body: CustomScrollView(
        slivers: [
          // Middle Section: Alerts
          if (alertCount > 0)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: ScreenUtils.relativePadding(context, 0.02),
                color: Colors.red,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: ScreenUtils.relativeSizeClamped(
                        context,
                        0.06, // Increased from 0.01
                        min: ScreenUtils.getSmallerDimension(context) * 0.05,
                        max: ScreenUtils.getSmallerDimension(context) * 0.08,
                      ),
                    ),
                    SizedBox(width: ScreenUtils.relativeSize(context, 0.015)),
                    Text(
                      'Warning: $alertCount Machine${alertCount > 1 ? 's' : ''} Empty!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          0.045, // Increased from 0.007 to match dashboard text
                          min: ScreenUtils.getSmallerDimension(context) * 0.035,
                          max: ScreenUtils.getSmallerDimension(context) * 0.065,
                        ),
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
                      size: ScreenUtils.relativeSizeClamped(
                        context,
                        0.08, // Increased from 0.06
                        min: ScreenUtils.getSmallerDimension(context) * 0.06,
                        max: ScreenUtils.getSmallerDimension(context) * 0.12,
                      ),
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: ScreenUtils.relativeSize(context, 0.025)),
                    Text(
                      'No machines yet',
                      style: TextStyle(
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          0.045, // Increased from 0.035
                          min: ScreenUtils.getSmallerDimension(context) * 0.035,
                          max: ScreenUtils.getSmallerDimension(context) * 0.065,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: ScreenUtils.relativeSize(context, 0.02)),
                    Text(
                      'Go to the Map to purchase machines',
                      style: TextStyle(
                        fontSize: ScreenUtils.relativeFontSize(
                          context,
                          0.032, // Increased from 0.025
                          min: ScreenUtils.getSmallerDimension(context) * 0.025,
                          max: ScreenUtils.getSmallerDimension(context) * 0.045,
                        ),
                        color: Colors.grey[600],
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

