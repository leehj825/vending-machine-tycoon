import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A small flat-shaded lowpoly renderer.
///
/// Scenes are built from axis-aligned boxes, prisms and pyramids. Every
/// triangle is lit once when it is built, then drawn as one vertex-coloured
/// batch per frame. Objects are sorted back to front by their centre, so
/// each object should be roughly convex and its parts listed back to front.
class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  Vec3 get normalized {
    final len = math.sqrt(dot(this));
    return len == 0 ? const Vec3(0, 1, 0) : this * (1 / len);
  }
}

/// One lit, flat-coloured triangle in world space.
class LowPolyTriangle {
  final Vec3 a;
  final Vec3 b;
  final Vec3 c;
  final Vec3 normal;
  final Color color;

  const LowPolyTriangle(this.a, this.b, this.c, this.normal, this.color);
}

/// A group of triangles that is drawn and picked as one unit.
class LowPolyObject {
  final List<LowPolyTriangle> triangles;

  /// Used to sort standing objects back to front.
  final Vec3 center;

  /// Flat ground pieces are drawn first, in list order, and never sorted.
  final bool onGround;

  /// What a tap on this object reports. Null objects cannot be tapped.
  final Object? payload;

  /// Undrawn objects only take taps. They make small things easier to hit.
  final bool drawn;

  const LowPolyObject({
    required this.triangles,
    required this.center,
    this.onGround = false,
    this.payload,
    this.drawn = true,
  });
}

/// Builds the triangles of one [LowPolyObject].
///
/// [brightness] scales every colour, and each face is lit by a fixed sun
/// direction, so the caller can dim a whole scene at night.
class LowPolyMeshBuilder {
  LowPolyMeshBuilder({this.brightness = 1.0});

  final double brightness;
  final List<LowPolyTriangle> _triangles = [];

  static final Vec3 _sun = const Vec3(-0.4, 0.8, 0.4).normalized;
  static const double _ambient = 0.6;

  /// Finishes the object. The centre is where it sorts from the camera.
  LowPolyObject build({
    required Vec3 center,
    bool onGround = false,
    Object? payload,
    bool drawn = true,
  }) {
    return LowPolyObject(
      triangles: List.unmodifiable(_triangles),
      center: center,
      onGround: onGround,
      payload: payload,
      drawn: drawn,
    );
  }

  /// Adds a triangle. [outward] is a direction hint that orients the normal.
  void _tri(Vec3 a, Vec3 b, Vec3 c, Vec3 outward, Color color) {
    var normal = (b - a).cross(c - a).normalized;
    if (normal.dot(outward) < 0) {
      normal = normal * -1;
    }
    final diffuse = math.max(0.0, normal.dot(_sun));
    final lit = _shade(color, (_ambient + (1 - _ambient) * diffuse) * brightness);
    _triangles.add(LowPolyTriangle(a, b, c, normal, lit));
  }

  void _quad(Vec3 a, Vec3 b, Vec3 c, Vec3 d, Vec3 outward, Color color) {
    _tri(a, b, c, outward, color);
    _tri(a, c, d, outward, color);
  }

  /// A quad with corners in order around its face. [outward] orients its normal.
  void quad(Vec3 a, Vec3 b, Vec3 c, Vec3 d, Vec3 outward, Color color) =>
      _quad(a, b, c, d, outward, color);

  /// A flat horizontal rectangle at height [y].
  void flat(double x0, double z0, double x1, double z1, double y, Color color) {
    _quad(
      Vec3(x0, y, z0),
      Vec3(x1, y, z0),
      Vec3(x1, y, z1),
      Vec3(x0, y, z1),
      const Vec3(0, 1, 0),
      color,
    );
  }

