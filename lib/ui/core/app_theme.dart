import 'package:flutter/material.dart';

/// Editorial Studio Notebook design system (inspired by Babbel & Busuu):
/// warm archival paper, Fraunces serif display for vocabulary, Plus Jakarta Sans
/// for crisp controls, terracotta primary CTA, and forest olive status cues.
class AppTheme {
  static const String fontSans = 'PlusJakartaSans';
  static const String fontSerif = 'Fraunces';

  // Warm Archival Paper & Terracotta Palette
  static const Color bgWarmPaper = Color(0xFFF6F0E4);
  static const Color surfaceSheet = Color(0xFFFFFDF9);
  static const Color surfaceStrip = Color(0xFFEFE7D8);
  static const Color borderRule = Color(0xFFDCD0BC);
  static const Color borderCard = Color(0xFFDFD4C2);

  static const Color inkPrimary = Color(0xFF241C15);
  static const Color inkBody = Color(0xFF544639);
  static const Color inkMuted = Color(0xFF6E5D4E);

  static const Color accentTerracotta = Color(0xFFB34E2E);
  static const Color pauseBadgeBg = Color(0xFFF9EBE4);
  static const Color accentSage = Color(0xFF3A664C);

  // Optical lens focus card inside the notebook sheet
  static const Color lensFocusBg = Color(0xFF1B1612);
  static const Color lensAmberWord = Color(0xFFF3B664);
  static const Color lensSubtleText = Color(0xFFBFB0A0);
  static const Color lensRightNote = Color(0xFF9C8D7E);

  // Dark Warm Espresso fallback for dark system theme
  static const Color darkBgEspresso = Color(0xFF191410);
  static const Color darkSurface = Color(0xFF241D18);
  static const Color darkBorder = Color(0xFF3A2F27);

  static ThemeData warmLight() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontSans,
      scaffoldBackgroundColor: bgWarmPaper,
      colorScheme: const ColorScheme.light(
        primary: accentTerracotta,
        onPrimary: surfaceSheet,
        secondary: accentSage,
        onSecondary: surfaceSheet,
        surface: surfaceSheet,
        onSurface: inkPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgWarmPaper,
        foregroundColor: inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: borderRule,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSheet,
        labelStyle: const TextStyle(color: inkMuted, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: borderCard),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: accentTerracotta, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData warmDark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontSans,
      scaffoldBackgroundColor: darkBgEspresso,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD97250),
        onPrimary: surfaceSheet,
        secondary: Color(0xFF6BA884),
        surface: darkSurface,
        onSurface: Color(0xFFF6F0E4),
      ),
    );
  }
}
