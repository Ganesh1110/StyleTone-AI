import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/color_recommendation.dart';
import '../models/history_item.dart';

class HistoryService {
  static const String _historyKey = 'style_tone_history';

  // Save a successful color recommendation to history
  Future<void> saveItem(
    File imageFile,
    String occasion,
    ColorRecommendation recommendation,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

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

      // Create new history item
      final newItem = HistoryItem(
        id: timestamp.toString(),
        date: DateTime.now(),
        occasion: occasion,
        imagePath: permanentImagePath,
        recommendation: recommendation,
      );

      // Load existing history
      final List<HistoryItem> currentHistory = await getHistory();

      // Prepend the new item (newest first)
      currentHistory.insert(0, newItem);

      // Serialize and save
      final List<String> serialized =
          currentHistory.map((item) => json.encode(item.toJson())).toList();
      await prefs.setStringList(_historyKey, serialized);
    } catch (e) {
      // Log or handle error silently
      debugPrint('Error saving history item: $e');
    }
  }

  // Retrieve history list
  Future<List<HistoryItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? serialized = prefs.getStringList(_historyKey);
      if (serialized == null) return [];

      return serialized
          .map(
            (itemStr) => HistoryItem.fromJson(
              json.decode(itemStr) as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error loading history: $e');
      return [];
    }
  }

  // Delete a specific history item
  Future<void> deleteItem(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
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

        // Remove from list
        currentHistory.removeAt(index);

        // Serialize and save
        final List<String> serialized =
            currentHistory.map((item) => json.encode(item.toJson())).toList();
        await prefs.setStringList(_historyKey, serialized);
      }
    } catch (e) {
      debugPrint('Error deleting history item: $e');
    }
  }
}
