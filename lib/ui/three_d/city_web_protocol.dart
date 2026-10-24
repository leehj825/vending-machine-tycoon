import 'dart:ui' show Color;

import 'city_scene_3d.dart';
import 'human_rig.dart';
import 'people_look.dart';
import 'lowpoly_engine.dart';

/// The JSON the city page draws. Geometry comes from the same Dart builders as before,
/// so the city looks the same; the page draws it with a depth buffer, so things that
/// stand behind other things are hidden by them.

/// Rounds to 4 decimals, which is finer than a pixel and keeps the messages small.
double _round(double v) => (v * 10000).roundToDouble() / 10000;

/// A colour as the page reads it: `#rrggbb`.
String hexColour(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// What a tap on this object should report, or null when it is not tappable.
Map<String, Object?>? _pickFor(Object? payload) {
  if (payload is CityCell) return {'kind': 'cell', 'x': payload.x, 'y': payload.y};
  if (identical(payload, marketingTapTarget)) return {'kind': 'marketing'};
  return null;
}

/// Triangles of one object, flat: nine corner numbers and nine colour numbers per triangle.
Map<String, Object?> lowPolyObjectJson(LowPolyObject object) {
  final positions = <double>[];
  final colours = <double>[];
  for (final tri in object.triangles) {
    for (final v in [tri.a, tri.b, tri.c]) {
      positions
        ..add(_round(v.x))
        ..add(_round(v.y))
        ..add(_round(v.z));
      colours
        ..add(_round(tri.color.r))
        ..add(_round(tri.color.g))
        ..add(_round(tri.color.b));
    }
  }
  return {'p': positions, 'c': colours, 'pick': _pickFor(object.payload)};
}

/// The whole static scene: every drawn object, the figure's shape, the sky and the
/// camera the city starts from. Sent when the city or its machines change; the page only
/// moves the camera back to [home] when [resetCamera] is set.
Map<String, Object?> cityScenePayload({
  required List<LowPolyObject> objects,
  required Color sky,
  required LowPolyCamera home,
  required double minDistance,
  required double maxDistance,
  required bool resetCamera,
}) {
  return {
    'resetCamera': resetCamera,
    'sky': hexColour(sky),
    'minDistance': minDistance,
    'maxDistance': maxDistance,
    'home': {
      'target': [home.target.x, home.target.y, home.target.z],
      'yaw': home.yaw,
      'pitch': home.pitch,
      'distance': home.distance,
    },
    'rig': humanRigTable(),
    'objects': [
      for (final object in objects)
        if (object.drawn) lowPolyObjectJson(object),
    ],
  };
}

/// One person for a frame: where they stand, how they face, and their 13 bone transforms.
Map<String, Object?> walkerJson({
  required String key,
  required double x,
  required double z,
  required double yaw,
  required double scale,
  required PersonLook look,
  required double brightness,
  required List<double> bones,
}) {
  return {
    'key': key,
    'x': _round(x),
    'z': _round(z),
    'yaw': _round(yaw),
    'scale': scale,
    'shirt': hexColour(look.shirt),
    'pants': hexColour(look.pants),
    'skin': hexColour(look.skin),
    'hair': hexColour(look.hair),
    'hat': look.hat == null ? null : hexColour(look.hat!),
    'bag': look.bag == null ? null : hexColour(look.bag!),
    'brightness': brightness,
    'bones': [for (final v in bones) _round(v)],
  };
}

/// One frame of moving things: the people, and the triangles of vehicles and markers.
Map<String, Object?> cityFrameJson({
  required List<Map<String, Object?>> walkers,
  required List<LowPolyObject> soups,
}) {
  return {
    'walkers': walkers,
    'soups': [
      for (final object in soups)
        if (object.drawn) lowPolyObjectJson(object),
    ],
  };
}
