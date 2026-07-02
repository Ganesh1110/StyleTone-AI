import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const String _profileKey = 'style_tone_user_profile';

  // Save the user profile details locally
  Future<void> saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String serialized = json.encode(profile.toJson());
      await prefs.setString(_profileKey, serialized);
    } catch (e) {
      debugPrint('Error saving user profile: $e');
    }
  }

  // Load the user profile, falling back to a default profile if none exists
  Future<UserProfile> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? serialized = prefs.getString(_profileKey);
      if (serialized == null) {
        return UserProfile.defaultProfile();
      }

      return UserProfile.fromJson(
        json.decode(serialized) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return UserProfile.defaultProfile();
    }
  }
}
