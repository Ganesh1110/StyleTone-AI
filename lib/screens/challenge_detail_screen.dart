import 'package:flutter/material.dart';
import '../models/challenge.dart';
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

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    final progress = await DatabaseHelper.instance.getChallengeProgress(_challenge.id);
    setState(() {
      _progress = progress;
      _isLoading = false;
    });
  }

  Future<void> _toggleDay(int dayNumber) async {
    final isCompleted = _progress[dayNumber] ?? false;
    final now = DateTime.now().toIso8601String();

    await DatabaseHelper.instance.upsertChallengeProgress(
      _challenge.id,
      dayNumber,
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
      _progress[dayNumber] = !isCompleted;
      _challenge = updated;
    });
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
              Text(
                '30-Day Capsule Wardrobe',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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
              'Congratulations! You earned the CAPSULE GRADUATE badge!',
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
      itemCount: capsuleWardrobeChallenges.length,
      itemBuilder: (context, index) {
        final daily = capsuleWardrobeChallenges[index];
        final isCompleted = _progress[daily.dayNumber] ?? false;

        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: GlassCard(
            color: isCompleted ? Colors.green.withOpacity(0.08) : Colors.white.withOpacity(0.03),
            padding: EdgeInsets.all(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _toggleDay(daily.dayNumber),
              child: Row(
                children: [
                  // Day number circle
                  Container(
                    width: 42,
                    height: 42,
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
                          ? Icon(Icons.check_rounded, color: Colors.green, size: 22)
                          : Text(
                              '${daily.dayNumber}',
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day ${daily.dayNumber}: ${daily.title}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isCompleted ? Colors.green : Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          daily.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isCompleted ? Colors.green : Colors.white24,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
