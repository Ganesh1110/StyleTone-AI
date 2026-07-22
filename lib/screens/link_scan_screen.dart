import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../models/closet_item.dart';
import '../widgets/glass_card.dart';

class LinkScanScreen extends StatefulWidget {
  const LinkScanScreen({super.key});

  @override
  State<LinkScanScreen> createState() => _LinkScanScreenState();
}

class _LinkScanScreenState extends State<LinkScanScreen> {
  final _urlController = TextEditingController();
  final _api = ApiService();

  bool _loading = false;
  bool _isLoadingData = true;
  String? _error;
  Map<String, dynamic>? _result;
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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await _api.analyzeDressUrl(
        url: url,
        activeSeason: _activeSeason,
        closetItems: _closetItems,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shop Link Scanner')),
        body: const Center(child: SpinKitFadingCircle(color: Colors.white, size: 40)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Shop Link Scanner')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste a product page link and see how it scores against '
                'your season palette and closet — before you buy.',
                style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://store.example.com/product/...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _analyze(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : _analyze,
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: SpinKitFadingCircle(color: Colors.white, size: 40)),
              if (_error != null)
                GlassCard(
                  color: Colors.red.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ).animate().fadeIn(),
              if (_result != null) _buildResult(_result!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> data) {
    final imageUrl = data['dress_image_url'] as String?;
    final colorName = data['color_name'] as String? ?? 'Unknown';
    final colorHex = data['color_hex'] as String? ?? '#CCCCCC';
    final synergyScore = data['synergy_score'] as int? ?? 0;
    final combosCount = data['new_combos_count'] as int? ?? 0;
    final gapFillers = (data['gap_fillers'] as List?) ?? [];

    Color parsedColor;
    try {
      parsedColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      parsedColor = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(imageUrl, height: 220, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: parsedColor, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24)),
                  ),
                  const SizedBox(width: 10),
                  Text(colorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Synergy Score: $synergyScore%',
                  style: TextStyle(
                    color: synergyScore >= 60 ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold, fontSize: 16,
                  )),
              const SizedBox(height: 4),
              Text(
                synergyScore >= 60
                    ? 'Great match for your palette.'
                    : 'This may wash you out — consider it carefully.',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text('$combosCount potential outfit pairing(s) in your closet',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (gapFillers.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Gap fillers this would unlock:',
                    style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                for (final g in gapFillers)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• ${g['reason']}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }
}