  /// An axis-aligned box. The top uses [top] when given, so roofs can differ.
  void box(
    double x0,
    double y0,
    double z0,
    double x1,
    double y1,
    double z1,
    Color color, {
    Color? top,
  }) {
    _quad(
      Vec3(x0, y1, z0),
      Vec3(x1, y1, z0),
      Vec3(x1, y1, z1),
      Vec3(x0, y1, z1),
      const Vec3(0, 1, 0),
      top ?? color,
    );
    _quad(
      Vec3(x0, y0, z1),
      Vec3(x1, y0, z1),
      Vec3(x1, y1, z1),
      Vec3(x0, y1, z1),
      const Vec3(0, 0, 1),
      color,
    );
    _quad(
      Vec3(x1, y0, z0),
      Vec3(x0, y0, z0),
      Vec3(x0, y1, z0),
      Vec3(x1, y1, z0),
      const Vec3(0, 0, -1),
      color,
    );
    _quad(
      Vec3(x1, y0, z1),
      Vec3(x1, y0, z0),
      Vec3(x1, y1, z0),
      Vec3(x1, y1, z1),
      const Vec3(1, 0, 0),
      color,
    );
    _quad(
      Vec3(x0, y0, z0),
      Vec3(x0, y0, z1),
      Vec3(x0, y1, z1),
      Vec3(x0, y1, z0),
      const Vec3(-1, 0, 0),
      color,
    );
  }

  /// Window panes on the four sides of a box spanning [y0] to [y1].
  ///
  /// Panes are flat quads just outside each face, which is much cheaper to
  /// draw than small boxes. When [frame] is given, each pane sits in a frame of
  /// that colour. Every pane on a lit side uses [lit] in a pattern, so buildings
  /// look lived in. Add this after the box it decorates.
  void windows(
    double x0,
    double z0,
    double x1,
    double z1,
    double y0,
    double y1, {
    required int cols,
    required int rows,
    required Color glass,
    Color? lit,
    Color? frame,
  }) {
    const edge = 0.1;
    const gap = 0.03;
    final rowH = (y1 - y0) / rows;
    for (var r = 0; r < rows; r++) {
      final wy0 = y0 + rowH * (r + 0.25);
      final wy1 = y0 + rowH * (r + 0.7);
      for (var c = 0; c < cols; c++) {
        final color = lit != null && (r + c) % 3 == 0 ? lit : glass;
        final t0 = edge + (1 - 2 * edge) * c / cols + gap;
        final t1 = edge + (1 - 2 * edge) * (c + 1) / cols - gap;
        if (frame != null) {
          // The frame is a little bigger than the pane and sits just behind it.
          _paneOnFaces(x0, z0, x1, z1, t0 - 0.02, t1 + 0.02, wy0 - 0.02, wy1 + 0.02, 0.008, frame);
        }
        _paneOnFaces(x0, z0, x1, z1, t0, t1, wy0, wy1, 0.014, color);
      }
    }
  }

  /// One pane on each of the four faces of a box: [t0] to [t1] along the face,
  /// from [wy0] to [wy1] up it, pushed [off] outside the face.
  void _paneOnFaces(
    double x0,
    double z0,
    double x1,
    double z1,
    double t0,
    double t1,
    double wy0,
    double wy1,
    double off,
    Color color,
  ) {
    final ax0 = x0 + (x1 - x0) * t0;
    final ax1 = x0 + (x1 - x0) * t1;
    final az0 = z0 + (z1 - z0) * t0;
    final az1 = z0 + (z1 - z0) * t1;
    _quad(
      Vec3(ax0, wy0, z1 + off),
      Vec3(ax1, wy0, z1 + off),
      Vec3(ax1, wy1, z1 + off),
      Vec3(ax0, wy1, z1 + off),
      const Vec3(0, 0, 1),
      color,
    );
    _quad(
      Vec3(ax1, wy0, z0 - off),
      Vec3(ax0, wy0, z0 - off),
      Vec3(ax0, wy1, z0 - off),
      Vec3(ax1, wy1, z0 - off),
      const Vec3(0, 0, -1),
      color,
    );
    _quad(
      Vec3(x1 + off, wy0, az1),
      Vec3(x1 + off, wy0, az0),
      Vec3(x1 + off, wy1, az0),
      Vec3(x1 + off, wy1, az1),
      const Vec3(1, 0, 0),
      color,
    );
    _quad(
      Vec3(x0 - off, wy0, az0),
      Vec3(x0 - off, wy0, az1),
      Vec3(x0 - off, wy1, az1),
      Vec3(x0 - off, wy1, az0),
      const Vec3(-1, 0, 0),
      color,
    );
  }

