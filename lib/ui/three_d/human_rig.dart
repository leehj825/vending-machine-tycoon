import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'human_clips.dart';
import 'human_clips_dw.dart';
import 'lowpoly_engine.dart';

/// A baked walk or run cycle from vexmarch's crowd (human_clips.dart).
///
/// [quats] holds 13 bone rotations per frame, each as x, y, z, w, and
/// [hipY] and [hipZ] give the hips' height and depth for each frame.
class HumanClip {
  const HumanClip({
    required this.frames,
    required this.quats,
    required this.hipY,
    required this.hipZ,
    this.stride = _walkStride,
  });

  final int frames;
  final List<double> quats;
  final List<double> hipY;
  final List<double> hipZ;

  /// Distance covered by one cycle, in the city's tiles. A figure's feet keep pace with the
  /// ground when it moves this far per cycle.
  final double stride;
}

/// Animation state of one person, advanced each time they are drawn.
class HumanPose {
  /// Position in the walk cycle, in cycles.
  double phase = 0;

  /// Direction the person is facing, in radians around the vertical axis.
  double yaw = 0;
  double? lastX;
  double? lastY;
  DateTime? lastMovedAt;

  /// The player's movement read against [yaw]: forward (+1 straight ahead, -1 back) and side
  /// (+ or - for the two strafe directions). Null for people who simply walk where they face.
  double? dirF;
  double? dirS;
}

/// Distance covered by one step cycle. Running takes longer steps.
const double _walkStride = 0.2;
const double _runStride = 0.4;

/// Scale from vexmarch's figure size (about 1.9 units tall) to a tile.
const double _figureScale = 0.13;

/// How long a person keeps their walking pose after moving. The city redraws
/// slower than its 50 ms tick on a busy frame, so this must cover several
/// frames. Too short a hold makes walkers flicker between walk and stand.
const Duration _movingHold = Duration(milliseconds: 600);

/// vexmarch's rig: the parent bone of each of the 13 bones.
const List<int> _parent = [-1, 0, 1, 1, 1, 3, 4, 5, 6, 0, 0, 9, 10];

/// Each bone's offset from its parent in the rest pose.
const List<List<double>> _offset = [
  [0, 0.9, 0],
  [0, 0.05, 0],
  [0, 0.66, 0],
  [-0.34, 0.58, 0],
  [0.34, 0.58, 0],
  [0, -0.3, 0],
  [0, -0.3, 0],
  [0, -0.3, 0],
  [0, -0.3, 0],
  [-0.14, -0.04, 0],
  [0.14, -0.04, 0],
  [0, -0.45, 0],
  [0, -0.45, 0],
];

const int _hips = 0;
const int _head = 2;
const int _shoulderL = 3;
const int _shoulderR = 4;
const int _elbowL = 5;
const int _elbowR = 6;
const int _hipL = 9;
const int _hipR = 10;
const int _kneeL = 11;
const int _kneeR = 12;

final List<Vec3> _rest = _restPose();

List<Vec3> _restPose() {
  final rest = <Vec3>[];
  for (var i = 0; i < _parent.length; i++) {
    final parent = _parent[i] < 0 ? const Vec3(0, 0, 0) : rest[_parent[i]];
    final o = _offset[i];
    rest.add(Vec3(parent.x + o[0], parent.y + o[1], parent.z + o[2]));
  }
  return rest;
}

/// A rigid transform: a point p maps to r·p + t, with r row-major.
class _Affine {
  const _Affine(this.r, this.t);

  final List<double> r;
  final Vec3 t;
}

List<double> _mul3(List<double> a, List<double> b) {
  final o = List<double>.filled(9, 0);
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 3; j++) {
      var s = 0.0;
      for (var k = 0; k < 3; k++) {
        s += a[i * 3 + k] * b[k * 3 + j];
      }
      o[i * 3 + j] = s;
    }
  }
  return o;
}

Vec3 _apply(List<double> r, Vec3 v) => Vec3(
      r[0] * v.x + r[1] * v.y + r[2] * v.z,
      r[3] * v.x + r[4] * v.y + r[5] * v.z,
      r[6] * v.x + r[7] * v.y + r[8] * v.z,
    );

_Affine _compose(_Affine a, _Affine b) =>
    _Affine(_mul3(a.r, b.r), _apply(a.r, b.t) + a.t);

/// Rotation matrix of a unit quaternion, matching vexmarch's fromQuat.
List<double> _quatMatrix(double x, double y, double z, double w) {
  final n = math.sqrt(x * x + y * y + z * z + w * w);
  final qx = n == 0 ? 0.0 : x / n;
  final qy = n == 0 ? 0.0 : y / n;
  final qz = n == 0 ? 0.0 : z / n;
  final qw = n == 0 ? 1.0 : w / n;
  return [
    1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
    2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
    2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy),
  ];
}

