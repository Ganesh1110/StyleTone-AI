import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../services/history_service.dart';
import '../models/color_recommendation.dart';

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final String occasion;
  final ColorRecommendation? preloadedRecommendation;
  final String? preloadedHistoryId;
  final int? preloadedRating;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.occasion,
    this.preloadedRecommendation,
    this.preloadedHistoryId,
    this.preloadedRating,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  ColorRecommendation? _recommendation;
  String _errorMessage = '';
  bool _isLoading = true;
  late final TtsService _tts;
  String? _ttsStatusMessage;
  String? _historyId;
  int _rating = 0;

  // Step-by-step loading states
  final List<String> _loadingSteps = [
    'Analyzing facial features...',
    'Extracting skin undertones...',
    'Determining seasonal palette...',
    'Curating style recommendations...',
    'Finalizing personalized report...',
  ];
  int _currentStepIndex = 0;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _tts = TtsService(onProgressChanged: _onTtsProgress);
    if (widget.preloadedRecommendation != null) {
      _recommendation = widget.preloadedRecommendation;
      _historyId = widget.preloadedHistoryId;
      _rating = widget.preloadedRating ?? 0;
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _speakRecommendation();
      });
    } else {
      _startLoadingTimer();
      _fetchRecommendations();
    }
    _tts.init();
  }

  void _onTtsProgress() {
    if (mounted) {
      setState(() {
        _ttsStatusMessage = _tts.statusMessage;
      });
    }
  }

  void _startLoadingTimer() {
    _currentStepIndex = 0;
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (mounted && _isLoading) {
        setState(() {
          if (_currentStepIndex < _loadingSteps.length - 1) {
            _currentStepIndex++;
          } else {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    _startLoadingTimer();

    try {
      final apiService = ApiService();
      final data = await apiService.getRecommendations(
        imageFile: widget.imageFile,
        occasion: widget.occasion,
      );

      _loadingTimer?.cancel();
      final recommendation = ColorRecommendation.fromJson(data);

      setState(() {
        _recommendation = recommendation;
        _isLoading = false;
      });

      // Save to history cache
      final historyService = HistoryService();
      _historyId = await historyService.saveItem(widget.imageFile, widget.occasion, recommendation);

      _speakRecommendation();
    } catch (e) {
      _loadingTimer?.cancel();
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateRating(int newRating) async {
    if (_historyId == null) return;

    final nextRating = _rating == newRating ? 0 : newRating;

    final historyService = HistoryService();
    await historyService.updateRating(_historyId!, nextRating);

    setState(() {
      _rating = nextRating;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextRating == 1
              ? 'Thanks for the feedback! (Liked)'
              : nextRating == -1
                  ? 'Thanks for the feedback! (Disliked)'
                  : 'Feedback cleared.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _speakRecommendation() async {
    if (_recommendation == null) return;

    if (_tts.isInitialized) {
      final message = _buildSpeechMessage();
      await _tts.speak(message);
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            _tts.onProgressChanged = () {
              setDialogState(() {});
            };

            final progress = _tts.downloadProgress;
            final status = _tts.statusMessage ?? 'Preparing voice...';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.download_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text('Downloading Voice'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress == 0.0 && _tts.isInitializing ? null : progress,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  if (progress > 0.0 && progress < 1.0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    // Start/Await initialization
    await _tts.init();

    // Close progress dialog if it's open
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      // Restore default callback
      _tts.onProgressChanged = _onTtsProgress;
    }

    if (_tts.isInitialized) {
      final message = _buildSpeechMessage();
      await _tts.speak(message);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tts.statusMessage ?? 'Failed to initialize voice')),
        );
      }
    }
  }

  String _buildSpeechMessage() {
    final rec = _recommendation!;
    return 'Analysis complete. ${rec.explanation}';
  }

  // Unique keys for RepaintBoundaries on each tab
  final GlobalKey _officeShareKey = GlobalKey();
  final GlobalKey _partyShareKey = GlobalKey();
  final GlobalKey _casualShareKey = GlobalKey();

  GlobalKey _getShareKey(String occasion) {
    if (occasion == 'office') return _officeShareKey;
    if (occasion == 'party') return _partyShareKey;
    return _casualShareKey;
  }

  Future<void> _sharePalette(ColorRecommendation rec, String occasionKey) async {
    try {
      final boundaryKey = _getShareKey(occasionKey);
      final RenderRepaintBoundary? boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        throw Exception('Could not find paint boundary');
      }

      // Capture image frame
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Could not encode image data');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to cache dir
      final tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final tempFile = File(p.join(tempDir.path, 'style_report_${occasionKey}_$timestamp.png'));
      await tempFile.writeAsBytes(pngBytes);

      // Trigger sharing dialog
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Check out my StyleTone AI ${occasionKey.toUpperCase()} Style Palette!\n'
            'Seasonal category: ${rec.detectedCategory}\n'
            'Explanation: ${rec.explanation}',
      );
    } catch (e) {
      debugPrint('Sharing failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sharing failed: $e')),
        );
      }
    }
  }

  void _showColorDetailsSheet(BuildContext context, String label, String hexCode, String occasion) {
    final color = Color(int.parse(hexCode.replaceFirst('#', '0xFF')));
    final r = color.red;
    final g = color.green;
    final b = color.blue;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$label Color Details',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HEX: ${hexCode.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'RGB: ($r, $g, $b)',
                        style: const TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'How to Style This Shade:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepPurple),
              ),
              const SizedBox(height: 8),
              Text(
                _getStylingTip(occasion, label.toLowerCase()),
                style: const TextStyle(fontSize: 14.5, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Style Report'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_recommendation != null)
            IconButton(
              icon: Icon(
                _tts.isInitialized ? Icons.volume_up : Icons.volume_off,
              ),
              tooltip: _tts.isInitialized
                  ? 'Read aloud'
                  : (_ttsStatusMessage ?? 'Voice loading...'),
              onPressed: _speakRecommendation,
            ),
          if (_tts.isInitializing)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : _buildResultState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpinKitFadingCube(color: Colors.deepPurple, size: 50.0),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: animation.drive(
                    Tween<Offset>(
                      begin: const Offset(0.0, 0.2),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOut)),
                  ),
                  child: child,
                ),
              );
            },
            child: Text(
              _loadingSteps[_currentStepIndex],
              key: ValueKey<int>(_currentStepIndex),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepPurple),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Please wait, this takes ~5 seconds',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Oops! Something went wrong.',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_errorMessage, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchRecommendations,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState() {
    final rec = _recommendation!;

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(rec),
          const SizedBox(height: 24),

          // Occasion Tab Selection Layout
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Office'),
                Tab(text: 'Party'),
                Tab(text: 'Casual'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Occasion Pages
          Expanded(
            child: TabBarView(
              children: [
                _buildOccasionDetails(rec, 'office'),
                _buildOccasionDetails(rec, 'party'),
                _buildOccasionDetails(rec, 'casual'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(ColorRecommendation rec) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Detected: ${rec.detectedCategory}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  value: rec.confidence / 100.0,
                  strokeWidth: 2.5,
                  color: Colors.green,
                  backgroundColor: Colors.green.withOpacity(0.15),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${rec.confidence}% Match',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOccasionDetails(ColorRecommendation rec, String occasionKey) {
    final palette = rec.palettes[occasionKey] ?? rec.palettes['casual']!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Styling Tips Card
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                palette.message,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Palette Header
          const Text(
            'Recommended Swatches (Tap to style)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 16),

          // Swatches row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorSwatch('Primary', palette.primaryColor, occasionKey),
              _buildColorSwatch('Secondary', palette.secondaryColor, occasionKey),
              _buildColorSwatch('Accent', palette.accentColor, occasionKey),
            ],
          ),
          const SizedBox(height: 28),

          // Explainable AI Card wrapped in sharing boundary
          RepaintBoundary(
            key: _getShareKey(occasionKey),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.deepPurple.withOpacity(0.15)),
              ),
              color: Colors.deepPurple.withOpacity(0.01),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'AI Color Analysis',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: Colors.deepPurple, size: 20),
                          onPressed: () => _sharePalette(rec, occasionKey),
                          tooltip: 'Share styling card',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      rec.explanation,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Was this analysis accurate?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _rating == 1
                                    ? Icons.thumb_up_rounded
                                    : Icons.thumb_up_outlined,
                                color: _rating == 1 ? Colors.green : Colors.grey,
                                size: 20,
                              ),
                              onPressed: _historyId == null
                                  ? null
                                  : () => _updateRating(1),
                            ),
                            IconButton(
                              icon: Icon(
                                _rating == -1
                                    ? Icons.thumb_down_rounded
                                    : Icons.thumb_down_outlined,
                                color: _rating == -1 ? Colors.red : Colors.grey,
                                size: 20,
                              ),
                              onPressed: _historyId == null
                                  ? null
                                  : () => _updateRating(-1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(String label, String hexCode, String occasionKey) {
    final parsedColor = Color(int.parse(hexCode.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: () => _showColorDetailsSheet(context, label, hexCode, occasionKey),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: parsedColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ]
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            hexCode.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _getStylingTip(String occasion, String swatchType) {
    if (swatchType == 'primary') {
      switch (occasion) {
        case 'office':
          return 'Keep it professional. Use this primary shade for your main garments like blazers, suits, or structured dresses. Pair with soft neutrals.';
        case 'party':
          return 'Make a statement! This primary color should be the focal point of your outfit—a stunning suit jacket, shirt, or party dress.';
        default:
          return 'Relaxed elegance. Wear this primary color in everyday items like casual t-shirts, polo shirts, or light knit sweaters.';
      }
    } else if (swatchType == 'secondary') {
      switch (occasion) {
        case 'office':
          return 'Complement your outfit. Use this secondary color for under-layers (like shirts or blouses) or accessories (ties, scarves).';
        case 'party':
          return 'Add matching contrast. Rock this color in secondary styling elements like pants, belts, shoes, or statement makeup.';
        default:
          return 'Great for layering. Use this secondary color for layering items, cardigans, light jackets, or chinos.';
      }
    } else {
      switch (occasion) {
        case 'office':
          return 'Keep it subtle. This accent shade is perfect for watch straps, pocket squares, socks, or minimal jewelry accents.';
        case 'party':
          return 'Sparkle and shine! Use this accent shade for eye-catching details—clutches, pocket squares, earrings, high-contrast heels, or ties.';
        default:
          return 'Everyday highlights. Perfect for baseball caps, sneaker trims, canvas bags, or small personal accessories.';
      }
    }
  }
}