  /// A four-sided pyramid roof over a rectangle at height [y0].
  void roof(
    double x0,
    double z0,
    double x1,
    double z1,
    double y0,
    double yTop,
    Color color,
  ) {
    final apex = Vec3((x0 + x1) / 2, yTop, (z0 + z1) / 2);
    final a = Vec3(x0, y0, z0);
    final b = Vec3(x1, y0, z0);
    final c = Vec3(x1, y0, z1);
    final d = Vec3(x0, y0, z1);
    _tri(a, b, apex, const Vec3(0, 0.5, -1), color);
    _tri(b, c, apex, const Vec3(1, 0.5, 0), color);
    _tri(c, d, apex, const Vec3(0, 0.5, 1), color);
    _tri(d, a, apex, const Vec3(-1, 0.5, 0), color);
  }

  /// A round-ish prism with [sides] faces. Its top is capped when [top] is set.
  void prism(
    double cx,
    double cz,
    double radius,
    int sides,
    double y0,
    double y1,
    Color color, {
    Color? top,
  }) {
    final topCenter = Vec3(cx, y1, cz);
    for (var i = 0; i < sides; i++) {
      final a0 = i * 2 * math.pi / sides;
      final a1 = (i + 1) * 2 * math.pi / sides;
      final mid = (a0 + a1) / 2;
      final p0 = Vec3(cx + radius * math.cos(a0), y0, cz + radius * math.sin(a0));
      final p1 = Vec3(cx + radius * math.cos(a1), y0, cz + radius * math.sin(a1));
      final t0 = Vec3(p0.x, y1, p0.z);
      final t1 = Vec3(p1.x, y1, p1.z);
      final hint = Vec3(math.cos(mid), 0, math.sin(mid));
      _quad(p0, p1, t1, t0, hint, color);
      if (top != null) {
        _tri(topCenter, t0, t1, const Vec3(0, 1, 0), top);
      }
    }
  }

  /// A cone with [sides] faces, from a round base at [y0] to a point at [yTop].
  void cone(
    double cx,
    double cz,
    double radius,
    int sides,
    double y0,
    double yTop,
    Color color,
  ) {
    final apex = Vec3(cx, yTop, cz);
    for (var i = 0; i < sides; i++) {
      final a0 = i * 2 * math.pi / sides;
      final a1 = (i + 1) * 2 * math.pi / sides;
      final mid = (a0 + a1) / 2;
      final p0 = Vec3(cx + radius * math.cos(a0), y0, cz + radius * math.sin(a0));
      final p1 = Vec3(cx + radius * math.cos(a1), y0, cz + radius * math.sin(a1));
      _tri(p0, p1, apex, Vec3(math.cos(mid), 0.6, math.sin(mid)), color);
    }
  }
}

/// Orbit camera around [target]. Yaw turns around the vertical axis, pitch
/// lifts the eye above the horizon, and distance is the eye's range.
class LowPolyCamera {
  final Vec3 target;
  final double yaw;
  final double pitch;
  final double distance;

  const LowPolyCamera({
    required this.target,
    required this.yaw,
    required this.pitch,
    required this.distance,
  });

  static const double minPitch = 0.15;
  static const double maxPitch = 1.45;

  LowPolyCamera orbit(double dYaw, double dPitch) => LowPolyCamera(
        target: target,
        yaw: yaw + dYaw,
        pitch: (pitch + dPitch).clamp(minPitch, maxPitch).toDouble(),
        distance: distance,
      );

  LowPolyCamera withDistance(double value) => LowPolyCamera(
        target: target,
        yaw: yaw,
        pitch: pitch,
        distance: value,
      );

  Vec3 get eye {
    final cosPitch = math.cos(pitch);
    return target +
        Vec3(
              math.sin(yaw) * cosPitch,
              math.sin(pitch),
              math.cos(yaw) * cosPitch,
            ) *
            distance;
  }
}

