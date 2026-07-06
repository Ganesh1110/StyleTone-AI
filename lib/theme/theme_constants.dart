import 'package:flutter/material.dart';

class ThemeConfig {
  final String id;
  final String label;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Brightness brightness;
  final Color textPrimary;
  final Color textSecondary;
  final String description;

  const ThemeConfig({
    required this.id,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.brightness,
    required this.textPrimary,
    required this.textSecondary,
    this.description = '',
  });
}

class ThemeConstants {
  static const Map<String, ThemeConfig> allThemes = {
    'default': ThemeConfig(
      id: 'default',
      label: 'StyleTone Signature',
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFFEC4899),
      background: Color(0xFF0B071E),
      surface: Color(0xFF171133),
      brightness: Brightness.dark,
      textPrimary: Colors.white,
      textSecondary: Color(0xFF9E99BA),
      description: 'Editorial violet & electric pink',
    ),
    'boucle_beige': ThemeConfig(
      id: 'boucle_beige',
      label: 'Bouclé Beige',
      primary: Color(0xFFC49B6C),
      secondary: Color(0xFFE8D5B7),
      background: Color(0xFF1A1510),
      surface: Color(0xFF2D241C),
      brightness: Brightness.dark,
      textPrimary: Colors.white,
      textSecondary: Color(0xFFB8A99A),
      description: 'Quiet luxury, warm camel & champagne',
    ),
    'sorbet_pastel': ThemeConfig(
      id: 'sorbet_pastel',
      label: 'Sorbet Pastel',
      primary: Color(0xFFD4A5E5),
      secondary: Color(0xFFA8D8B9),
      background: Color(0xFF1A1423),
      surface: Color(0xFF2E1F3A),
      brightness: Brightness.dark,
      textPrimary: Colors.white,
      textSecondary: Color(0xFFB8A8C4),
      description: 'Ethereal lavender & mint cream',
    ),
    'terracotta_earth': ThemeConfig(
      id: 'terracotta_earth',
      label: 'Terracotta Earth',
      primary: Color(0xFFD9734C),
      secondary: Color(0xFF8FA86A),
      background: Color(0xFF14100C),
      surface: Color(0xFF241E18),
      brightness: Brightness.dark,
      textPrimary: Colors.white,
      textSecondary: Color(0xFFB09A8A),
      description: 'Warm terracotta & sage green',
    ),
    'royal_luxe': ThemeConfig(
      id: 'royal_luxe',
      label: 'Royal Luxe',
      primary: Color(0xFFC9A84C),
      secondary: Color(0xFF8B2F3A),
      background: Color(0xFF0C0814),
      surface: Color(0xFF1A1530),
      brightness: Brightness.dark,
      textPrimary: Colors.white,
      textSecondary: Color(0xFFA89CC0),
      description: 'Gold & burgundy opulence',
    ),
  };

  static const List<String> themeOrder = [
    'default',
    'boucle_beige',
    'sorbet_pastel',
    'terracotta_earth',
    'royal_luxe',
  ];

  static List<ThemeConfig> get orderedThemes =>
      themeOrder.map((id) => allThemes[id]!).toList();

  static ThemeConfig get defaultTheme => allThemes['default']!;

  static ThemeConfig getTheme(String id) =>
      allThemes[id] ?? defaultTheme;

  static const Map<String, String> seasonThemeMap = {
    'spring': 'boucle_beige',
    'summer': 'sorbet_pastel',
    'autumn': 'terracotta_earth',
    'winter': 'royal_luxe',
  };

  static String? themeForSeason(String season) =>
      seasonThemeMap[season.toLowerCase()];

  static const Map<String, String> oldToNewMapping = {
    'ocean': 'royal_luxe',
    'forest': 'terracotta_earth',
  };

  static String migrateOldTheme(String oldThemeName) =>
      oldToNewMapping[oldThemeName] ?? oldThemeName;
}
