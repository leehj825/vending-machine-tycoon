import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import 'hq_dashboard.dart';

/// Main dashboard screen - CEO Dashboard (HQ Tab)
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
    return const HQDashboard();
  }
}