/// Projects world points to screen pixels for one camera and viewport size.
class LowPolyProjector {
  LowPolyProjector._(
    this.eye,
    this._forward,
    this._right,
    this._up,
    this._focal,
    this._centerX,
    this._centerY,
  );

  factory LowPolyProjector(LowPolyCamera camera, Size size) {
    final eye = camera.eye;
    final forward = (camera.target - eye).normalized;
    final right = forward.cross(const Vec3(0, 1, 0)).normalized;
    final up = right.cross(forward).normalized;
    return LowPolyProjector._(
      eye,
      forward,
      right,
      up,
      size.shortestSide,
      size.width / 2,
      size.height / 2,
    );
  }

  static const double _nearPlane = 0.3;

  final Vec3 eye;
  final Vec3 _forward;
  final Vec3 _right;
  final Vec3 _up;
  final double _focal;
  final double _centerX;
  final double _centerY;

  /// Distance along the view direction. Larger values are farther away.
  double depthOf(Vec3 p) => (p - eye).dot(_forward);

  /// Screen position of [p], or null when it is behind the near plane.
  Offset? project(Vec3 p) {
    final d = p - eye;
    final z = d.dot(_forward);
    if (z < _nearPlane) return null;
    final scale = _focal / z;
    final x = _centerX + d.dot(_right) * scale;
    final y = _centerY - d.dot(_up) * scale;
    if (!x.isFinite || !y.isFinite) return null;
    return Offset(x, y);
  }
}

/// Copies [object] into the world: scaled, turned by [yaw] about the vertical axis, then
/// moved to [at]. Used to place a model built at its own size on the map.
LowPolyObject placeObject(
  LowPolyObject object, {
  required Vec3 at,
  required double scale,
  double yaw = 0,
  Object? payload,
  bool drawn = true,
}) {
  final c = math.cos(yaw);
  final s = math.sin(yaw);
  Vec3 move(Vec3 p) {
    final x = p.x * scale;
    final z = p.z * scale;
    return Vec3(at.x + x * c + z * s, at.y + p.y * scale, at.z - x * s + z * c);
  }

  Vec3 turn(Vec3 n) => Vec3(n.x * c + n.z * s, n.y, -n.x * s + n.z * c);

  return LowPolyObject(
    triangles: [
      for (final t in object.triangles)
        LowPolyTriangle(move(t.a), move(t.b), move(t.c), turn(t.normal), t.color),
    ],
    center: move(object.center),
    onGround: object.onGround,
    payload: payload,
    drawn: drawn,
  );
}

/// Sorts objects into draw order: ground first, then standing objects from
/// farthest to nearest.
List<LowPolyObject> lowPolyDrawOrder(
  List<LowPolyObject> objects,
  LowPolyProjector projector,
) {
  final ground = <LowPolyObject>[];
  final standing = <({LowPolyObject object, double depth})>[];
  for (final object in objects) {
    if (object.onGround) {
      ground.add(object);
    } else {
      standing.add((object: object, depth: projector.depthOf(object.center)));
    }
  }
  standing.sort((a, b) => b.depth.compareTo(a.depth));
  return [...ground, for (final entry in standing) entry.object];
}

/// True when a triangle faces the camera, so it can be drawn.
bool _facesEye(LowPolyTriangle tri, Vec3 eye) {
  final centroid = (tri.a + tri.b + tri.c) * (1 / 3);
  return tri.normal.dot(eye - centroid) > 0;
}

/// Returns the payload of the nearest pickable object under [at], or null.
Object? lowPolyPick({
  required List<LowPolyObject> objects,
  required LowPolyCamera camera,
  required Size size,
  required Offset at,
}) {
  final projector = LowPolyProjector(camera, size);
  final order = lowPolyDrawOrder(objects, projector);
  for (final object in order.reversed) {
    if (object.payload == null) continue;
    for (final tri in object.triangles) {
      if (!_facesEye(tri, projector.eye)) continue;
      final pa = projector.project(tri.a);
      final pb = projector.project(tri.b);
      final pc = projector.project(tri.c);
      if (pa == null || pb == null || pc == null) continue;
      if (_pointInTriangle(at, pa, pb, pc)) return object.payload;
    }
  }
  return null;
}

