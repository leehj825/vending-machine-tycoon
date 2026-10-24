import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../simulation/models/machine.dart' as sim;
import 'human_rig.dart';
import 'lowpoly_engine.dart';
import 'vending_machine_3d.dart';

/// A vending machine in 3D with a customer who walks up, buys and walks away.
///
/// The timings match the old sprite version: a customer appears after a random
/// wait of 5 to 30 seconds, walks up in 3 seconds, buys on arrival, pauses for
/// 1 second, then walks away in 2 seconds and the cycle repeats. [onPurchase]
/// is called on arrival with whether the customer is special.
class VendingMachineStage extends StatefulWidget {
  const VendingMachineStage({
    super.key,
    required this.machine,
    required this.height,
    this.onPurchase,
    this.showCustomers = true,
  });

  final sim.Machine machine;
  final double height;
  final ValueChanged<bool>? onPurchase;
  final bool showCustomers;

  @override
  State<VendingMachineStage> createState() => _VendingMachineStageState();
}

enum _CustomerPhase { waiting, walkIn, buying, pausing, walkAway }

class _VendingMachineStageState extends State<VendingMachineStage>
    with SingleTickerProviderStateMixin {
  static const Duration _walkInDuration = Duration(seconds: 3);
  static const Duration _buyDuration = Duration(seconds: 1);
  static const Duration _pauseDuration = Duration(seconds: 1);
  static const Duration _walkAwayDuration = Duration(seconds: 2);

  /// Where the customer enters, where they stand to buy, and where they leave.
  static const double _enterX = 2.6;
  static const double _stopX = 1.0;
  static const double _exitX = -2.6;

  /// In front of the machine's glass.
  static const double _walkZ = 0.9;

  static const List<Color> _shirts = [
    Color(0xFF3949AB),
    Color(0xFFD81B60),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF00897B),
  ];
  static const List<Color> _caps = [
    Color(0xFFB79A52),
    Color(0xFF5D4037),
    Color(0xFF455A64),
    Color(0xFF8E24AA),
  ];

  final math.Random _random = math.Random();
  final HumanPose _pose = HumanPose();
  late final Ticker _ticker = createTicker(_onTick);

  _CustomerPhase _phase = _CustomerPhase.waiting;
  Duration _phaseStart = Duration.zero;
  Duration _lastTick = Duration.zero;
  Duration _waitFor = Duration.zero;
  bool _special = false;
  Color _shirt = _shirts.first;
  Color _cap = _caps.first;

  @override
  void initState() {
    super.initState();
    if (widget.showCustomers) {
      _startWaiting(Duration.zero);
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant VendingMachineStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showCustomers && !_ticker.isActive) {
      _startWaiting(Duration.zero);
      _ticker.start();
    } else if (!widget.showCustomers && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _startWaiting(Duration now) {
    _phase = _CustomerPhase.waiting;
    _phaseStart = now;
    _waitFor = Duration(milliseconds: 5000 + _random.nextInt(25000));
  }

  void _enter(_CustomerPhase phase, Duration now) {
    _phase = phase;
    _phaseStart = now;
    if (phase == _CustomerPhase.walkIn) {
      // A new customer: new clothes, and a fresh walk with no stale position.
      _special = _random.nextDouble() < 0.2;
      _shirt = _special ? const Color(0xFFFFD54F) : _shirts[_random.nextInt(_shirts.length)];
      _cap = _caps[_random.nextInt(_caps.length)];
      _pose
        ..lastX = null
        ..lastY = null
        ..lastMovedAt = null;
    }
    if (phase == _CustomerPhase.buying) {
      widget.onPurchase?.call(_special);
    }
  }

  void _onTick(Duration elapsed) {
    _lastTick = elapsed;
    final inPhase = elapsed - _phaseStart;
    if (_phase == _CustomerPhase.waiting && inPhase >= _waitFor) {
      _enter(_CustomerPhase.walkIn, elapsed);
    } else if (_phase == _CustomerPhase.walkIn && inPhase >= _walkInDuration) {
      _enter(_CustomerPhase.buying, elapsed);
    } else if (_phase == _CustomerPhase.buying && inPhase >= _buyDuration) {
      _enter(_CustomerPhase.pausing, elapsed);
    } else if (_phase == _CustomerPhase.pausing && inPhase >= _pauseDuration) {
      _enter(_CustomerPhase.walkAway, elapsed);
    } else if (_phase == _CustomerPhase.walkAway && inPhase >= _walkAwayDuration) {
      _startWaiting(elapsed);
    }
    if (mounted) setState(() {});
  }

  /// The customer's x position, or null while they are not in the shop.
  double? _customerX() {
    final inPhase = _lastTick - _phaseStart;
    switch (_phase) {
      case _CustomerPhase.waiting:
        return null;
      case _CustomerPhase.walkIn:
        final t = (inPhase.inMicroseconds / _walkInDuration.inMicroseconds).clamp(0.0, 1.0);
        return _enterX + (_stopX - _enterX) * t;
      case _CustomerPhase.buying:
      case _CustomerPhase.pausing:
        return _stopX;
      case _CustomerPhase.walkAway:
        final t = (inPhase.inMicroseconds / _walkAwayDuration.inMicroseconds).clamp(0.0, 1.0);
        return _stopX + (_exitX - _stopX) * t;
    }
  }

  @override
  Widget build(BuildContext context) {
    final objects = buildVendingMachineScene(widget.machine);
    final overlay = <LowPolyObject>[];
    final x = widget.showCustomers ? _customerX() : null;
    if (x != null) {
      overlay.add(buildHumanObject(
        x: x,
        z: _walkZ,
        pose: _pose,
        running: false,
        shirt: _shirt,
        cap: _cap,
        brightness: 1,
        scale: 1.0,
      ));
    }
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LowPolyView(
          objects: [..._floor(), ...objects],
          overlay: overlay,
          camera: stageCamera,
          background: const Color(0xFF14101A),
          minDistance: 2.4,
          maxDistance: 8,
        ),
      ),
    );
  }

  List<LowPolyObject> _floor() {
    final m = LowPolyMeshBuilder()
      ..flat(-4, -0.6, 4, 1.4, -0.001, const Color(0xFF2A2230));
    return [m.build(center: const Vec3(0, 0, 0), onGround: true)];
  }
}

/// Camera that frames the machine on the left and the customer's walk.
const LowPolyCamera stageCamera = LowPolyCamera(
  target: Vec3(0.2, 1.0, 0.2),
  yaw: 0.35,
  pitch: 0.2,
  distance: 5.4,
);
