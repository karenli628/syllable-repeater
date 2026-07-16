// AI-Generate
import 'package:flutter/material.dart';

abstract final class AppTokens {
  static const Color primary = Color(0xFF3B6EF5);
  static const Color needsReview = Color(0xFFE8A13C);
  static const Color selectedHighlight = Color(0xFFF5D33B);
  static const Color difference = Color(0xFFD94F4F);
  static const Color success = Color(0xFF2E7D5B);

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double radius = 8;
  static const double minimumWindowWidth = 1100;
  static const double minimumWindowHeight = 700;
  static const Size minimumWindowSize = Size(1100, 700);

  static ThemeData lightTheme() => _theme(Brightness.light);

  static ThemeData darkTheme() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
