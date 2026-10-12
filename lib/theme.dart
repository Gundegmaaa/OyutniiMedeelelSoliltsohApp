import 'package:flutter/material.dart';

abstract final class AppColors {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF192655);
  static const background = Color(0xFFF7F9FB);
  static const muted = Color(0xFF74849B);
  static const paleBlue = Color(0xFFEFF6FF);
  static const border = Color(0xFFE2E8F0);
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: brightness,
    primary: AppColors.blue,
    surface: dark ? const Color(0xFF1C2536) : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF111827)
        : AppColors.background,
    dividerColor: dark ? const Color(0xFF344155) : AppColors.border,
    textTheme: Typography.material2021().black.apply(
      bodyColor: dark ? const Color(0xFFF1F5F9) : const Color(0xFF202B3C),
      displayColor: dark ? const Color(0xFFF1F5F9) : const Color(0xFF202B3C),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.all(16),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.blue,
      foregroundColor: Colors.white,
      shape: CircleBorder(),
      elevation: 0,
    ),
  );
}
