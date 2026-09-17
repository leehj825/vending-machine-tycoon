import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Utility class for responsive sizing based on screen dimensions.
///
/// Sizes are expressed as a factor of a *reference* screen (a 400x800dp phone)
/// scaled by a bounded [uiScale]. Sizing used to be `factor * min(width,
/// height)` with no upper bound, which made every icon, button and font grow
/// without limit: a 768dp tablet drew everything ~1.9x the size a phone did,
/// and a short wide window scaled the whole UI off its height. Clamping the
/// scale keeps the UI at the proportions it was designed with on any screen
/// ratio or orientation, while still adapting to genuinely small or large
/// devices.
class ScreenUtils {
  /// Short side of the screen the UI proportions were designed against.
  static const double referenceShortSide = 400.0;

  /// Bounds for [uiScale]. Small phones never shrink below [minScale] so touch
  /// targets stay usable; tablets and desktops never grow past [maxScale].
  static const double minScale = 0.85;
  static const double maxScale = 1.35;

  /// Get the smaller dimension (width or height) of the screen
  static double getSmallerDimension(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return math.min(size.width, size.height);
  }

  /// Bounded UI scale factor. 1.0 on the reference screen.
  ///
  /// Driven by the short side only, which is the same number in portrait and
  /// landscape, so a device gets the same size controls either way.
  ///
  /// This deliberately ignores the long side. Folding in a long-side ratio to
  /// protect short windows pinned the scale to 1.0 on any screen with a
  /// tablet-ish aspect (e.g. 621x800dp got phone-sized buttons despite being
  /// half again as wide as a phone). Bars that genuinely need to be bounded by
  /// the available height use [barHeight] instead.
  static double uiScale(BuildContext context) {
    final shortSide = getSmallerDimension(context);
    if (shortSide <= 0) return 1.0;
    return (shortSide / referenceShortSide).clamp(minScale, maxScale);
  }

  /// Height for a top or bottom bar: scales with the UI, but never takes more
  /// than [maxFraction] of the screen height, so landscape phones and short
  /// windows keep their usable area without shrinking the whole UI.
  static double barHeight(
    BuildContext context,
    double factor,
    double maxFraction,
  ) {
    final scaled = relativeSize(context, factor);
    final cap = MediaQuery.sizeOf(context).height * maxFraction;
    return math.min(scaled, cap);
  }

  /// Get a relative size based on the reference screen and [uiScale]
  /// [factor] is a multiplier (e.g., 0.1 means 10% of the reference short side)
  static double relativeSize(BuildContext context, double factor) {
    return factor * referenceShortSide * uiScale(context);
  }

  /// Get a relative size with min and max constraints.
  ///
  /// [min] and [max] are logical pixels on the reference screen; they are
  /// scaled by [uiScale] alongside the size itself so a bound can never
  /// reintroduce the unbounded growth this class exists to prevent.
  static double relativeSizeClamped(
    BuildContext context,
    double factor, {
    double? min,
    double? max,
  }) {
    final scale = uiScale(context);
    final size = factor * referenceShortSide * scale;
    if (min != null && size < min * scale) return min * scale;
    if (max != null && size > max * scale) return max * scale;
    return size;
  }

  /// Get relative padding based on the reference screen
  static EdgeInsets relativePadding(
    BuildContext context,
    double factor,
  ) {
    final padding = relativeSize(context, factor);
    return EdgeInsets.all(padding);
  }

  /// Get relative symmetric padding
  static EdgeInsets relativePaddingSymmetric(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    final hPadding = horizontal > 0 ? relativeSize(context, horizontal) : 0.0;
    final vPadding = vertical > 0 ? relativeSize(context, vertical) : 0.0;
    return EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding);
  }

  /// Get relative font size
  static double relativeFontSize(
    BuildContext context,
    double factor, {
    double? min,
    double? max,
  }) {
    return relativeSizeClamped(context, factor, min: min, max: max);
  }
}
