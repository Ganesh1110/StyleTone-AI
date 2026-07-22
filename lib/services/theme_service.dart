import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_constants.dart';
import 'profile_service.dart';

class ThemeService {
  static final ValueNotifier<ThemeData> notifier =
      ValueNotifier<ThemeData>(AppTheme.darkTheme);

  static Future<void> loadTheme() async {
    final profile = await ProfileService().getProfile();

    final themeName = ThemeConstants.migrateOldTheme(profile.themeName);

    if (themeName != profile.themeName) {
      final updated = profile.copyWith(themeName: themeName);
      await ProfileService().saveProfile(updated);
    }

    notifier.value = AppTheme.getThemeByName(
      themeName,
      customPrimary: profile.customPrimaryColor != null
          ? AppTheme.hexToColor(profile.customPrimaryColor!)
          : null,
      customSecondary: profile.customSecondaryColor != null
          ? AppTheme.hexToColor(profile.customSecondaryColor!)
          : null,
    );
  }

  static Future<void> applyTheme(String themeName, {String? customPrimaryColor, String? customSecondaryColor}) async {
    final profile = await ProfileService().getProfile();
    final updated = profile.copyWith(
      themeName: themeName,
      customPrimaryColor: customPrimaryColor,
      customSecondaryColor: customSecondaryColor,
    );
    await ProfileService().saveProfile(updated);
    await loadTheme();
  }

  static String? themeForSeason(String season) =>
      ThemeConstants.themeForSeason(season);

  static String? getRecommendedTheme(String season) =>
      ThemeConstants.themeForSeason(season);
}
