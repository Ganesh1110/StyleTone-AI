import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/history_item.dart';
import '../models/color_recommendation.dart';
import '../models/closet_item.dart';
import '../models/trip.dart';
import '../models/timeline_event.dart';

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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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

    await db.execute('''
      CREATE TABLE closet (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        hexColor TEXT NOT NULL,
        colorName TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE challenges (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        totalDays INTEGER NOT NULL,
        daysCompleted INTEGER NOT NULL DEFAULT 0,
        startDate TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 0,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        badgeName TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE challenge_progress (
        challengeId TEXT NOT NULL,
        dayNumber INTEGER NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        completedDate TEXT,
        PRIMARY KEY (challengeId, dayNumber),
        FOREIGN KEY (challengeId) REFERENCES challenges(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        destination TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        activities TEXT,
        packedItemIds TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE timeline_events (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL,
        date TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        imagePath TEXT,
        metadata TEXT
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
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE challenges (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          totalDays INTEGER NOT NULL,
          daysCompleted INTEGER NOT NULL DEFAULT 0,
          startDate TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 0,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          badgeName TEXT,
          capsuleItemIds TEXT DEFAULT '',
          seasonPaletteJson TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE challenge_progress (
          challengeId TEXT NOT NULL,
          dayNumber INTEGER NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          completedDate TEXT,
          PRIMARY KEY (challengeId, dayNumber),
          FOREIGN KEY (challengeId) REFERENCES challenges(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE trips (
          id TEXT PRIMARY KEY,
          destination TEXT NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT NOT NULL,
          activities TEXT,
          packedItemIds TEXT,
          isCompleted INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE timeline_events (
          id TEXT PRIMARY KEY,
          type INTEGER NOT NULL,
          date TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          imagePath TEXT,
          metadata TEXT
        )
      ''');
      debugPrint('SQLite database upgraded to version 3: added challenges, trips, timeline tables');
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE challenges ADD COLUMN capsuleItemIds TEXT DEFAULT \'\'');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE challenges ADD COLUMN seasonPaletteJson TEXT');
      } catch (_) {}
      debugPrint('SQLite database upgraded to version 4: added capsuleItemIds, seasonPaletteJson columns');
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



  // --- TRIP DAO METHODS ---

  Future<int> insertTrip(Trip trip) async {
    try {
      final db = await instance.database;
      return await db.insert(
        'trips',
        trip.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting trip: $e');
      return -1;
    }
  }

  Future<List<Trip>> getAllTrips() async {
    try {
      final db = await instance.database;
      final maps = await db.query('trips', orderBy: 'startDate DESC');
      return maps.map((map) => Trip.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error querying trips: $e');
      return [];
    }
  }

  Future<int> updateTrip(Trip trip) async {
    try {
      final db = await instance.database;
      return await db.update(
        'trips',
        trip.toMap(),
        where: 'id = ?',
        whereArgs: [trip.id],
      );
    } catch (e) {
      debugPrint('Error updating trip: $e');
      return -1;
    }
  }

  Future<int> deleteTrip(String id) async {
    try {
      final db = await instance.database;
      return await db.delete('trips', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      return -1;
    }
  }

  // --- TIMELINE DAO METHODS ---

  Future<int> insertTimelineEvent(TimelineEvent event) async {
    try {
      final db = await instance.database;
      return await db.insert(
        'timeline_events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting timeline event: $e');
      return -1;
    }
  }

  Future<List<TimelineEvent>> getAllTimelineEvents() async {
    try {
      final db = await instance.database;
      final maps = await db.query('timeline_events', orderBy: 'date DESC');
      return maps.map((map) => TimelineEvent.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error querying timeline events: $e');
      return [];
    }
  }

  Future<int> deleteTimelineEvent(String id) async {
    try {
      final db = await instance.database;
      return await db.delete('timeline_events', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error deleting timeline event: $e');
      return -1;
    }
  }

  Future<void> clearTimeline() async {
    try {
      final db = await instance.database;
      await db.delete('timeline_events');
    } catch (e) {
      debugPrint('Error clearing timeline: $e');
    }
  }
}
