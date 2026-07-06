import 'dart:convert' as convert;
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/challenge.dart';
import '../models/closet_item.dart';
import '../models/color_recommendation.dart';
import '../services/database_helper.dart';
import '../widgets/glass_card.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final Challenge challenge;

  const ChallengeDetailScreen({super.key, required this.challenge});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  Map<int, bool> _progress = {};
  bool _isLoading = true;
  late Challenge _challenge;
  List<ClosetItem> _capsuleItems = [];
  List<DailyChallenge> _personalizedChallenges = [];
  ColorRecommendation? _recommendation;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final allItems = await DatabaseHelper.instance.getAllClosetItems();
    _capsuleItems = allItems.where((i) => _challenge.capsuleItemIds.contains(i.id)).toList();

    if (_challenge.seasonPaletteJson != null) {
      try {
        final Map<String, dynamic> seasonData = convert.json.decode(_challenge.seasonPaletteJson!) as Map<String, dynamic>;
        _recommendation = ColorRecommendation.fromJson(seasonData);
      } catch (_) {}
    }

    _personalizedChallenges = generatePersonalizedChallenges(
      capsuleItems: _capsuleItems,
      recommendation: _recommendation,
    );

    final progress = await DatabaseHelper.instance.getChallengeProgress(_challenge.id);
    setState(() {
      _progress = progress;
      _isLoading = false;
    });
  }

  Future<void> _toggleDay(DailyChallenge daily) async {
    final isCompleted = _progress[daily.dayNumber] ?? false;
    final now = DateTime.now().toIso8601String();

    await DatabaseHelper.instance.upsertChallengeProgress(
      _challenge.id,
      daily.dayNumber,
      !isCompleted,
      completedDate: !isCompleted ? now : null,
    );

    final completedCount = _progress.values.where((v) => v).length + (isCompleted ? -1 : 1);
    final updated = _challenge.copyWith(
      daysCompleted: completedCount,
      isCompleted: completedCount >= 30,
      badgeName: completedCount >= 30 ? 'Capsule Graduate' : null,
    );
    await DatabaseHelper.instance.updateChallenge(updated);

    setState(() {
      _progress[daily.dayNumber] = !isCompleted;
      _challenge = updated;
    });
  }

  List<ClosetItem> _suggestedItems(DailyChallenge daily) {
    return _capsuleItems.where((i) => daily.suggestedItemIds.contains(i.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _challenge.progress;

    return Scaffold(
      appBar: AppBar(
        title: Text('Challenge Progress', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : Column(
              children: [
                _buildHeader(theme, progress),
                Expanded(child: _buildDayList()),
              ],
            ),
    );
  }

  Widget _buildHeader(ThemeData theme, double progress) {
    return GlassCard(
      color: Colors.white.withOpacity(0.05),
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '30-Day Capsule',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_challenge.capsuleSize} items · ${_recommendation?.detectedCategory ?? 'personalised'} palette',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_challenge.isCompleted)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.amber.shade700, Colors.orange.shade500]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Graduate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green : Colors.deepPurple,
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${_challenge.daysCompleted} / ${_challenge.totalDays} days completed',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (_challenge.isCompleted) ...[
            SizedBox(height: 12),
            Text(
              'Capsule Graduate! You mastered your palette with ${_challenge.capsuleSize} items.',
              style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: _personalizedChallenges.length,
      itemBuilder: (context, index) {
        final daily = _personalizedChallenges[index];
        final isCompleted = _progress[daily.dayNumber] ?? false;
        final suggested = _suggestedItems(daily);

        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: GlassCard(
            color: isCompleted ? Colors.green.withOpacity(0.08) : Colors.white.withOpacity(0.03),
            padding: EdgeInsets.all(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _toggleDay(daily),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : Colors.white10,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted ? Colors.green : Colors.white24,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isCompleted
                              ? Icon(Icons.check_rounded, color: Colors.green, size: 20)
                              : Text(
                                  '${daily.dayNumber}',
                                  style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Day ${daily.dayNumber}: ${daily.title}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isCompleted ? Colors.green : Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              daily.description,
                              style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.3),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isCompleted ? Colors.green : Colors.white24,
                        size: 20,
                      ),
                    ],
                  ),
                  if (suggested.isNotEmpty) ...[
                    SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: suggested.map((item) {
                          final itemColor = Color(int.parse(item.hexColor.replaceFirst('#', '0xFF')));
                          return Container(
                            width: 48,
                            margin: EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(File(item.imagePath), fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 4,
                                      color: itemColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
