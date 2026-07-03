import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'profile_service.dart';

class ThemeService {
  static final ValueNotifier<ThemeData> notifier =
      ValueNotifier<ThemeData>(AppTheme.darkTheme);

  static Future<void> loadTheme() async {
    final profile = await ProfileService().getProfile();
    notifier.value = AppTheme.getThemeByName(
      profile.themeName,
      customPrimary: profile.customPrimaryColor != null
          ? AppTheme.hexToColor(profile.customPrimaryColor!)
          : null,
      customSecondary: profile.customSecondaryColor != null
          ? AppTheme.hexToColor(profile.customSecondaryColor!)
          : null,
    );
  }
}
