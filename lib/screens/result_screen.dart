import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../services/history_service.dart';
import '../models/color_recommendation.dart';

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final String occasion;
  final ColorRecommendation? preloadedRecommendation;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.occasion,
    this.preloadedRecommendation,
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
      await historyService.saveItem(widget.imageFile, widget.occasion, recommendation);

      _speakRecommendation();
    } catch (e) {
      _loadingTimer?.cancel();
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
    return 'Analysis complete. ${rec.explanation} '
        'For ${widget.occasion}, we recommend ${rec.detectedCategory} styling.';
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with Category Badge & Confidence Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Detected: ${rec.detectedCategory}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              // Match Confidence Circular Gauge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        value: rec.confidence / 100.0,
                        strokeWidth: 3,
                        color: Colors.green,
                        backgroundColor: Colors.green.withOpacity(0.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${rec.confidence}% Match',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Occasion Context
          Text(
            'For ${widget.occasion.toUpperCase()}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            rec.message,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),

          // Stylist Analysis (Explainable AI)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.deepPurple.withOpacity(0.15)),
            ),
            color: Colors.deepPurple.withOpacity(0.02),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 12),
                  Text(
                    rec.explanation,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Color Swatches
          const Text(
            'Your Recommended Palette',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorSwatch('Primary', rec.primaryColor),
              _buildColorSwatch('Secondary', rec.secondaryColor),
              _buildColorSwatch('Accent', rec.accentColor),
            ],
          ),

          const SizedBox(height: 36),

          // Styling Tips (Mock)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Stylist Tip',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStylingTip(widget.occasion, rec.primaryColor),
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Retake Photo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(String label, String hexCode) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Color(int.parse(hexCode.replaceFirst('#', '0xFF'))),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        ),
        Text(
          hexCode.toUpperCase(),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  String _getStylingTip(String occasion, String primaryColor) {
    switch (occasion) {
      case 'office':
        return 'Keep it professional. Use $primaryColor as your blazer, shirt, or top. Pair it with tailored neutrals like beige, navy, or charcoal trousers.';
      case 'party':
        return 'Make a statement! Let $primaryColor shine on your dress, shirt, or bold accessory. Pair with metallic shoes or a sleek black bottom.';
      case 'casual':
      default:
        return 'Relaxed elegance. Wear $primaryColor as a casual t-shirt, sweater, or shorts. Combine with denim or light linens for a breezy look.';
    }
  }
}
