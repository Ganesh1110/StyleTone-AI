import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_constants.dart';

class AppTheme {
  static Color hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static LinearGradient primaryGradientFor(Color p, Color s) {
    return LinearGradient(
      colors: [p, s],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8A2387), Color(0xFFE94057)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFE94057), Color(0xFFF27121)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData buildThemeFromConfig(ThemeConfig config) {
    final isDark = config.brightness == Brightness.dark;
    return ThemeData(
      brightness: config.brightness,
      scaffoldBackgroundColor: config.background,
      primaryColor: config.primary,
      colorScheme: ColorScheme(
        primary: config.primary,
        secondary: config.secondary,
        surface: config.surface,
        error: const Color(0xFFCF6679),
        onPrimary: isDark ? Colors.white : Colors.white,
        onSecondary: isDark ? Colors.white : Colors.white,
        onSurface: config.textPrimary,
        onError: Colors.black,
        brightness: config.brightness,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: config.textPrimary,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: config.textPrimary,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: config.textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: config.textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: config.textPrimary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          color: config.textSecondary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          color: config.textSecondary,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: config.textPrimary,
        ),
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: config.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: config.textPrimary,
        ),
        iconTheme: IconThemeData(color: config.textPrimary),
        foregroundColor: config.textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: config.primary,
          foregroundColor: config.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: config.secondary,
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return config.primary;
          return config.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return config.primary.withValues(alpha: 0.5);
          }
          return config.textSecondary.withValues(alpha: 0.3);
        }),
      ),
      chipTheme: ChipThemeData(
        selectedColor: config.primary,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        side: BorderSide.none,
        labelStyle: TextStyle(color: config.textPrimary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: config.primary,
        inactiveTrackColor: config.textSecondary.withValues(alpha: 0.3),
        thumbColor: config.primary,
        overlayColor: config.primary.withValues(alpha: 0.12),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: config.surface,
        selectedItemColor: config.primary,
        unselectedItemColor: config.textSecondary.withValues(alpha: 0.6),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: config.textSecondary.withValues(alpha: 0.15),
    );
  }

  static ThemeData get darkTheme =>
      buildThemeFromConfig(ThemeConstants.defaultTheme);

  static ThemeData getThemeByName(
    String name, {
    Color? customPrimary,
    Color? customSecondary,
  }) {
    final migratedName = ThemeConstants.migrateOldTheme(name);
    if (migratedName == 'custom') {
      final config = ThemeConstants.defaultTheme;
      return buildThemeFromConfig(ThemeConfig(
        id: 'custom',
        label: 'Custom',
        primary: customPrimary ?? config.primary,
        secondary: customSecondary ?? config.secondary,
        background: config.background,
        surface: config.surface,
        brightness: config.brightness,
        textPrimary: config.textPrimary,
        textSecondary: config.textSecondary,
      ));
    }
    return buildThemeFromConfig(ThemeConstants.getTheme(migratedName));
  }
}
