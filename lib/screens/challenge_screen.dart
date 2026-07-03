import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/challenge.dart';
import '../services/database_helper.dart';
import '../widgets/glass_card.dart';
import 'challenge_detail_screen.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  List<Challenge> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    final challenges = await DatabaseHelper.instance.getAllChallenges();
    setState(() {
      _challenges = challenges;
      _isLoading = false;
    });
  }

  Future<void> _startNewChallenge() async {
    final existing = await DatabaseHelper.instance.getAllChallenges();
    if (existing.any((c) => c.isActive && !c.isCompleted)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complete your current challenge first!')),
        );
      }
      return;
    }

    final challenge = Challenge(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '30-Day Capsule Wardrobe',
      description: 'Build a versatile 30-piece capsule and master colour coordination with your seasonal palette.',
      totalDays: 30,
      startDate: DateTime.now(),
      isActive: true,
    );

    await DatabaseHelper.instance.insertChallenge(challenge);
    _loadChallenges();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Capsule Challenge', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _challenges.isEmpty
              ? _buildEmptyState(theme)
              : _buildChallengeList(),
      floatingActionButton: _challenges.isEmpty || _challenges.every((c) => c.isCompleted)
          ? FloatingActionButton.extended(
              onPressed: _startNewChallenge,
              backgroundColor: Colors.deepPurple,
              icon: Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: Text('Start 30-Day Challenge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, size: 80, color: Colors.amber.shade400),
            SizedBox(height: 24),
            Text(
              '30-Day Capsule Wardrobe',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Select 30 items from your closet. Each day, we will challenge you\nto style them in new ways using your seasonal palette.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Complete all 30 days to earn the\n"Capsule Graduate" badge!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amber.shade300,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startNewChallenge,
              icon: Icon(Icons.rocket_launch_rounded),
              label: Text('Start Your Journey'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeList() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        ..._challenges.map((challenge) => _buildChallengeCard(challenge)),
      ],
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    final progress = challenge.progress;
    final dateFormat = DateFormat('MMM d, yyyy');
    final daysLeft = challenge.totalDays - challenge.daysCompleted;

    Color progressColor;
    if (progress >= 1.0) {
      progressColor = Colors.green;
    } else if (progress >= 0.5) {
      progressColor = Colors.amber;
    } else {
      progressColor = Colors.deepPurple;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: GlassCard(
        color: Colors.white.withOpacity(0.05),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: challenge.isCompleted ? Colors.green.withOpacity(0.15) : Colors.deepPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    challenge.isCompleted ? Icons.emoji_events_rounded : Icons.timer_rounded,
                    color: challenge.isCompleted ? Colors.green : Colors.deepPurple,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        challenge.isCompleted
                            ? 'Completed on ${dateFormat.format(challenge.startDate.add(Duration(days: challenge.totalDays)))}'
                            : 'Started ${dateFormat.format(challenge.startDate)}',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                if (challenge.isCompleted)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'GRADUATED',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${challenge.daysCompleted}/${challenge.totalDays} days',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (!challenge.isCompleted)
                  Text(
                    '$daysLeft days remaining',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: challenge.isCompleted ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChallengeDetailScreen(challenge: challenge),
                    ),
                  ).then((_) => _loadChallenges());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: challenge.isCompleted ? Colors.grey : Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  challenge.isCompleted ? 'View Completed' : 'Continue Challenge',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (challenge.isCompleted && challenge.badgeName != null) ...[
              SizedBox(height: 12),
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade700, Colors.orange.shade500],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Badge Earned: ${challenge.badgeName}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
