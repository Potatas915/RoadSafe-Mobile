import 'package:flutter/material.dart';

/// Shared with the web command center's Tailwind color tokens.
class RoadSafeColors {
  static const background = Color(0xFF0B0F19);
  static const card = Color(0xFF131C2E);
  static const border = Color(0xFF1E293B);
  static const orange = Color(0xFFF97316);
  static const muted = Color(0xFF94A3B8);
  static const green = Color(0xFF34D399);
}

ThemeData buildRoadSafeTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: RoadSafeColors.orange,
    brightness: Brightness.dark,
  ).copyWith(
    primary: RoadSafeColors.orange,
    onPrimary: Colors.white,
    surface: RoadSafeColors.card,
    outline: RoadSafeColors.border,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RoadSafeColors.background,
    dividerColor: RoadSafeColors.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: RoadSafeColors.card,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RoadSafeColors.background,
      contentPadding: const EdgeInsets.all(16),
      hintStyle: const TextStyle(color: RoadSafeColors.muted, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: RoadSafeColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: RoadSafeColors.orange),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RoadSafeColors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: RoadSafeColors.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: RoadSafeColors.orange.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? RoadSafeColors.orange
                : RoadSafeColors.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? RoadSafeColors.orange
                : RoadSafeColors.muted,
          )),
    ),
  );
}
