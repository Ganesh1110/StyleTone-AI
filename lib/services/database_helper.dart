import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/history_item.dart';
import '../models/color_recommendation.dart';
import '../models/closet_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('styletone_ai.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // History table
    await db.execute('''
      CREATE TABLE history (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        occasion TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        rating INTEGER NOT NULL DEFAULT 0,
        recommendation_json TEXT NOT NULL
      )
    ''');

    // Closet table (for v2.5 virtual wardrobe)
    await db.execute('''
      CREATE TABLE closet (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        hexColor TEXT NOT NULL,
        colorName TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE closet (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL,
          imagePath TEXT NOT NULL,
          hexColor TEXT NOT NULL,
          colorName TEXT NOT NULL
        )
      ''');
      debugPrint('SQLite database upgraded to version 2: created closet table');
    }
  }

  // --- HISTORY DAO METHODS ---

  Future<int> insertHistory(HistoryItem item) async {
    final db = await instance.database;
    return await db.insert(
      'history',
      {
        'id': item.id,
        'date': item.date.toIso8601String(),
        'occasion': item.occasion,
        'imagePath': item.imagePath,
        'rating': item.rating,
        'recommendation_json': json.encode(item.recommendation.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HistoryItem>> fetchAllHistory() async {
    try {
      final db = await instance.database;
      final maps = await db.query('history', orderBy: 'date DESC');

      return maps.map((map) {
        final recMap = json.decode(map['recommendation_json'] as String) as Map<String, dynamic>;
        return HistoryItem(
          id: map['id'] as String,
          date: DateTime.parse(map['date'] as String),
          occasion: map['occasion'] as String,
          imagePath: map['imagePath'] as String,
          rating: map['rating'] as int? ?? 0,
          recommendation: ColorRecommendation.fromJson(recMap),
        );
      }).toList();
    } catch (e) {
      debugPrint('Database query failed: $e');
      return [];
    }
  }

  Future<int> updateRating(String id, int rating) async {
    final db = await instance.database;
    return await db.update(
      'history',
      {'rating': rating},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteHistory(String id) async {
    final db = await instance.database;
    return await db.delete(
      'history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearHistory() async {
    final db = await instance.database;
    await db.delete('history');
  }

  // --- CLOSET DAO METHODS ---

  Future<int> insertClosetItem(ClosetItem item) async {
    try {
      final db = await instance.database;
      return await db.insert(
        'closet',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting closet item: $e');
      return -1;
    }
  }

  Future<List<ClosetItem>> getClosetItemsByCategory(String category) async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'closet',
        where: 'category = ?',
        whereArgs: [category],
      );
      return maps.map((map) => ClosetItem.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error querying closet items by category: $e');
      return [];
    }
  }

  Future<List<ClosetItem>> getAllClosetItems() async {
    try {
      final db = await instance.database;
      final maps = await db.query('closet');
      return maps.map((map) => ClosetItem.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error querying all closet items: $e');
      return [];
    }
  }

  Future<int> deleteClosetItem(String id) async {
    try {
      final db = await instance.database;
      return await db.delete(
        'closet',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting closet item: $e');
      return -1;
    }
  }
}