/// The world transform of each bone for one pose. A null [clip] is the rest pose.
List<_Affine> _poseBones(HumanClip? clip, double phase) {
  final q = List<double>.filled(_parent.length * 4, 0);
  for (var b = 0; b < _parent.length; b++) {
    q[b * 4 + 3] = 1;
  }
  var hipY = _rest[_hips].y;
  var hipZ = _rest[_hips].z;
  if (clip != null) {
    final cycle = phase - phase.floorToDouble();
    final frame = math.min((cycle * clip.frames).floor(), clip.frames - 1);
    for (var i = 0; i < _parent.length * 4; i++) {
      q[i] = clip.quats[frame * _parent.length * 4 + i];
    }
    hipY = clip.hipY[frame];
    hipZ = clip.hipZ[frame];
  }

  final world = <_Affine>[];
  for (var b = 0; b < _parent.length; b++) {
    final o = _offset[b];
    final offset = b == 0 ? Vec3(0, hipY, hipZ) : Vec3(o[0], o[1], o[2]);
    final local = _Affine(
      _quatMatrix(q[b * 4], q[b * 4 + 1], q[b * 4 + 2], q[b * 4 + 3]),
      offset,
    );
    world.add(_parent[b] < 0 ? local : _compose(world[_parent[b]], local));
  }
  return world;
}

/// One box of a person, in the rest pose, hung on one bone.
class _Part {
  const _Part(this.bone, this.center, this.half, this.role);

  final int bone;
  final Vec3 center;
  final Vec3 half;
  /// Which colour the part takes: shirt, cap, or one of the fixed roles in [_roleColor].
  final String role;
}

/// Colour of each fixed part role. Shirt and cap come from the person.
Color _roleColor(String role, Color shirt, Color cap) => switch (role) {
      'shirt' => shirt,
      'cap' => cap,
      'skin' => _skin,
      'pants' => _pants,
      'boot' => _boot,
      'bag' => const Color(0xFF3E2723),
      _ => _sleeve,
    };

const Color _skin = Color(0xFFE2B88E);
const Color _pants = Color(0xFF4B4036);
const Color _boot = Color(0xFF2E241C);
const Color _sleeve = Color(0xFFFFFFFF);

/// The body every person shares, as vexmarch's civilian figure: legs, torso
/// in the shirt colour, arms, head and cap.
List<_Part> _personParts() {
  final parts = <_Part>[
    _Part(_hips, _rest[_hips], const Vec3(0.19, 0.1, 0.11), 'pants'),
    _Part(1, const Vec3(0, 1.3, 0), const Vec3(0.25, 0.3, 0.135), 'shirt'),
    _Part(_head, const Vec3(0, 1.78, 0), const Vec3(0.105, 0.115, 0.105), 'skin'),
    _Part(_head, const Vec3(0, 1.9, -0.01), const Vec3(0.12, 0.04, 0.12), 'cap'),
    // A backpack on the back of the torso.
    _Part(1, const Vec3(0, 1.3, -0.19), const Vec3(0.2, 0.24, 0.055), 'bag'),
  ];
  for (final side in [
    (_shoulderL, _elbowL, _hipL, _kneeL),
    (_shoulderR, _elbowR, _hipR, _kneeR),
  ]) {
    final (shoulder, elbow, hip, knee) = side;
    final sx = _rest[shoulder].x;
    final hx = _rest[hip].x;
    parts.addAll([
      _Part(shoulder, Vec3(sx, 1.39, 0), const Vec3(0.07, 0.155, 0.07), 'sleeve'),
      _Part(elbow, Vec3(sx, 1.05, 0), const Vec3(0.0575, 0.19, 0.0575), 'skin'),
      _Part(hip, Vec3(hx, 0.64, 0), const Vec3(0.09, 0.23, 0.1), 'pants'),
      _Part(knee, Vec3(hx, 0.2, 0), const Vec3(0.0775, 0.21, 0.085), 'pants'),
      _Part(knee, Vec3(hx, 0.04, 0.045), const Vec3(0.085, 0.05, 0.14), 'boot'),
    ]);
  }
  return parts;
}

/// Turns a person toward where they are moving and advances their walk cycle. Returns
/// whether they are moving now. A person who has not moved recently stands still.
bool advanceHumanPose(HumanPose pose, double x, double z, bool running, DateTime now) {
  final lastX = pose.lastX;
  final lastZ = pose.lastY;
  if (lastX != null && lastZ != null) {
    final dx = x - lastX;
    final dz = z - lastZ;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist > 0.0005) {
      pose.yaw = math.atan2(dx, dz);
      pose.phase += dist / (running ? _runStride : _walkStride);
      pose.lastMovedAt = now;
    }
  }
  pose.lastX = x;
  pose.lastY = z;
  return pose.lastMovedAt != null && now.difference(pose.lastMovedAt!) < _movingHold;
}

HumanClip? _clipFor(HumanPose pose, bool moving, bool running) {
  if (!moving) return null;
  final forward = pose.dirF;
  final side = pose.dirS;
  if (forward == null || side == null) return running ? humanRunClip : humanWalkClip;
  // Same thresholds and sides as Deepward's locomotion, so a strafe looks as it does there.
  if (forward > 0.5) return running ? dwRunClip : dwWalkClip;
  if (forward < -0.5) return running ? dwRunBackClip : dwWalkBackClip;
  if (side > 0) return running ? dwStrafeRunNClip : dwStrafeWalkNClip;
  return running ? dwStrafeRunPClip : dwStrafeWalkPClip;
}