bool _pointInTriangle(Offset p, Offset a, Offset b, Offset c) {
  double side(Offset p1, Offset p2, Offset p3) =>
      (p1.dx - p3.dx) * (p2.dy - p3.dy) - (p2.dx - p3.dx) * (p1.dy - p3.dy);

  final d1 = side(p, a, b);
  final d2 = side(p, b, c);
  final d3 = side(p, c, a);
  final hasNegative = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPositive = d1 > 0 || d2 > 0 || d3 > 0;
  return !(hasNegative && hasPositive);
}

Color _shade(Color c, double k) => Color.from(
      alpha: c.a,
      red: (c.r * k).clamp(0.0, 1.0).toDouble(),
      green: (c.g * k).clamp(0.0, 1.0).toDouble(),
      blue: (c.b * k).clamp(0.0, 1.0).toDouble(),
    );

/// Draws objects onto [canvas]: the background first, then every drawn
/// object in draw order. Triangles are batched into a few vertex calls.
void _drawObjects(
  Canvas canvas,
  Size size,
  List<LowPolyObject> objects,
  LowPolyCamera camera,
  Color background,
) {
  canvas.drawRect(Offset.zero & size, Paint()..color = background);

  final projector = LowPolyProjector(camera, size);
  final eye = projector.eye;
  final positions = <Offset>[];
  final colors = <Color>[];

  void flush() {
    if (positions.isEmpty) return;
    final vertices = ui.Vertices(ui.VertexMode.triangles, positions, colors: colors);
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    positions.clear();
    colors.clear();
  }

  for (final object in lowPolyDrawOrder(objects, projector)) {
    if (!object.drawn) continue;
    for (final tri in object.triangles) {
      if (!_facesEye(tri, eye)) continue;
      final pa = projector.project(tri.a);
      final pb = projector.project(tri.b);
      final pc = projector.project(tri.c);
      if (pa == null || pb == null || pc == null) continue;
      positions
        ..add(pa)
        ..add(pb)
        ..add(pc);
      colors
        ..add(tri.color)
        ..add(tri.color)
        ..add(tri.color);
      if (positions.length >= LowPolyPainter.maxVerticesPerBatch) flush();
    }
  }
  flush();
}

/// Keeps the static part of a scene as one image, so each frame only redraws
/// the objects that move. The image is rebuilt when the objects, camera,
/// size, background or pixel ratio change.
class LowPolyStaticLayer {
  ui.Image? _image;
  bool _built = false;
  List<LowPolyObject>? _objects;
  LowPolyCamera? _camera;
  Size? _size;
  Color? _background;
  double? _pixelRatio;

  /// Returns the cached image, rebuilding it first when anything has changed.
  /// Returns null when the image cannot be built, and the caller then draws
  /// the scene directly.
  ui.Image? resolve({
    required List<LowPolyObject> objects,
    required LowPolyCamera camera,
    required Size size,
    required Color background,
    required double pixelRatio,
  }) {
    final valid = _built &&
        identical(_objects, objects) &&
        identical(_camera, camera) &&
        _size == size &&
        _background == background &&
        _pixelRatio == pixelRatio;
    if (valid) return _image;

    _image?.dispose();
    _image = null;
    _built = true;
    _objects = objects;
    _camera = camera;
    _size = size;
    _background = background;
    _pixelRatio = pixelRatio;
    if (size.isEmpty || pixelRatio <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    _drawObjects(canvas, size, objects, camera, background);
    final picture = recorder.endRecording();
    try {
      _image = picture.toImageSync(
        (size.width * pixelRatio).ceil(),
        (size.height * pixelRatio).ceil(),
      );
    } catch (error) {
      // Drawing the scene directly is slower, but the map still shows.
      debugPrint('Lowpoly city image could not be built: $error');
      _image = null;
    } finally {
      picture.dispose();
    }
    return _image;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _built = false;
    _objects = null;
  }
}

/// Paints lowpoly objects with [camera]. The background is painted first.
///
/// [objects] is the static scene and can be cached in [layer]. [overlay]
/// holds the moving objects, which are drawn on top of the scene each frame.
class LowPolyPainter extends CustomPainter {
  LowPolyPainter({
    required this.objects,
    required this.overlay,
    required this.camera,
    required this.background,
    required this.layer,
    required this.pixelRatio,
  });

