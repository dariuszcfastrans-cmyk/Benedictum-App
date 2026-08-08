import 'package:flutter/material.dart';

/// Motyw ciemny aplikacji Benedictum.
/// Kolorystyka DCI: fiolet jako primary, turkus jako secondary.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF6C5DD3);
  static const Color secondary = Color(0xFF00D4AA);
  static const Color background = Color(0xFF0F0F1E);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color error = Color(0xFFFF4D4D);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: surface,
          error: error,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      );
}
