import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/history_item.dart';
import '../models/closet_item.dart';
import '../models/timeline_event.dart';
import '../services/database_helper.dart';
import '../widgets/glass_card.dart';

class StyleTimelineScreen extends StatefulWidget {
  const StyleTimelineScreen({super.key});

  @override
  State<StyleTimelineScreen> createState() => _StyleTimelineScreenState();
}

class _StyleTimelineScreenState extends State<StyleTimelineScreen> {
  List<HistoryItem> _history = [];
  List<ClosetItem> _closet = [];
  List<TimelineEvent> _timelineEvents = [];
  StyleAnalytics _analytics = StyleAnalytics();
  bool _isLoading = true;
  bool _showRewind = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final history = await DatabaseHelper.instance.fetchAllHistory();
    final closet = await DatabaseHelper.instance.getAllClosetItems();
    final events = await DatabaseHelper.instance.getAllTimelineEvents();

    // If events are empty, generate them from history + closet
    if (events.isEmpty) {
      await _generateEventsFromData(history, closet);
    }

    final allEvents = await DatabaseHelper.instance.getAllTimelineEvents();
    final analytics = _computeAnalytics(history, closet, allEvents);

    setState(() {
      _history = history;
      _closet = closet;
      _timelineEvents = allEvents;
      _analytics = analytics;
      _isLoading = false;
    });
  }

  Future<void> _generateEventsFromData(List<HistoryItem> history, List<ClosetItem> closet) async {
    for (final item in history) {
      await DatabaseHelper.instance.insertTimelineEvent(TimelineEvent(
        id: 'scan_${item.id}',
        type: TimelineEventType.scan,
        date: item.date,
        title: 'Style Scan: ${item.recommendation.detectedCategory}',
        description: 'Season detected: ${item.recommendation.detectedCategory} (${item.recommendation.confidence}% confidence)',
        imagePath: item.imagePath,
        metadata: {'occasion': item.occasion, 'season': item.recommendation.detectedCategory},
      ));
    }

    for (final item in closet) {
      await DatabaseHelper.instance.insertTimelineEvent(TimelineEvent(
        id: 'closet_${item.id}',
        type: TimelineEventType.closetAdd,
        date: DateTime.now(), // approximate
        title: 'Added ${item.colorName} ${item.category}',
        description: 'Colour: ${item.colorName} (${item.hexColor})',
        imagePath: item.imagePath,
        metadata: {'category': item.category, 'color': item.hexColor, 'colorName': item.colorName},
      ));
    }
  }

  StyleAnalytics _computeAnalytics(List<HistoryItem> history, List<ClosetItem> closet, List<TimelineEvent> events) {
    // Count colours in closet
    final colourCounts = <String, int>{};
    for (final item in closet) {
      colourCounts[item.colorName] = (colourCounts[item.colorName] ?? 0) + 1;
    }

    String mostWornColor = 'Unknown';
    String mostWornHex = '#CCCCCC';
    int maxCount = 0;
    colourCounts.forEach((name, count) {
      if (count > maxCount) {
        maxCount = count;
        mostWornColor = name;
        final match = closet.where((i) => i.colorName == name);
        if (match.isNotEmpty) mostWornHex = match.first.hexColor;
      }
    });

    // Dominant season
    final seasonCounts = <String, int>{};
    for (final item in history) {
      seasonCounts[item.recommendation.detectedCategory] = (seasonCounts[item.recommendation.detectedCategory] ?? 0) + 1;
    }
    String dominantSeason = 'Unknown';
    int maxSeason = 0;
    seasonCounts.forEach((season, count) {
      if (count > maxSeason) {
        maxSeason = count;
        dominantSeason = season;
      }
    });

    // Streak: consecutive days with scans
    int streak = 0;
    if (history.length >= 2) {
      final sortedDates = history.map((h) => h.date).toList()..sort();
      int currentStreak = 1;
      for (int i = 1; i < sortedDates.length; i++) {
        if (sortedDates[i].difference(sortedDates[i - 1]).inDays <= 2) {
          currentStreak++;
        } else {
          currentStreak = 1;
        }
      }
      streak = currentStreak;
    }

    final challengeCount = events.where((e) => e.type == TimelineEventType.challengeCompleted).length;

    return StyleAnalytics(
      totalScans: history.length,
      totalClosetItems: closet.length,
      totalChallengesCompleted: challengeCount,
      mostWornColorHex: mostWornHex,
      mostWornColorName: mostWornColor,
      dominantSeason: dominantSeason,
      streakDays: streak,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showRewind ? 'Style Rewind' : 'Style Evolution',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showRewind ? Icons.timeline_rounded : Icons.auto_awesome_rounded),
            tooltip: _showRewind ? 'Timeline view' : 'Style Rewind',
            onPressed: () => setState(() => _showRewind = !_showRewind),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _showRewind
              ? _buildStyleRewind(theme)
              : _buildTimeline(theme),
    );
  }

  Widget _buildTimeline(ThemeData theme) {
    if (_timelineEvents.isEmpty && _history.isEmpty && _closet.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timeline_rounded, size: 72, color: Colors.grey.shade500),
              SizedBox(height: 16),
              Text(
                'Your Style Journey Starts Here',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                'Scan your skin tone and add items to your closet.\nEvery styling moment will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    // Aggregate events from all data sources
    final allEntries = <TimelineEntry>[];

    for (final item in _history) {
      allEntries.add(TimelineEntry(
        date: item.date,
        type: 'scan',
        title: 'Style Scan: ${item.recommendation.detectedCategory}',
        subtitle: '${item.occasion} · ${item.recommendation.confidence}% match',
        imagePath: item.imagePath,
        season: item.recommendation.detectedCategory,
        colors: [
          item.recommendation.primaryColor,
          item.recommendation.secondaryColor,
          item.recommendation.accentColor,
        ],
      ));
    }

    for (final item in _closet) {
      allEntries.add(TimelineEntry(
        date: DateTime.now(), // approximate
        type: 'closet',
        title: '${item.colorName} ${item.category}',
        subtitle: item.hexColor.toUpperCase(),
        imagePath: item.imagePath,
        color: item.hexColor,
      ));
    }

    allEntries.sort((a, b) => b.date.compareTo(a.date));

    // Group by month
    final grouped = <String, List<TimelineEntry>>{};
    final monthFormat = DateFormat('MMMM yyyy');
    for (final entry in allEntries) {
      final key = monthFormat.format(entry.date);
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: grouped.entries.map((group) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    group.key,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            ...group.value.map((entry) => _buildTimelineEntry(entry)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTimelineEntry(TimelineEntry entry) {
    final isScan = entry.type == 'scan';
    final icon = isScan ? Icons.face_retouching_natural_rounded : Icons.checkroom_rounded;
    final iconColor = isScan ? Colors.deepPurple : Colors.teal;

    return Padding(
      padding: EdgeInsets.only(left: 6, bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline connector
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.white12,
                  ),
                ),
              ],
            ),
            SizedBox(width: 12),
            // Content card
            Expanded(
              child: GlassCard(
                color: Colors.white.withValues(alpha: 0.05),
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (entry.imagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(entry.imagePath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          cacheWidth: 100,
                          errorBuilder: (_, __, ___) => SizedBox(width: 48, height: 48),
                        ),
                      ),
                    if (entry.imagePath != null) SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            entry.subtitle,
                            style: TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                          if (entry.colors != null) ...[
                            SizedBox(height: 6),
                            Row(
                              children: entry.colors!.map((hex) {
                                return Container(
                                  width: 12,
                                  height: 12,
                                  margin: EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          if (entry.color != null)
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(entry.color!.replaceFirst('#', '0xFF'))),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  entry.color!.toUpperCase(),
                                  style: TextStyle(fontSize: 10, color: Colors.white38),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleRewind(ThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // Hero section
          GlassCard(
            color: Colors.white.withValues(alpha: 0.05),
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 48, color: Colors.amber.shade400),
                SizedBox(height: 12),
                Text(
                  'Your Style Rewind',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'A look back at your style journey',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Stats grid
          Row(
            children: [
              Expanded(child: _statCard('Scans', '${_analytics.totalScans}', Icons.face_retouching_natural_rounded, Colors.deepPurple)),
              SizedBox(width: 12),
              Expanded(child: _statCard('Closet Items', '${_analytics.totalClosetItems}', Icons.checkroom_rounded, Colors.teal)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('Day Streak', '${_analytics.streakDays}', Icons.local_fire_department_rounded, Colors.orange)),
              SizedBox(width: 12),
              Expanded(
                child: _statCard('Challenges', '${_analytics.totalChallengesCompleted}', Icons.emoji_events_rounded, Colors.amber),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Dominant season
          GlassCard(
            color: Colors.white.withValues(alpha: 0.05),
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.palette_rounded, color: Colors.deepPurple, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dominant Season', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      SizedBox(height: 4),
                      Text(
                        _analytics.dominantSeason,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Most worn colour
          GlassCard(
            color: Colors.white.withValues(alpha: 0.05),
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Color(int.parse(_analytics.mostWornColorHex.replaceFirst('#', '0xFF'))),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Most Worn Colour', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      SizedBox(height: 4),
                      Text(
                        _analytics.mostWornColorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _analytics.mostWornColorHex.toUpperCase(),
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32),

          // Share button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Style Rewind shared!')),
                );
              },
              icon: Icon(Icons.share_rounded),
              label: Text('Share Your Style Rewind'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      color: Colors.white.withValues(alpha: 0.05),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class TimelineEntry {
  final DateTime date;
  final String type;
  final String title;
  final String subtitle;
  final String? imagePath;
  final String? season;
  final List<String>? colors;
  final String? color;

  const TimelineEntry({
    required this.date,
    required this.type,
    required this.title,
    required this.subtitle,
    this.imagePath,
    this.season,
    this.colors,
    this.color,
  });
}