/// Moves the player's figure. It faces [facing] whatever way it steps, and each step is read
/// against that facing, so walking backward or sideways plays the matching clip.
bool advancePlayerPose(HumanPose pose, double x, double z, double facing, bool running, DateTime now) {
  pose.yaw = facing;
  final lastX = pose.lastX;
  final lastZ = pose.lastY;
  if (lastX != null && lastZ != null) {
    final dx = x - lastX;
    final dz = z - lastZ;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist > 0.0005) {
      // Deepward's convention: forward is (sin, cos) of the facing, side is (cos, -sin).
      final ux = dx / dist;
      final uz = dz / dist;
      final fx = math.sin(facing);
      final fz = math.cos(facing);
      pose.dirF = ux * fx + uz * fz;
      pose.dirS = ux * fz - uz * fx;
      // The cycle length comes from the clip being played, so the feet keep pace with the ground.
      pose.phase += dist / _clipFor(pose, true, running)!.stride;
      pose.lastMovedAt = now;
    }
  }
  pose.lastX = x;
  pose.lastY = z;
  return pose.lastMovedAt != null && now.difference(pose.lastMovedAt!) < _movingHold;
}

/// The 13 bone transforms of a person for the pose, as 12 numbers each: the row-major
/// rotation followed by the translation. Bones are in the figure's own space.
List<double> humanBoneValues(HumanPose pose, bool running, bool moving) {
  final out = <double>[];
  for (final bone in _poseBones(_clipFor(pose, moving, running), pose.phase)) {
    out.addAll(bone.r);
    out.addAll([bone.t.x, bone.t.y, bone.t.z]);
  }
  return out;
}

/// The figure's shape, once: the rest position of each bone, and every box with the
/// bone it hangs on and its role. The city draws people from this and [humanBoneValues].
Map<String, Object?> humanRigTable() => {
      'rest': [for (final r in _rest) [r.x, r.y, r.z]],
      'parts': [
        for (final part in _personParts())
          {
            'bone': part.bone,
            'c': [part.center.x, part.center.y, part.center.z],
            'h': [part.half.x, part.half.y, part.half.z],
            'role': part.role,
          },
      ],
    };

/// Builds one person, posed by the walk or run clip, and facing the way
/// they are moving. A person who has not moved recently stands still.
///
/// [x] and [z] are the world position of the feet. [running] picks the run
/// cycle over the walk cycle while moving.
LowPolyObject buildHumanObject({
  required double x,
  required double z,
  required HumanPose pose,
  required bool running,
  required Color shirt,
  required Color cap,
  required double brightness,
  Object? payload,
  double scale = _figureScale,
}) {
  final moving = advanceHumanPose(pose, x, z, running, DateTime.now());
  final world = _poseBones(_clipFor(pose, moving, running), pose.phase);

  final cosYaw = math.cos(pose.yaw);
  final sinYaw = math.sin(pose.yaw);
  // Figure space to world: scale, turn to face the direction, then move to (x, z).
  Vec3 toWorld(Vec3 p) {
    final sx = p.x * scale;
    final sz = p.z * scale;
    return Vec3(
      x + sx * cosYaw + sz * sinYaw,
      p.y * scale,
      z - sx * sinYaw + sz * cosYaw,
    );
  }

  final m = LowPolyMeshBuilder(brightness: brightness);
  for (final part in _personParts()) {
    final bone = world[part.bone];
    final rest = _rest[part.bone];
    final corners = List<Vec3>.filled(8, const Vec3(0, 0, 0));
    for (var i = 0; i < 8; i++) {
      final sx = i & 1 == 0 ? -1.0 : 1.0;
      final sy = i & 2 == 0 ? -1.0 : 1.0;
      final sz = i & 4 == 0 ? -1.0 : 1.0;
      final local = Vec3(
        part.center.x + sx * part.half.x - rest.x,
        part.center.y + sy * part.half.y - rest.y,
        part.center.z + sz * part.half.z - rest.z,
      );
      corners[i] = toWorld(_apply(bone.r, local) + bone.t);
    }
    final centre = toWorld(_apply(bone.r, part.center - rest) + bone.t);
    // Faces are listed in order around the box, from corner index i.
    const faces = [
      [1, 5, 7, 3],
      [0, 2, 6, 4],
      [2, 6, 7, 3],
      [0, 1, 5, 4],
      [4, 5, 7, 6],
      [0, 1, 3, 2],
    ];
    for (final f in faces) {
      final a = corners[f[0]];
      final b = corners[f[1]];
      final c = corners[f[2]];
      final d = corners[f[3]];
      final face = Vec3(
        (a.x + b.x + c.x + d.x) / 4,
        (a.y + b.y + c.y + d.y) / 4,
        (a.z + b.z + c.z + d.z) / 4,
      );
      m.quad(a, b, c, d, face - centre, _roleColor(part.role, shirt, cap));
    }
  }
  return m.build(center: Vec3(x, 0.2, z), payload: payload);
}
