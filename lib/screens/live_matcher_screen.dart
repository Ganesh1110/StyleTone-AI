import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/history_item.dart';
import '../services/database_helper.dart';
import '../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LiveMatcherScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LiveMatcherScreen({super.key, required this.cameras});

  @override
  State<LiveMatcherScreen> createState() => _LiveMatcherScreenState();
}

class _LiveMatcherScreenState extends State<LiveMatcherScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  DateTime? _lastProcessedTime;

  // Live Extracted State
  int _r = 255, _g = 255, _b = 255;
  String _hexColor = '#FFFFFF';
  String _colorName = 'White';

  // Matchmaking State
  HistoryItem? _latestScan;
  String _selectedSeason = 'Autumn'; // Fallback if no scans exist
  String _selectedOccasion = 'casual';
  final List<String> _seasonsList = ['Spring', 'Summer', 'Autumn', 'Winter'];
  final List<String> _occasionList = ['office', 'party', 'casual'];

  // Static color ranges for fast local naming
  final Map<String, List<int>> _colorLibrary = {
    'Crimson Red': [220, 20, 60],
    'Tomato Red': [255, 99, 71],
    'Soft Pink': [255, 182, 193],
    'Hot Pink': [255, 105, 180],
    'Coral Orange': [255, 127, 80],
    'Golden Yellow': [255, 215, 0],
    'Mustard Yellow': [228, 178, 47],
    'Olive Green': [128, 128, 0],
    'Emerald Green': [80, 200, 120],
    'Mint Green': [152, 255, 152],
    'Forest Green': [34, 139, 34],
    'Teal': [0, 128, 128],
    'Sky Blue': [135, 206, 235],
    'Royal Blue': [65, 105, 225],
    'Navy Blue': [0, 0, 128],
    'Lavender Purple': [230, 230, 250],
    'Deep Purple': [128, 0, 128],
    'Indigo': [75, 0, 130],
    'Chocolate Brown': [139, 69, 19],
    'Tan Brown': [210, 180, 140],
    'Beige': [245, 245, 220],
    'Cream White': [255, 253, 240],
    'Pure White': [255, 255, 255],
    'Light Gray': [211, 211, 211],
    'Charcoal Gray': [64, 64, 64],
    'Jet Black': [15, 15, 15],
  };

  // Mock season colors to fallback on if no selfie scans are stored in SQLite
  // Keyed by "Season|occasion" for occasion-aware fallback
  final Map<String, List<String>> _fallbackSeasonColors = {
    'Spring|office': ['#C28E75', '#D6C5A8', '#477876'],
    'Spring|party': ['#FF7F50', '#FFD700', '#008080'],
    'Spring|casual': ['#E9967A', '#F5F5DC', '#20B2AA'],
    'Summer|office': ['#B08B9E', '#708090', '#6A7B83'],
    'Summer|party': ['#DA8A9F', '#9370DB', '#4682B4'],
    'Summer|casual': ['#FFB6C1', '#E6E6FA', '#778899'],
    'Autumn|office': ['#8A5E38', '#556B2F', '#C2A67D'],
    'Autumn|party': ['#E05A47', '#B8860B', '#2E8B57'],
    'Autumn|casual': ['#D2691E', '#8FBC8F', '#F5F5DC'],
    'Winter|office': ['#1F3A60', '#0E5033', '#4A4A4A'],
    'Winter|party': ['#4169E1', '#00A86B', '#C71585'],
    'Winter|casual': ['#4682B4', '#2E8B57', '#E0115F'],
  };

  @override
  void initState() {
    super.initState();
    _loadUserSeasonProfile();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadUserSeasonProfile() async {
    try {
      final history = await DatabaseHelper.instance.fetchAllHistory();
      if (history.isNotEmpty && mounted) {
        setState(() {
          _latestScan = history.first;
          // Sync fallback helper season selector to detected category
          final detected = _latestScan!.recommendation.detectedCategory;
          for (var season in _seasonsList) {
            if (detected.toLowerCase().contains(season.toLowerCase())) {
              _selectedSeason = season;
              break;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load season logs: $e');
    }
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    // Use rear camera for scanning clothes
    final backCamera = widget.cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      // Start stream
      _controller!.startImageStream(_processCameraFrame);
    } catch (e) {
      debugPrint('Camera stream initialization failed: $e');
    }
  }

  void _processCameraFrame(CameraImage image) {
    if (!mounted) return;
    if (_isProcessing) return;

    final now = DateTime.now();
    // Throttle processing to 1 frame every 150ms to maintain smooth 60 FPS UI rendering
    if (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inMilliseconds < 150) {
      return;
    }
    _lastProcessedTime = now;

    _isProcessing = true;

    try {
      final int width = image.width;
      final int height = image.height;
      final int cx = width ~/ 2;
      final int cy = height ~/ 2;

      int r = 255, g = 255, b = 255;
      int sumR = 0, sumG = 0, sumB = 0;
      int count = 0;
      const int halfGrid = 4; // 9x9 grid around the center pixel

      // Extract colors from center coordinates depending on frame format
      if (image.format.group == ImageFormatGroup.yuv420) {
        // YUV420 (Android default)
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];

        final int yRowStride = yPlane.bytesPerRow;
        final int yPixelStride = yPlane.bytesPerPixel ?? 1;
        final int uvRowStride = uPlane.bytesPerRow;
        final int uvPixelStride = uPlane.bytesPerPixel ?? 2;

        for (int dy = -halfGrid; dy <= halfGrid; dy++) {
          final int py = (cy + dy).clamp(0, height - 1);
          for (int dx = -halfGrid; dx <= halfGrid; dx++) {
            final int px = (cx + dx).clamp(0, width - 1);

            final int yIndex = py * yRowStride + px * yPixelStride;
            if (yIndex >= yPlane.bytes.length) continue;
            final int yVal = yPlane.bytes[yIndex];

            final int uvIndex = (py ~/ 2) * uvRowStride + (px ~/ 2) * uvPixelStride;
            if (uvIndex >= uPlane.bytes.length || uvIndex >= vPlane.bytes.length) continue;
            final int uVal = uPlane.bytes[uvIndex];
            final int vVal = vPlane.bytes[uvIndex];

            // Standard YUV to RGB conversion formula
            final double rVal = yVal + 1.402 * (vVal - 128);
            final double gVal = yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128);
            final double bVal = yVal + 1.772 * (uVal - 128);

            sumR += rVal.round().clamp(0, 255);
            sumG += gVal.round().clamp(0, 255);
            sumB += bVal.round().clamp(0, 255);
            count++;
          }
        }

        if (count > 0) {
          r = sumR ~/ count;
          g = sumG ~/ count;
          b = sumB ~/ count;
        }
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        // BGRA8888 (iOS default)
        final plane = image.planes[0];
        final bytes = plane.bytes;
        final int pixelStride = plane.bytesPerPixel ?? 4;
        final int rowStride = plane.bytesPerRow;

        for (int dy = -halfGrid; dy <= halfGrid; dy++) {
          final int py = (cy + dy).clamp(0, height - 1);
          for (int dx = -halfGrid; dx <= halfGrid; dx++) {
            final int px = (cx + dx).clamp(0, width - 1);

            final int index = py * rowStride + px * pixelStride;
            if (index + 2 >= bytes.length) continue;

            sumB += bytes[index];
            sumG += bytes[index + 1];
            sumR += bytes[index + 2];
            count++;
          }
        }

        if (count > 0) {
          r = sumR ~/ count;
          g = sumG ~/ count;
          b = sumB ~/ count;
        }
      }

      final String hexStr = '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
      final String colorLabel = _getColorLabel(r, g, b);

      if (mounted) {
        setState(() {
          _r = r;
          _g = g;
          _b = b;
          _hexColor = hexStr;
          _colorName = colorLabel;
        });
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  String _getColorLabel(int r, int g, int b) {
    String closestName = 'Unknown Color';
    double minDistance = double.infinity;

    _colorLibrary.forEach((name, rgb) {
      final double dist = ((r - rgb[0]) * (r - rgb[0]) +
                           (g - rgb[1]) * (g - rgb[1]) +
                           (b - rgb[2]) * (b - rgb[2])).toDouble();
      if (dist < minDistance) {
        minDistance = dist;
        closestName = name;
      }
    });
    return closestName;
  }

  double _getColorDistance(String hex1, String hex2) {
    try {
      final r1 = int.parse(hex1.substring(1, 3), radix: 16);
      final g1 = int.parse(hex1.substring(3, 5), radix: 16);
      final b1 = int.parse(hex1.substring(5, 7), radix: 16);

      final r2 = int.parse(hex2.substring(1, 3), radix: 16);
      final g2 = int.parse(hex2.substring(3, 5), radix: 16);
      final b2 = int.parse(hex2.substring(5, 7), radix: 16);

      return ((r1 - r2) * (r1 - r2) + (g1 - g2) * (g1 - g2) + (b1 - b2) * (b1 - b2)).toDouble();
    } catch (e) {
      return 195075.0;
    }
  }

  Map<String, dynamic> _matchAgainstSeason() {
    List<String> activePaletteColors = [];

    if (_latestScan != null) {
      // Use actual user recommended colors for the selected occasion
      final palettes = _latestScan!.recommendation.palettes;
      final occasionPalette = palettes[_selectedOccasion] ?? palettes['casual'] ?? palettes['office']!;
      activePaletteColors = [occasionPalette.primaryColor, occasionPalette.secondaryColor, occasionPalette.accentColor];
    } else {
      // Use occasion-aware seasonal fallback colors
      final key = '$_selectedSeason|$_selectedOccasion';
      activePaletteColors = _fallbackSeasonColors[key] ?? ['#FFFFFF', '#888888', '#000000'];
    }

    // Calculate match percentage against the closest palette color
    double minDistance = double.infinity;
    String matchedTargetHex = '#FFFFFF';

    for (var targetHex in activePaletteColors) {
      final dist = _getColorDistance(_hexColor, targetHex);
      if (dist < minDistance) {
        minDistance = dist;
        matchedTargetHex = targetHex;
      }
    }

    // Scale distance squared (max is 195075) to a match percentage score
    final int score = (100.0 - (minDistance / 1400.0)).clamp(0, 100).round();

    return {
      'score': score,
      'target_hex': matchedTargetHex,
    };
  }

  @override
  Widget build(BuildContext context) {
    final matchResult = _matchAgainstSeason();
    final int score = matchResult['score'] as int;

    final Color liveColor = Color.fromARGB(255, _r, _g, _b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Color Matcher'),
        foregroundColor: Colors.white,
      ),
      body: !_isCameraInitialized
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : Stack(
              children: [
                // 1. Camera Viewfinder Preview
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                ),

                // 2. Reticle Dotted Circular Overlay Target
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Info Panel overlay at the bottom
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: GlassCard(
                    color: Colors.white.withValues(alpha: 0.05),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Custom season fallback selector if no history exists
                        if (_latestScan == null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Verify Season:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white70)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedSeason,
                                  underline: const SizedBox(),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 13),
                                  dropdownColor: Theme.of(context).colorScheme.surface,
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedSeason = newValue;
                                      });
                                    }
                                  },
                                  items: _seasonsList.map((String season) {
                                    return DropdownMenuItem<String>(
                                      value: season,
                                      child: Text(season),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Colors.white24),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Profile Season: ${_latestScan!.recommendation.detectedCategory}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Theme.of(context).colorScheme.primary),
                              ),
                              Icon(Icons.verified_user_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                            ],
                          ),
                          const Divider(height: 20, color: Colors.white24),
                        ],

                        // Occasion toggle chips
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _occasionList.map((occ) {
                            final selected = _selectedOccasion == occ;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedOccasion = occ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Text(
                                    occ.toUpperCase(),
                                    style: TextStyle(
                                      color: selected ? Colors.white : Colors.white54,
                                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),

                        // Live and Match Indicators
                        Row(
                          children: [
                            // Live Circle Color Box
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: liveColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Live Target Color', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  Text(
                                    _colorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                  ),
                                  Text(_hexColor.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),

                            // Match Score Badge
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getScoreColor(score).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '$score% Match',
                                    style: TextStyle(
                                      color: _getScoreColor(score),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _getMatchAdvice(score),
                                  style: TextStyle(
                                    color: _getScoreColor(score),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                ),
              ],
            ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 82) return Colors.green;
    if (score >= 68) return Colors.orange;
    return Colors.red;
  }

  String _getMatchAdvice(int score) {
    if (score >= 82) return 'Perfect Match! 🌟';
    if (score >= 68) return 'Good Tone';
    return 'Avoid Color';
  }
}
