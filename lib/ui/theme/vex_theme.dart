import 'package:flutter/material.dart';

/// Colours from vexmarch: an ink background, warm cream text, and gold accents.
class VexColors {
  VexColors._();

  static const Color ink = Color(0xFF07060A);
  static const Color panel = Color(0xF20C0A0E);
  static const Color panelSoft = Color(0xFF1C1620);
  static const Color card = Color(0xFF14101A);
  static const Color gold = Color(0xFFF2D27A);
  static const Color goldDeep = Color(0xFFC9963A);
  static const Color cream = Color(0xFFEEE6D6);
  static const Color muted = Color(0xDDEEE6D6);
  static const Color green = Color(0xFF9AD060);
  static const Color red = Color(0xFFE0483A);
  static const Color border = Color(0x66F2D27A);
  static const Color line = Color(0x26FFE6BE);
}

/// The app theme: dark ink surfaces, cream text, and gold for emphasis.
class VexTheme {
  VexTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: VexColors.ink,
      canvasColor: VexColors.ink,
      colorScheme: const ColorScheme.dark(
        primary: VexColors.gold,
        onPrimary: Color(0xFF1A1008),
        secondary: VexColors.goldDeep,
        onSecondary: Color(0xFF1A1008),
        surface: VexColors.panel,
        onSurface: VexColors.cream,
        error: VexColors.red,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: VexColors.cream,
        displayColor: VexColors.cream,
      ),
      dividerColor: VexColors.line,
      appBarTheme: const AppBarTheme(
        backgroundColor: VexColors.ink,
        foregroundColor: VexColors.gold,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VexColors.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: VexColors.border),
        ),
      ),
      cardTheme: CardThemeData(
        color: VexColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: VexColors.line),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: VexColors.gold,
        inactiveTrackColor: VexColors.line,
        thumbColor: VexColors.gold,
        overlayColor: Color(0x33F2D27A),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? VexColors.gold : VexColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? const Color(0x80F2D27A) : VexColors.line,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: VexColors.gold),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: VexColors.panel,
        contentTextStyle: TextStyle(color: VexColors.cream),
      ),
    );
  }
}
