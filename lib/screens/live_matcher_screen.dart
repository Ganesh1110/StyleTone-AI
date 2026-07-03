import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/history_item.dart';
import '../services/database_helper.dart';

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
  final List<String> _seasonsList = ['Spring', 'Summer', 'Autumn', 'Winter'];

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
  final Map<String, List<String>> _fallbackSeasonColors = {
    'Spring': ['#FFD700', '#FFA07A', '#98FB98'], // Gold, Peach, Mint
    'Summer': ['#87CEEB', '#E6E6FA', '#FFB6C1'], // Sky blue, Lavender, Pink
    'Autumn': ['#D2691E', '#E4B22F', '#808000'], // Chocolate, Mustard, Olive
    'Winter': ['#4169E1', '#800080', '#0F0F0F'], // Royal blue, Deep purple, Black
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
      if (history.isNotEmpty) {
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
    if (_isProcessing) return;

    final now = DateTime.now();
    // Throttle processing to 1 frame every 150ms to maintain smooth 60 FPS UI rendering
    if (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inMilliseconds < 150) {
      return;
    }
    _lastProcessedTime = now;

    setState(() {
      _isProcessing = true;
    });

    try {
      final int width = image.width;
      final int height = image.height;
      final int cx = width ~/ 2;
      final int cy = height ~/ 2;

      int r = 255, g = 255, b = 255;

      // Extract colors from center coordinates depending on frame format
      if (image.format.group == ImageFormatGroup.yuv420) {
        // YUV420 (Android default)
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];

        final int yRowStride = yPlane.bytesPerRow;
        final int yPixelStride = yPlane.bytesPerPixel ?? 1;
        final int yIndex = cy * yRowStride + cx * yPixelStride;
        final int yVal = yPlane.bytes[yIndex];

        final int uvRowStride = uPlane.bytesPerRow;
        final int uvPixelStride = uPlane.bytesPerPixel ?? 2;
        final int uvIndex = (cy ~/ 2) * uvRowStride + (cx ~/ 2) * uvPixelStride;

        final int uVal = uPlane.bytes[uvIndex < uPlane.bytes.length ? uvIndex : uPlane.bytes.length - 1];
        final int vVal = vPlane.bytes[uvIndex < vPlane.bytes.length ? uvIndex : vPlane.bytes.length - 1];

        // Standard YUV to RGB formulas
        r = (yVal + 1.402 * (vVal - 128)).round().clamp(0, 255);
        g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).round().clamp(0, 255);
        b = (yVal + 1.772 * (uVal - 128)).round().clamp(0, 255);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        // BGRA8888 (iOS default)
        final plane = image.planes[0];
        final bytes = plane.bytes;
        final int pixelStride = plane.bytesPerPixel ?? 4;
        final int index = cy * plane.bytesPerRow + cx * pixelStride;

        b = bytes[index];
        g = bytes[index + 1];
        r = bytes[index + 2];
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
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
      // Use actual user recommended colors
      final palettes = _latestScan!.recommendation.palettes;
      final casual = palettes['casual'] ?? palettes['office']!;
      activePaletteColors = [casual.primaryColor, casual.secondaryColor, casual.accentColor];
    } else {
      // Use seasonal fallback colors
      activePaletteColors = _fallbackSeasonColors[_selectedSeason] ?? ['#FFFFFF', '#888888', '#000000'];
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
        backgroundColor: Colors.deepPurple,
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
                          color: Colors.black.withOpacity(0.2),
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
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    color: Colors.white.withOpacity(0.96),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Custom season fallback selector if no history exists
                          if (_latestScan == null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Verify Season:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black54)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _selectedSeason,
                                    underline: const SizedBox(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 13),
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
                            const Divider(height: 24),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Profile Season: ${_latestScan!.recommendation.detectedCategory}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.deepPurple),
                                ),
                                const Icon(Icons.verified_user_rounded, color: Colors.deepPurple, size: 18),
                              ],
                            ),
                            const Divider(height: 20),
                          ],

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
                                      color: Colors.black.withOpacity(0.1),
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
                                    const Text('Live Target Color', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 3),
                                    Text(
                                      _colorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(_hexColor.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                                      color: _getScoreColor(score).withOpacity(0.12),
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
                    ),
                  ),
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
