import 'dart:io';
import 'package:flutter/material.dart';
import '../models/closet_item.dart';
import '../models/history_item.dart';
import '../services/database_helper.dart';
import '../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OutfitCombinatorScreen extends StatefulWidget {
  const OutfitCombinatorScreen({super.key});

  @override
  State<OutfitCombinatorScreen> createState() => _OutfitCombinatorScreenState();
}

class _OutfitCombinatorScreenState extends State<OutfitCombinatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  HistoryItem? _latestScan;
  List<ClosetItem> _closetItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await DatabaseHelper.instance.fetchAllHistory();
      final closet = await DatabaseHelper.instance.getAllClosetItems();

      if (!mounted) return;
      setState(() {
        _latestScan = history.isNotEmpty ? history.first : null;
        _closetItems = closet;
      });
    } catch (e) {
      debugPrint('Error loading matchmaking data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Calculate perceptual color distance using the redmean approximation formula
  double _getColorDistance(String hex1, String hex2) {
    try {
      final r1 = int.parse(hex1.substring(1, 3), radix: 16);
      final g1 = int.parse(hex1.substring(3, 5), radix: 16);
      final b1 = int.parse(hex1.substring(5, 7), radix: 16);
      
      final r2 = int.parse(hex2.substring(1, 3), radix: 16);
      final g2 = int.parse(hex2.substring(3, 5), radix: 16);
      final b2 = int.parse(hex2.substring(5, 7), radix: 16);
      
      final double meanR = (r1 + r2) / 2.0;
      final double deltaR = (r1 - r2).toDouble();
      final double deltaG = (g1 - g2).toDouble();
      final double deltaB = (b1 - b2).toDouble();

      final double weightR = 2.0 + meanR / 256.0;
      final double weightG = 4.0;
      final double weightB = 2.0 + (255.0 - meanR) / 256.0;

      return weightR * deltaR * deltaR + weightG * deltaG * deltaG + weightB * deltaB * deltaB;
    } catch (e) {
      return 585225.0; // Max possible redmean distance squared
    }
  }

  int _calculateMatchScore(double distSquared) {
    // Redmean distance squared maxes out at ~585,000.
    // We scale it so that a visual distance squared of 15,000 or greater yields 0%, and 0 yields 100%
    final double score = 100.0 - (distSquared / 150.0);
    return score.clamp(0, 100).round();
  }

  Map<String, Map<String, dynamic>> _generateOutfitForOccasion(String occasion) {
    if (_latestScan == null || _closetItems.isEmpty) return {};

    final rec = _latestScan!.recommendation;
    final palette = rec.palettes[occasion] ?? rec.palettes['casual']!;

    // Categorize current closet items
    final tops = _closetItems.where((i) => i.category == 'top').toList();
    final bottoms = _closetItems.where((i) => i.category == 'bottom').toList();
    final outers = _closetItems.where((i) => i.category == 'outer').toList();
    final shoes = _closetItems.where((i) => i.category == 'shoes').toList();
    final accessories = _closetItems.where((i) => i.category == 'accessory').toList();

    // Matching functions
    Map<String, dynamic>? findBestMatch(List<ClosetItem> items, String targetHex) {
      if (items.isEmpty) return null;
      ClosetItem bestItem = items.first;
      double minDistance = double.infinity;

      for (var item in items) {
        final dist = _getColorDistance(item.hexColor, targetHex);
        if (dist < minDistance) {
          minDistance = dist;
          bestItem = item;
        }
      }

      final int score = _calculateMatchScore(minDistance);
      return {'item': bestItem, 'score': score};
    }

    // Match categories:
    // Tops matching primaryColor, Bottoms matching secondaryColor, etc.
    return {
      'top': findBestMatch(tops, palette.primaryColor) ?? {},
      'bottom': findBestMatch(bottoms, palette.secondaryColor) ?? {},
      'outer': findBestMatch(outers, palette.primaryColor) ?? {},
      'shoes': findBestMatch(shoes, palette.secondaryColor) ?? {},
      'accessory': findBestMatch(accessories, palette.accentColor) ?? {},
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfit Combinator'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Office Wear'),
            Tab(text: 'Party Night'),
            Tab(text: 'Casual Wear'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _latestScan == null
              ? _buildNoScanState()
              : _closetItems.isEmpty
                  ? _buildEmptyClosetState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOccasionMatchView('office'),
                        _buildOccasionMatchView('party'),
                        _buildOccasionMatchView('casual'),
                      ],
                    ),
    );
  }

  Widget _buildNoScanState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face_retouching_natural_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Personal Season Profile Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please perform at least one selfie scan from the Home Screen to determine your season palette before matching clothes!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyClosetState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Your Closet is Empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add clothes like tops, bottoms, and jackets to your closet first so we can suggest outfit combinations!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOccasionMatchView(String occasionKey) {
    final outfitMap = _generateOutfitForOccasion(occasionKey);
    final rec = _latestScan!.recommendation;
    final palette = rec.palettes[occasionKey] ?? rec.palettes['casual']!;

    // Match percentage averages
    int totalItems = 0;
    int totalScoreSum = 0;
    outfitMap.forEach((key, val) {
      if (val.containsKey('score')) {
        totalItems++;
        totalScoreSum += val['score'] as int;
      }
    });

    final int averageMatchScore = totalItems > 0 ? (totalScoreSum / totalItems).round() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Season & Fit Summary Card
          GlassCard(
            color: Colors.white.withOpacity(0.05),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detected: ${rec.detectedCategory}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary),
                    ),
                    if (averageMatchScore > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$averageMatchScore% Closet Match',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  palette.message,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
          const SizedBox(height: 24),

          const Text(
            'Suggested Outfit Combinations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white60),
          ),
          const SizedBox(height: 16),

          // Suggestion list
          _buildGarmentSlot(
            'Primary Layer / Tops',
            outfitMap['top']?['item'] as ClosetItem?,
            outfitMap['top']?['score'] as int?,
            palette.primaryColor,
          ),
          const SizedBox(height: 16),
          _buildGarmentSlot(
            'Secondary Layer / Bottoms',
            outfitMap['bottom']?['item'] as ClosetItem?,
            outfitMap['bottom']?['score'] as int?,
            palette.secondaryColor,
          ),
          const SizedBox(height: 16),
          _buildGarmentSlot(
            'Outerwear / Jackets',
            outfitMap['outer']?['item'] as ClosetItem?,
            outfitMap['outer']?['score'] as int?,
            palette.primaryColor,
          ),
          const SizedBox(height: 16),
          _buildGarmentSlot(
            'Shoes',
            outfitMap['shoes']?['item'] as ClosetItem?,
            outfitMap['shoes']?['score'] as int?,
            palette.secondaryColor,
          ),
          const SizedBox(height: 16),
          _buildGarmentSlot(
            'Accessory Accent',
            outfitMap['accessory']?['item'] as ClosetItem?,
            outfitMap['accessory']?['score'] as int?,
            palette.accentColor,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGarmentSlot(String roleLabel, ClosetItem? item, int? score, String targetColorHex) {
    final targetColor = Color(int.parse(targetColorHex.replaceFirst('#', '0xFF')));

    return GlassCard(
      color: Colors.white.withOpacity(0.05),
      padding: const EdgeInsets.all(14.0),
      child: Row(
        children: [
          // Item photo or placeholder
          if (item != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(item.imagePath),
                width: 75,
                height: 75,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inventory_2_outlined, color: Colors.white30),
            ),
          const SizedBox(width: 16),

          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 6),
                if (item != null) ...[
                  Text(
                    item.colorName,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Color(int.parse(item.hexColor.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getScoreColor(score ?? 0).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$score% Match',
                          style: TextStyle(
                            color: _getScoreColor(score ?? 0),
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  )
                ] else ...[
                  Row(
                    children: [
                      const Text(
                        'Target: ',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: targetColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        targetColorHex.toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.orange.shade400),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No garments registered. Tap closet to add.',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade400, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          )
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0, duration: 400.ms);
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.orange;
    return Colors.red;
  }
}