  final List<LowPolyObject> objects;
  final List<LowPolyObject> overlay;
  final LowPolyCamera camera;
  final Color background;
  final LowPolyStaticLayer? layer;
  final double pixelRatio;

  /// Vertices per draw call. Kept well below GPU buffer limits.
  static const int maxVerticesPerBatch = 30000;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cached = layer?.resolve(
      objects: objects,
      camera: camera,
      size: size,
      background: background,
      pixelRatio: pixelRatio,
    );
    if (cached != null) {
      canvas.drawImageRect(
        cached,
        Rect.fromLTWH(0, 0, cached.width.toDouble(), cached.height.toDouble()),
        Offset.zero & size,
        Paint(),
      );
    } else {
      _drawObjects(canvas, size, objects, camera, background);
    }
    if (overlay.isNotEmpty) {
      _drawObjects(canvas, size, overlay, camera, Colors.transparent);
    }
  }

  @override
  bool shouldRepaint(LowPolyPainter oldDelegate) =>
      !identical(oldDelegate.objects, objects) ||
      !identical(oldDelegate.overlay, overlay) ||
      !identical(oldDelegate.camera, camera) ||
      oldDelegate.background != background ||
      oldDelegate.pixelRatio != pixelRatio;
}

/// Lets buttons on the screen zoom and reset a [LowPolyView].
class LowPolyController {
  void Function(double factor)? _zoom;
  VoidCallback? _reset;
  void Function(Vec3 target, double distance, double pitch)? _focus;

  /// Multiplies the camera distance: below 1 zooms in, above 1 zooms out.
  void zoomBy(double factor) => _zoom?.call(factor);

  /// Returns the camera to the view the widget was given.
  void reset() => _reset?.call();

  /// Glides the camera to look at [target] from [distance] at [pitch].
  void focusOn(Vec3 target, {double distance = 5, double pitch = 0.5}) =>
      _focus?.call(target, distance, pitch);
}

/// Interactive lowpoly view. One finger orbits, a pinch or the scroll wheel
/// zooms, and a short tap reports the payload under the finger.
///
/// [objects] is the static scene. [overlay] holds the moving objects, which
/// change often and are drawn on top of the scene.
class LowPolyView extends StatefulWidget {
  const LowPolyView({
    super.key,
    required this.objects,
    required this.camera,
    required this.background,
    this.overlay = const [],
    this.minDistance = 4,
    this.maxDistance = 60,
    this.onTapTarget,
    this.controller,
  });

  final LowPolyController? controller;

  final List<LowPolyObject> objects;
  final List<LowPolyObject> overlay;
  final LowPolyCamera camera;
  final Color background;
  final double minDistance;
  final double maxDistance;
  final ValueChanged<Object>? onTapTarget;

  @override
  State<LowPolyView> createState() => _LowPolyViewState();
}

class _LowPolyViewState extends State<LowPolyView> with SingleTickerProviderStateMixin {
  static const double _tapSlop = 10;
  static const Duration _tapDuration = Duration(milliseconds: 350);
  static const double _orbitSpeedYaw = 0.008;
  static const double _orbitSpeedPitch = 0.006;

  late LowPolyCamera _camera = widget.camera;
  AnimationController? _glide;
  final Map<int, Offset> _pointers = {};
  final LowPolyStaticLayer _layer = LowPolyStaticLayer();
  Offset? _downAt;
  DateTime? _downTime;
  bool _tapCandidate = false;
  double? _pinchSpan;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didUpdateWidget(covariant LowPolyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _detach(oldWidget.controller);
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    _detach(widget.controller);
    _glide?.dispose();
    _layer.dispose();
    super.dispose();
  }

