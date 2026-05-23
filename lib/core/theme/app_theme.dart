import 'package:flutter/material.dart';

/// Application-wide theme definitions.
///
/// This file is intentionally minimal during the bootstrap phase – it only
/// exposes a light and a dark [ThemeData] so the [MaterialApp] entry point
/// can wire them up without bringing in any feature-specific styling.
class AppTheme {
  AppTheme._();

  static const Color _seedColor = Color(0xFF3F51B5);

  /// Light theme used by default.
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      );

  /// Dark theme – chosen automatically when the device is in dark mode.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      );
}
