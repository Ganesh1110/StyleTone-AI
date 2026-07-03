import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Base Colors
  static const Color primary = Color(0xFF6A1B9A);
  static const Color secondary = Color(0xFFE94057);
  static const Color background = Color(0xFF0F0F13);
  static const Color surface = Color(0xFF1E1E24);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0A5);

  // Ocean Theme Colors
  static const Color oceanPrimary = Color(0xFF0066CC);
  static const Color oceanSecondary = Color(0xFF00BCD4);

  // Forest Theme Colors
  static const Color forestPrimary = Color(0xFF2E7D32);
  static const Color forestSecondary = Color(0xFFFF8F00);

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
    Color? background,
    Color? surface,
  }) {
    final bg = background ?? AppTheme.background;
    final sf = surface ?? AppTheme.surface;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: sf,
        background: bg,
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
    return _buildThemeData(primary: primary, secondary: secondary);
  }

  static ThemeData get oceanTheme {
    return _buildThemeData(primary: oceanPrimary, secondary: oceanSecondary);
  }

  static ThemeData get forestTheme {
    return _buildThemeData(primary: forestPrimary, secondary: forestSecondary);
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
        );
      default:
        return darkTheme;
    }
  }
}
