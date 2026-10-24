import 'package:flutter/material.dart';

/// Light colours for the screens: a white background, dark text, and amber accents.
/// Gold is dark enough to read as text on white, and still works as a button fill.
class VexColors {
  VexColors._();

  static const Color ink = Color(0xFFFFFFFF);
  static const Color panel = Color(0xF2FFFFFF);
  static const Color panelSoft = Color(0xFFEDEBE5);
  static const Color card = Color(0xFFF7F6F2);
  static const Color gold = Color(0xFFB88A1A);
  static const Color goldDeep = Color(0xFF8A6212);
  static const Color cream = Color(0xFF1E1D22);
  static const Color muted = Color(0xFF5E5B66);
  static const Color green = Color(0xFF2E7D32);
  static const Color red = Color(0xFFC62828);
  static const Color border = Color(0x66B88A1A);
  static const Color line = Color(0x1F000000);
}

/// The app theme: white surfaces, dark text, and amber for emphasis.
class VexTheme {
  VexTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: VexColors.ink,
      canvasColor: VexColors.ink,
      colorScheme: const ColorScheme.light(
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
        overlayColor: Color(0x33B88A1A),
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
