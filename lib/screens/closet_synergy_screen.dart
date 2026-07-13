import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/closet_item.dart';
import '../models/synergy_result.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../widgets/synergy_ring_painter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClosetSynergyScreen — Smart Shop Synergy feature entry point
// ─────────────────────────────────────────────────────────────────────────────

class ClosetSynergyScreen extends StatefulWidget {
  const ClosetSynergyScreen({super.key});

  @override
  State<ClosetSynergyScreen> createState() => _ClosetSynergyScreenState();
}

class _ClosetSynergyScreenState extends State<ClosetSynergyScreen> {
  SynergyResult? _result;
  File? _selectedImage;
  bool _isAnalyzing = false;
  bool _isLoadingData = true;
  String? _errorMessage;
  String _activeSeason = 'Spring Season';
  List<ClosetItem> _closetItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final items = await DatabaseHelper.instance.getAllClosetItems();
      final history = await DatabaseHelper.instance.fetchAllHistory();
      String season = 'Spring Season';
      if (history.isNotEmpty) {
        season = history.first.recommendation.detectedCategory;
      }
      if (mounted) {
        setState(() {
          _closetItems = items;
          _activeSeason = season;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;

    setState(() {
      _selectedImage = File(picked.path);
      _isAnalyzing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final data = await ApiService().analyzeGarmentSynergy(
        imageFile: _selectedImage!,
        activeSeason: _activeSeason,
        closetItems: _closetItems,
      );
      if (mounted) {
        setState(() {
          _result = SynergyResult.fromJson(data);
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  void _reset() => setState(() {
        _result = null;
        _selectedImage = null;
        _errorMessage = null;
      });

  // ─── Scaffold ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      appBar: AppBar(
        title: const Text('Smart Shop Synergy'),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              tooltip: 'Check another item',
              onPressed: _reset,
            ),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple))
          : _isAnalyzing
              ? _buildLoadingState()
              : _errorMessage != null
                  ? _buildErrorState()
                  : _result != null
                      ? _buildResultState()
                      : _buildPickerState(),
    );
  }

  // ─── PICKER STATE ─────────────────────────────────────────────────────────

  Widget _buildPickerState() {
    final seasonName = _activeSeason.split(' ').first;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Active season badge
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade900,
                      Colors.indigo.shade800
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.deepPurple.shade300.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.palette_rounded,
                        color: Colors.white70, size: 15),
                    const SizedBox(width: 7),
                    Text(
                      'Active Season: $_activeSeason',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 44),

            // Hero icon
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade700,
                    Colors.indigo.shade600
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.5),
                    blurRadius: 44,
                    spreadRadius: 14,
                  ),
                ],
              ),
              child: const Icon(Icons.add_shopping_cart_rounded,
                  color: Colors.white, size: 58),
            )
                .animate()
                .scale(duration: 620.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 32),

            const Text(
              'Closet Synergy Check',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 10),
            Text(
              'Scan or upload any garment to see how well it fits your $seasonName '
              'palette and how many new outfit combos it unlocks from your wardrobe.',
              style: const TextStyle(
                  fontSize: 14.5, color: Colors.white60, height: 1.55),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 150.ms),

            // Closet status chip
            const SizedBox(height: 18),
            if (_closetItems.isEmpty)
              _warningBanner(
                  'Your closet is empty. Add garments first for outfit combo suggestions.')
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.checkroom_rounded,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_closetItems.length} item${_closetItems.length == 1 ? '' : 's'} ready for synergy check',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 48),

            // Camera CTA
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _pickAndAnalyze(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 20),
                label: const Text(
                  'Scan In-Store Tag or Garment',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 10,
                  shadowColor: Colors.deepPurple.withOpacity(0.5),
                ),
              ),
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 14),

            // Gallery CTA
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () => _pickAndAnalyze(ImageSource.gallery),
                icon: Icon(Icons.photo_library_rounded,
                    color: Colors.deepPurple.shade200, size: 20),
                label: Text(
                  'Upload Product Screenshot',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.deepPurple.shade200),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.deepPurple.shade400.withOpacity(0.5),
                      width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ).animate().fadeIn(delay: 330.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _warningBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(message,
                style: const TextStyle(
                    color: Colors.amber, fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ─── LOADING STATE ────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpinKitPulse(color: Colors.deepPurple, size: 68),
          const SizedBox(height: 30),
          const Text(
            'Computing Closet Synergy…',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            'Checking your ${_activeSeason.split(" ").first} palette\nand ${_closetItems.length} wardrobe items',
            style: const TextStyle(
                color: Colors.white54, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── ERROR STATE ──────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text('Analysis Failed',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Try Again',
                  style: TextStyle(color: Colors.white)),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RESULT STATE ─────────────────────────────────────────────────────────

  Widget _buildResultState() {
    final result = _result!;
    final sColor = _scoreColor(result.synergyScore);
    final sLabel = _scoreLabel(result.synergyScore);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResultHeader(result).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          _buildScoreCard(result, sColor, sLabel)
              .animate()
              .fadeIn(delay: 100.ms, duration: 500.ms)
              .slideY(begin: 0.06, end: 0),
          if (result.newCombosCount > 0) ...[
            const SizedBox(height: 20),
            _buildCombosSection(result),
          ],
          if (result.gapFillers.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildGapFillersSection(result),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.add_shopping_cart_rounded,
                  color: Colors.white60, size: 18),
              label: const Text('Check Another Item',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader(SynergyResult result) {
    final itemColor = _safeColor(result.newItemHex);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Row(
        children: [
          // Garment image or colour swatch
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _selectedImage != null
                ? Image.file(_selectedImage!,
                    width: 76, height: 76, fit: BoxFit.cover)
                : Container(width: 76, height: 76, color: itemColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Garment',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(result.newItemColorName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: itemColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(result.newItemHex.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                            fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
          // Season badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.deepPurple.shade800,
                Colors.indigo.shade700
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _activeSeason.replaceAll(' Season', ''),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(
      SynergyResult result, Color scoreColor, String scoreLabel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade900.withOpacity(0.85),
            Colors.indigo.shade900.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: scoreColor.withOpacity(0.12),
              blurRadius: 24,
              spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Closet Synergy Score',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4),
          ),
          const SizedBox(height: 24),

          // Animated ring gauge
          TweenAnimationBuilder<double>(
            tween:
                Tween<double>(begin: 0, end: result.synergyScore / 100.0),
            duration: const Duration(milliseconds: 1800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => SizedBox(
              width: 170,
              height: 170,
              child: CustomPaint(
                painter:
                    SynergyRingPainter(value: value, color: scoreColor),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(value * 100).round()}',
                        style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1),
                      ),
                      const Text('%',
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white60,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Score label chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scoreColor.withOpacity(0.4)),
            ),
            child: Text(scoreLabel,
                style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5)),
          ),

          // Unlocked combos callout
          if (result.newCombosCount > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withOpacity(0.09)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_open_rounded,
                      color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${result.newCombosCount}',
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text: ' new outfit combos unlocked!',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── COMBOS SECTION ───────────────────────────────────────────────────────

  Widget _buildCombosSection(SynergyResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: Colors.amberAccent, size: 17),
            SizedBox(width: 8),
            Text('New Outfit Combinations',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ...result.newCombos.asMap().entries.map(
              (e) => _comboCard(e.value)
                  .animate()
                  .fadeIn(delay: (e.key * 60).ms, duration: 300.ms)
                  .slideX(begin: 0.07, end: 0),
            ),
      ],
    );
  }

  Widget _comboCard(OutfitCombo combo) {
    final newC = _safeColor(combo.newItemHex);
    final existC = _safeColor(combo.existingItemHex);
    final isContrasting = combo.comboType == 'Contrasting';
    final scoreC = _comboColor(combo.matchScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          _colorCircle(newC),
          const SizedBox(width: 6),
          Icon(
            isContrasting ? Icons.contrast_rounded : Icons.link_rounded,
            color: Colors.white30,
            size: 16,
          ),
          const SizedBox(width: 6),
          _colorCircle(existC),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(combo.existingItemName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(_catLabel(combo.existingCategory),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
                Text(combo.comboType,
                    style: TextStyle(
                        color: scoreC,
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: scoreC.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${combo.matchScore}%',
                style: TextStyle(
                    color: scoreC,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ─── GAP FILLERS SECTION ──────────────────────────────────────────────────

  Widget _buildGapFillersSection(SynergyResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shopping_bag_outlined,
                color: Colors.cyanAccent, size: 17),
            SizedBox(width: 8),
            Text('Complete Your Wardrobe',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Gap pieces that unlock more full-outfit combos',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 10),
        ...result.gapFillers.asMap().entries.map(
              (e) => _gapCard(e.value)
                  .animate()
                  .fadeIn(delay: (e.key * 80).ms, duration: 350.ms)
                  .slideY(begin: 0.05, end: 0),
            ),
      ],
    );
  }

  Widget _gapCard(GapFiller filler) {
    final c = _safeColor(filler.recommendedHex);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.withOpacity(0.09),
            Colors.cyan.withOpacity(0.04)
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                        color: c.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1)
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(filler.categoryLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(
                      '${filler.recommendedColorName} • ${filler.recommendedHex.toUpperCase()}',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '🛍️ Searching ${filler.recommendedColorName} ${filler.categoryLabel}…'),
                      backgroundColor: Colors.teal.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Colors.teal, Color(0xFF00BCD4)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Shop',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
            ],
          ),
          if (filler.reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(filler.reason,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  static Widget _colorCircle(Color c) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
      );

  static Color _safeColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  static Color _scoreColor(int s) {
    if (s >= 86) return const Color(0xFF00E5A0);
    if (s >= 66) return const Color(0xFF4CAF50);
    if (s >= 41) return const Color(0xFFFFC107);
    return const Color(0xFFFF6B6B);
  }

  static String _scoreLabel(int s) {
    if (s >= 86) return '✨ Excellent Palette Match';
    if (s >= 66) return '👍 Great Match';
    if (s >= 41) return '🤔 Moderate Match';
    return '⚠️ Poor Match — Risky Buy';
  }

  static Color _comboColor(int s) {
    if (s >= 72) return Colors.greenAccent;
    if (s >= 52) return Colors.amberAccent;
    return Colors.orangeAccent;
  }

  static String _catLabel(String cat) {
    switch (cat) {
      case 'top':
        return 'Tops';
      case 'bottom':
        return 'Bottoms';
      case 'outer':
        return 'Outerwear';
      case 'shoes':
        return 'Shoes';
      case 'accessory':
        return 'Accessories';
      default:
        return cat;
    }
  }
}


