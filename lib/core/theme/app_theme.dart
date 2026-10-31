import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_settings_service.dart';

class AppTheme {
  // FotMob & Pro Design Dark Mode Colors
  static const Color background = Color(0xFF0D1117); // Deep pitch black canvas
  static const Color surface = Color(0xFF161B22);    // Elevated FotMob card surface
  static const Color cardHover = Color(0xFF1C2129);
  static const Color primary = Color(0xFF00D06C);    // FotMob Neon Green
  static const Color primaryDark = Color(0xFF00A855);
  static const Color secondary = Color(0xFF00E5FF);  // Electric Cyan accent
  static const Color accentViolet = Color(0xFF7C3AED);
  static const Color success = Color(0xFF00D06C);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color cardBorder = Color(0xFF272F3D);

  // Card curvature tokens (dynamic based on live settings)
  static double get radiusLg => AppSettingsService.instance.radiusLg;
  static double get radiusMd => AppSettingsService.instance.radiusMd;
  static double get radiusSm => AppSettingsService.instance.radiusSm;
  static const double radiusPill = 999.0;

  // Light mode colors
  static const Color lightBackground = Color(0xFFF6F8FA);
  static const Color lightSurface = Colors.white;
  static const Color lightCardBorder = Color(0xFFD0D7DE);
  static const Color lightTextPrimary = Color(0xFF1F2328);
  static const Color lightTextSecondary = Color(0xFF656D76);

  // Dynamic context helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? background : lightBackground;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? surface : lightSurface;

  static Color cardBorderOf(BuildContext context) =>
      isDark(context) ? cardBorder : lightCardBorder;

  static Color borderOf(BuildContext context) => cardBorderOf(context);

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
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: Color(0xFF334155), width: 0.8),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
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
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: lightCardBorder, width: 0.8),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
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
