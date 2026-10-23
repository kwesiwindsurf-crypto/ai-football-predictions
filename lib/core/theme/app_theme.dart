import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark mode colors
  static const Color background = Color(0xFF0F172A); // Deep sleek navy
  static const Color surface = Color(0xFF1E293B);
  static const Color primary = Color(0xFF38BDF8); // Neon blue
  static const Color secondary = Color(0xFFF472B6); // Neon pink for accents
  static const Color success = Color(0xFF4ADE80);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  // Light mode colors
  static const Color lightBackground = Color(0xFFF1F5F9); // Clean slate light
  static const Color lightSurface = Colors.white;
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dynamic context helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? background : lightBackground;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? surface : lightSurface;

  static Color cardBorderOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF334155) : lightCardBorder;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? textPrimary : lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? textSecondary : lightTextSecondary;

  static Color primaryOf(BuildContext context) =>
      Theme.of(context).primaryColor;

  static ThemeData darkTheme([Color? primaryColor]) {
    final effectivePrimary = primaryColor ?? primary;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: effectivePrimary,
      cardColor: surface,
      colorScheme: ColorScheme.dark(
        primary: effectivePrimary,
        secondary: secondary,
        surface: surface,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        titleLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        bodyLarge: const TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 0.8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: effectivePrimary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData lightTheme([Color? primaryColor]) {
    final effectivePrimary = primaryColor ?? const Color(0xFF0284C7); // Rich vibrant blue / emerald
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: effectivePrimary,
      cardColor: lightSurface,
      colorScheme: ColorScheme.light(
        primary: effectivePrimary,
        secondary: const Color(0xFFDB2777),
        surface: lightSurface,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          color: lightTextPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        titleLarge: GoogleFonts.outfit(
          color: lightTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        bodyLarge: const TextStyle(color: lightTextPrimary, fontSize: 16),
        bodyMedium: const TextStyle(color: lightTextSecondary, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightCardBorder, width: 0.8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightTextPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: effectivePrimary,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
