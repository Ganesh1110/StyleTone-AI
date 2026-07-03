import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/color_recommendation.dart';
import '../models/history_item.dart';
import 'database_helper.dart';

class HistoryService {
  static const String _historyKey = 'style_tone_history';

  // Save a successful color recommendation to history
  Future<String?> saveItem(
    File imageFile,
    String occasion,
    ColorRecommendation recommendation,
  ) async {
    try {
      // Get app doc directory to permanently save the image
      final docDir = await getApplicationDocumentsDirectory();
      final historyDir = Directory(p.join(docDir.path, 'history_images'));
      if (!await historyDir.exists()) {
        await historyDir.create(recursive: true);
      }

      // Copy image to history folder with a unique name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = p.extension(imageFile.path).isNotEmpty
          ? p.extension(imageFile.path)
          : '.jpg';
      final permanentImagePath =
          p.join(historyDir.path, 'img_$timestamp$fileExtension');

      await imageFile.copy(permanentImagePath);

      final String itemId = timestamp.toString();

      // Create new history item
      final newItem = HistoryItem(
        id: itemId,
        date: DateTime.now(),
        occasion: occasion,
        imagePath: permanentImagePath,
        recommendation: recommendation,
      );

      // Save to SQLite
      await DatabaseHelper.instance.insertHistory(newItem);
      return itemId;
    } catch (e) {
      debugPrint('Error saving history item: $e');
      return null;
    }
  }

  // Update the rating of an existing history item
  Future<void> updateRating(String id, int rating) async {
    try {
      await DatabaseHelper.instance.updateRating(id, rating);
    } catch (e) {
      debugPrint('Error updating history item rating: $e');
    }
  }

  // Retrieve history list (with automatic SharedPreferences-to-SQLite migration)
  Future<List<HistoryItem>> getHistory() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      List<HistoryItem> sqliteHistory = await dbHelper.fetchAllHistory();

      if (sqliteHistory.isEmpty) {
        // Check if there is legacy SharedPreferences data to migrate
        final prefs = await SharedPreferences.getInstance();
        final List<String>? legacyData = prefs.getStringList(_historyKey);

        if (legacyData != null && legacyData.isNotEmpty) {
          debugPrint('Migrating ${legacyData.length} legacy items from SharedPreferences to SQLite...');
          for (final itemStr in legacyData) {
            try {
              final item = HistoryItem.fromJson(json.decode(itemStr) as Map<String, dynamic>);
              await dbHelper.insertHistory(item);
            } catch (e) {
              debugPrint('Failed to migrate item: $e');
            }
          }
          // Reload from SQLite after migration
          sqliteHistory = await dbHelper.fetchAllHistory();
          // Clear legacy key to avoid future runs
          await prefs.remove(_historyKey);
        }
      }

      return sqliteHistory;
    } catch (e) {
      debugPrint('Error loading history: $e');
      return [];
    }
  }

  // Delete a specific history item
  Future<void> deleteItem(String id) async {
    try {
      final List<HistoryItem> currentHistory = await getHistory();

      // Find item to delete
      final int index = currentHistory.indexWhere((item) => item.id == id);
      if (index != -1) {
        final itemToDelete = currentHistory[index];

        // Delete the image file from disk
        final file = File(itemToDelete.imagePath);
        if (await file.exists()) {
          await file.delete();
        }

        // Delete from SQLite
        await DatabaseHelper.instance.deleteHistory(id);
      }
    } catch (e) {
      debugPrint('Error deleting history item: $e');
    }
  }

  // Clear all history items
  Future<void> clearAll() async {
    try {
      // Delete all stored history images
      final docDir = await getApplicationDocumentsDirectory();
      final historyDir = Directory(p.join(docDir.path, 'history_images'));
      if (await historyDir.exists()) {
        await historyDir.delete(recursive: true);
      }

      // Clear the database
      await DatabaseHelper.instance.clearHistory();
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }
}
