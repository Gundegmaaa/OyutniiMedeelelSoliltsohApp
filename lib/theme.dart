import 'package:flutter/material.dart';

abstract final class AppColors {
  static const purple = Color(0xFF7C3AED);
  static const lavender = Color(0xFFA78BFA);
  static const pink = Color(0xFFF472B6);
  static const orange = Color(0xFFFFAA63);
  static const mint = Color(0xFF6EDCC4);
  static const blue = purple;
  static const navy = Color(0xFF2D1C50);
  static const background = Color(0xFFF8F5FF);
  static const muted = Color(0xFF887D9D);
  static const paleBlue = Color(0xFFF0E8FF);
  static const border = Color(0xFFEDE6F8);
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9561F4), Color(0xFF7738E8), Color(0xFF5C2CC8)],
  );
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.purple,
    brightness: brightness,
    primary: dark ? const Color(0xFFC5A8FF) : AppColors.purple,
    surface: dark ? const Color(0xFF251D36) : Colors.white,
  );
  final outline = dark ? const Color(0xFF40334F) : AppColors.border;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF171020)
        : AppColors.background,
    dividerColor: outline,
    textTheme: Typography.material2021().black.apply(
      bodyColor: dark ? const Color(0xFFF5F0FC) : AppColors.navy,
      displayColor: dark ? const Color(0xFFF5F0FC) : AppColors.navy,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF171020) : AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF30253F) : const Color(0xFFF8F5FF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.all(16),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.purple,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      elevation: 6,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
