import 'package:flutter/material.dart';

/// Utility class for responsive sizing based on screen dimensions
class ScreenUtils {
  /// Get the smaller dimension (width or height) of the screen
  static double getSmallerDimension(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width < size.height ? size.width : size.height;
  }
  
  /// Get a relative size based on the smaller screen dimension
  /// [factor] is a multiplier (e.g., 0.1 means 10% of smaller dimension)
  static double relativeSize(BuildContext context, double factor) {
    return getSmallerDimension(context) * factor;
  }
  
  /// Get a relative size with min and max constraints
  static double relativeSizeClamped(
    BuildContext context,
    double factor, {
    double? min,
    double? max,
  }) {
    final size = relativeSize(context, factor);
    if (min != null && size < min) return min;
    if (max != null && size > max) return max;
    return size;
  }
  
  /// Get relative padding based on smaller dimension
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

