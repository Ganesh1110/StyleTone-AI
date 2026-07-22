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
  final _batchController = TextEditingController();
  final _api = ApiService();

  bool _batchMode = false;
  bool _loading = false;
  bool _isLoadingData = true;
  String? _error;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>>? _batchResults;
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
    _batchController.dispose();
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

  Future<void> _batchAnalyze() async {
    final raw = _batchController.text.trim();
    if (raw.isEmpty) return;

    final urls = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.startsWith('http'))
        .toList();

    if (urls.isEmpty) {
      setState(() => _error = 'Paste at least one valid URL (starting with http).');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _batchResults = null;
    });

    try {
      final result = await _api.batchAnalyzeDressUrls(
        urls: urls,
        activeSeason: _activeSeason,
        closetItems: _closetItems,
      );
      final results = (result['results'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      setState(() => _batchResults = results);
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
      appBar: AppBar(
        title: const Text('Shop Link Scanner'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _batchMode = !_batchMode;
              _error = null;
              _result = null;
              _batchResults = null;
            }),
            child: Text(_batchMode ? 'Single Scan' : 'Batch Scan',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _batchMode
                    ? 'Paste multiple product links (one per line) to see them ranked by synergy score.'
                    : 'Paste a product page link and see how it scores against '
                        'your season palette and closet — before you buy.',
                style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (_batchMode)
                _buildBatchInput()
              else
                _buildSingleInput(),
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
              if (_batchResults != null) _buildBatchResults(_batchResults!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleInput() {
    return Row(
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
    );
  }

  Widget _buildBatchInput() {
    return Column(
      children: [
        TextField(
          controller: _batchController,
          style: const TextStyle(color: Colors.white),
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'https://store1.com/product/...\nhttps://store2.com/product/...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _batchAnalyze,
            icon: const Icon(Icons.sort),
            label: const Text('Score & Rank All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.withValues(alpha: 0.85),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchResults(List<Map<String, dynamic>> results) {
    final successCount = results.where((r) => r['error'] == null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$successCount / ${results.length} products scored',
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 12),
        ...results.asMap().entries.map((entry) {
          final i = entry.key;
          final data = entry.value;
          final error = data['error'] as String?;
          return Padding(
            padding: EdgeInsets.only(top: i > 0 ? 12 : 0),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              color: error != null
                  ? Colors.red.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.05),
              child: _buildBatchRow(data, error, i + 1),
            ).animate().fadeIn(duration: 300.ms, delay: (i * 100).ms),
          );
        }),
      ],
    );
  }

  Widget _buildBatchRow(Map<String, dynamic> data, String? error, int rank) {
    final url = data['url'] as String? ?? '';
    final score = data['synergy_score'] as int? ?? 0;
    final colorHex = data['color_hex'] as String? ?? '#CCCCCC';
    final colorName = data['color_name'] as String? ?? '';

    Color parsedColor;
    try {
      parsedColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      parsedColor = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24, height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: error != null ? Colors.red.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('#$rank',
                  style: TextStyle(
                    color: error != null ? Colors.red : Colors.amber,
                    fontWeight: FontWeight.bold, fontSize: 11,
                  )),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: parsedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                colorName.isNotEmpty ? colorName : _truncateUrl(url),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (error == null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: score >= 60 ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$score%',
                    style: TextStyle(
                      color: score >= 60 ? Colors.greenAccent : Colors.orangeAccent,
                      fontWeight: FontWeight.bold, fontSize: 13,
                    )),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
        ],
        if (error == null && url.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(url, style: const TextStyle(color: Colors.white38, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }

  String _truncateUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.host}${uri.path.length > 30 ? '...' : uri.path}';
    } catch (_) {
      return url.length > 40 ? '${url.substring(0, 40)}...' : url;
    }
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