  void _attach(LowPolyController? controller) {
    controller?._zoom = _zoomBy;
    controller?._reset = _resetView;
    controller?._focus = _focusOn;
  }

  void _detach(LowPolyController? controller) {
    if (controller == null) return;
    controller._zoom = null;
    controller._reset = null;
    controller._focus = null;
  }

  void _resetView() {
    // A dialog can open over the view while a finger is down, so its release is never
    // seen here. Forget any stale pointers, or later taps would count as a pinch.
    _pointers.clear();
    _tapCandidate = false;
    _pinchSpan = null;
    _glideTo(widget.camera);
  }

  void _focusOn(Vec3 target, double distance, double pitch) {
    _glideTo(LowPolyCamera(target: target, yaw: _camera.yaw, pitch: pitch, distance: distance));
  }

  /// Animates the camera from where it is to [goal] over about half a second.
  void _glideTo(LowPolyCamera goal) {
    _glide?.dispose();
    final from = _camera;
    final glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    glide.addListener(() {
      final t = Curves.easeInOut.transform(glide.value);
      double mix(double a, double b) => a + (b - a) * t;
      setState(() {
        _camera = LowPolyCamera(
          target: Vec3(
            mix(from.target.x, goal.target.x),
            mix(from.target.y, goal.target.y),
            mix(from.target.z, goal.target.z),
          ),
          yaw: mix(from.yaw, goal.yaw),
          pitch: mix(from.pitch, goal.pitch),
          distance: mix(from.distance, goal.distance),
        );
      });
    });
    _glide = glide;
    glide.forward();
  }

  double? _span() {
    if (_pointers.length < 2) return null;
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _zoomBy(double factor) {
    final distance = (_camera.distance * factor)
        .clamp(widget.minDistance, widget.maxDistance)
        .toDouble();
    setState(() => _camera = _camera.withDistance(distance));
  }

  void _onPointerDown(PointerDownEvent event) {
    // A finger on the view takes over from any glide in progress.
    _glide?.stop();
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 1) {
      _downAt = event.localPosition;
      _downTime = DateTime.now();
      _tapCandidate = true;
    } else {
      _tapCandidate = false;
    }
    _pinchSpan = _span();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final previous = _pointers[event.pointer];
    if (previous == null) return;
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length == 1) {
      final delta = event.localPosition - previous;
      final downAt = _downAt;
      if (downAt != null && (event.localPosition - downAt).distance > _tapSlop) {
        _tapCandidate = false;
      }
      setState(() {
        _camera = _camera.orbit(-delta.dx * _orbitSpeedYaw, delta.dy * _orbitSpeedPitch);
      });
      return;
    }

    _tapCandidate = false;
    final span = _span();
    final previousSpan = _pinchSpan;
    if (span != null && previousSpan != null && previousSpan > 0) {
      _zoomBy(previousSpan / span);
    }
    _pinchSpan = span;
  }

  void _onPointerUp(PointerUpEvent event) {
    final wasSingle = _pointers.length == 1;
    final downTime = _downTime;
    final isTap = wasSingle &&
        _tapCandidate &&
        downTime != null &&
        DateTime.now().difference(downTime) < _tapDuration;
    _pointers.remove(event.pointer);
    _pinchSpan = _span();
    if (isTap) {
      _tapCandidate = false;
      _pick(event.localPosition);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    _tapCandidate = false;
    _pinchSpan = _span();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _zoomBy(math.exp(event.scrollDelta.dy * 0.001));
    }
  }

  void _pick(Offset at) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    if (size == null) return;
    final target = lowPolyPick(
      objects: [...widget.overlay, ...widget.objects],
      camera: _camera,
      size: size,
      at: at,
    );
    if (target != null) widget.onTapTarget?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    // While a finger is moving the camera, the cached image would be stale every
    // frame, so draw the scene directly until the gesture ends.
    final interacting = _pointers.isNotEmpty;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      onPointerSignal: _onPointerSignal,
      child: CustomPaint(
        painter: LowPolyPainter(
          objects: widget.objects,
          overlay: widget.overlay,
          camera: _camera,
          background: widget.background,
          layer: interacting ? null : _layer,
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
