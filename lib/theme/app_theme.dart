import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Default Premium Theme (Modern Orchid & Twilight) ──────────────────────
  static const Color primary = Color(0xFF8B5CF6); // Modern Violet
  static const Color secondary = Color(0xFFEC4899); // Electric Hot Pink
  static const Color background = Color(0xFF0B071E); // Rich Deep Twilight Navy
  static const Color surface = Color(0xFF171133); // Cozy Purple-Slate
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9E99BA); // Muted Violet-Silver

  // ─── Ocean Premium Theme (Electric Coral & Seafoam) ────────────────────────
  static const Color oceanPrimary = Color(0xFF0EA5E9); // Electric Blue
  static const Color oceanSecondary = Color(0xFF06B6D4); // Cyan Seafoam
  static const Color oceanBackground = Color(0xFF050E1A); // Deep Marine Blue
  static const Color oceanSurface = Color(0xFF0E1A2D); // Deep Teal-Slate

  // ─── Forest Premium Theme (Deep Moss & Golden Champagne) ───────────────────
  static const Color forestPrimary = Color(0xFF10B981); // Bright Emerald
  static const Color forestSecondary = Color(0xFFF59E0B); // Amber Champagne
  static const Color forestBackground = Color(0xFF040D0A); // Forest Pine Shadow
  static const Color forestSurface = Color(0xFF0D1C17); // Mossy Bark

  // Gradient definitions
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

  static Color hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static ThemeData _buildThemeData({
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
  }) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        background: background,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          color: textSecondary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
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
          foregroundColor: secondary,
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return _buildThemeData(
      primary: primary,
      secondary: secondary,
      background: background,
      surface: surface,
    );
  }

  static ThemeData get oceanTheme {
    return _buildThemeData(
      primary: oceanPrimary,
      secondary: oceanSecondary,
      background: oceanBackground,
      surface: oceanSurface,
    );
  }

  static ThemeData get forestTheme {
    return _buildThemeData(
      primary: forestPrimary,
      secondary: forestSecondary,
      background: forestBackground,
      surface: forestSurface,
    );
  }

  static ThemeData getThemeByName(
    String name, {
    Color? customPrimary,
    Color? customSecondary,
  }) {
    switch (name) {
      case 'ocean':
        return oceanTheme;
      case 'forest':
        return forestTheme;
      case 'custom':
        return _buildThemeData(
          primary: customPrimary ?? primary,
          secondary: customSecondary ?? secondary,
          background: background,
          surface: surface,
        );
      default:
        return darkTheme;
    }
  }
}
