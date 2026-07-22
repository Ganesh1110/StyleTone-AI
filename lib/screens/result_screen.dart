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

import 'package:image/image.dart' as img;
import '../services/api_service.dart';
import '../services/skin_analyzer.dart';
import '../services/tts_service.dart';
import '../services/history_service.dart';
import '../services/profile_service.dart';
import '../services/theme_service.dart';
import '../models/user_profile.dart';
import '../models/color_recommendation.dart';
import '../widgets/glass_card.dart';
import '../widgets/ready_to_wear_blueprint.dart';
import '../theme/theme_constants.dart';
import 'self_analysis_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  ColorRecommendation? _recommendation;
  String _errorMessage = '';
  bool _isLoading = true;
  late final TtsService _tts;
  String? _ttsStatusMessage;
  String? _historyId;
  int _rating = 0;
  late final TabController _tabController;

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
    _tabController = TabController(length: 3, vsync: this);
    _tts = TtsService(onProgressChanged: _onTtsProgress);
    if (widget.preloadedRecommendation != null) {
      _recommendation = widget.preloadedRecommendation;
      _historyId = widget.preloadedHistoryId;
      _rating = widget.preloadedRating ?? 0;
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _speakRecommendation(auto: true);
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
    _tabController.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    _startLoadingTimer();

    // Try offline on-device analysis (no network required)
    final offlineResult = await _tryOfflineAnalysis();
    if (offlineResult != null) {
      _onResult(offlineResult);
      return;
    }

    // Fall back to API
    try {
      final apiService = ApiService();
      final data = await apiService.getRecommendations(
        imageFile: widget.imageFile,
        occasion: widget.occasion,
      );
      _onResult(ColorRecommendation.fromJson(data));
    } catch (e) {
      _loadingTimer?.cancel();
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<ColorRecommendation?> _tryOfflineAnalysis() async {
    try {
      final profile = await ProfileService().getProfile();
      final bytes = await widget.imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final resized = img.copyResize(decoded, width: 400, height: 400);
      final data = await processSelfie(resized, gender: profile.gender);
      if (data == null) return null;
      return ColorRecommendation.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  void _onResult(ColorRecommendation recommendation) {
    _loadingTimer?.cancel();
    setState(() {
      _recommendation = recommendation;
      _isLoading = false;
    });
    HistoryService()
        .saveItem(widget.imageFile, widget.occasion, recommendation)
        .then((id) {
          _historyId = id;
          if (mounted) setState(() {});
        });
    _speakRecommendation(auto: true);
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
          content: Text(
            nextRating == 1
                ? 'Thanks for the feedback! (Liked)'
                : nextRating == -1
                ? 'Thanks for the feedback! (Disliked)'
                : 'Feedback cleared.',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _speakRecommendation({bool auto = false}) async {
    if (_recommendation == null) return;

    final profile = await ProfileService().getProfile();
    if (profile.muteVoiceOutput) return;

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
                  Icon(
                    Icons.download_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text('Downloading Voice'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress == 0.0 && _tts.isInitializing
                        ? null
                        : progress,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
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
          SnackBar(
            content: Text(_tts.statusMessage ?? 'Failed to initialize voice'),
          ),
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

  Future<void> _sharePalette(
    ColorRecommendation rec,
    String occasionKey,
  ) async {
    try {
      final boundaryKey = _getShareKey(occasionKey);
      final RenderRepaintBoundary? boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Could not find paint boundary');
      }

      // Capture image frame
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Could not encode image data');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to cache dir
      final tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final tempFile = File(
        p.join(tempDir.path, 'style_report_${occasionKey}_$timestamp.png'),
      );
      await tempFile.writeAsBytes(pngBytes);

      // Trigger sharing dialog
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text:
            'Check out my StyleTone AI ${occasionKey.toUpperCase()} Style Palette!\n'
            'Seasonal category: ${rec.detectedCategory}\n'
            'Explanation: ${rec.explanation}',
      );
    } catch (e) {
      debugPrint('Sharing failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sharing failed: $e')));
      }
    }
  }

  void _showReadyToWearBlueprint(
    BuildContext context,
    String label,
    String hexCode,
    String occasionKey,
  ) {
    if (_recommendation == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: ReadyToWearBlueprintSheet(
          focusHex: hexCode,
          focusLabel: label,
          rec: _recommendation!,
          initialOccasion: occasionKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Style Report'),
        actions: [
          if (_recommendation != null)
            IconButton(
              icon: const Icon(Icons.palette_rounded),
              tooltip: 'Self-Analysis',
              onPressed: () async {
                final updatedRec = await Navigator.push<ColorRecommendation?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SelfAnalysisScreen(
                      selfieFile: widget.imageFile,
                      recommendation: _recommendation!,
                    ),
                  ),
                );
                if (updatedRec != null && mounted) {
                  setState(() {
                    _recommendation = updatedRec;
                  });
                }
              },
            ),
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
        bottom: _recommendation != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: const [
                  Tab(text: 'Office'),
                  Tab(text: 'Party'),
                  Tab(text: 'Casual'),
                ],
              )
            : null,
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
          SpinKitFadingCube(
            color: Theme.of(context).colorScheme.primary,
            size: 50.0,
          ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Please wait, this takes ~5 seconds',
            style: TextStyle(color: Colors.white60),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState() {
    final rec = _recommendation!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderSection(rec),
        const SizedBox(height: 16),
        _buildThemeSuggestion(rec),
        const SizedBox(height: 16),

        // Occasion Pages
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOccasionDetails(rec, 'office'),
              _buildOccasionDetails(rec, 'party'),
              _buildOccasionDetails(rec, 'casual'),
            ],
          ),
        ),
      ],
    );
  }

  String _extractBaseSeason(String detectedCategory) {
    final lower = detectedCategory.toLowerCase();
    if (lower.contains('spring') ||
        lower.contains('golden') ||
        lower.contains('peach'))
      return 'spring';
    if (lower.contains('summer') ||
        lower.contains('rosy') ||
        lower.contains('pink'))
      return 'summer';
    if (lower.contains('autumn') ||
        lower.contains('bronze') ||
        lower.contains('honey'))
      return 'autumn';
    if (lower.contains('winter') || lower.contains('high-contrast'))
      return 'winter';
    return '';
  }

  Widget _buildThemeSuggestion(ColorRecommendation rec) {
    final season = _extractBaseSeason(rec.detectedCategory);
    if (season.isEmpty) return const SizedBox.shrink();

    final themeId = ThemeConstants.themeForSeason(season);
    if (themeId == null) return const SizedBox.shrink();

    final themeConfig = ThemeConstants.getTheme(themeId);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FutureBuilder<UserProfile>(
      future: ProfileService().getProfile(),
      builder: (context, snapshot) {
        if (snapshot.data?.themeSuggestionDismissed == true) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            margin: EdgeInsets.zero,
            color: themeConfig.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(14),
            border: Border.all(
              color: themeConfig.primary.withValues(alpha: 0.3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [themeConfig.primary, themeConfig.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Try the ${themeConfig.label} theme',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color:
                              theme.textTheme.bodyLarge?.color ?? Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color:
                            theme.textTheme.bodyMedium?.color ?? Colors.white60,
                      ),
                      onPressed: () async {
                        final profile = await ProfileService().getProfile();
                        final updated = profile.copyWith(
                          themeSuggestionDismissed: true,
                        );
                        await ProfileService().saveProfile(updated);
                        setState(() {});
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${season.substring(0, 1).toUpperCase()}${season.substring(1)} — ${themeConfig.description}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color ?? Colors.white60,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      await ThemeService.applyTheme(themeId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${themeConfig.label} theme applied!',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: themeConfig.primary.withValues(
                        alpha: 0.15,
                      ),
                      foregroundColor: themeConfig.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Apply Theme',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection(ColorRecommendation rec) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 250,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            'Detected: ${rec.detectedCategory}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
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
                  backgroundColor: Colors.green.withValues(alpha: 0.15),
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
          GlassCard(
                margin: EdgeInsets.zero,
                color: Colors.white.withValues(alpha: 0.05),
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  palette.message,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1, end: 0, duration: 400.ms),
          const SizedBox(height: 24),

          // Subseason indicator
          if (rec.detectedSubseason != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Text(
                'Sub-season: ${rec.detectedSubseason}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Palette Header
          const Text(
            'Recommended Swatches (Tap to style)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 16),

          // Swatches row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorSwatch('Primary', palette.primaryColor, occasionKey),
              _buildColorSwatch(
                'Secondary',
                palette.secondaryColor,
                occasionKey,
              ),
              _buildColorSwatch('Accent', palette.accentColor, occasionKey),
            ],
          ),
          const SizedBox(height: 28),

          // Explainable AI Card wrapped in sharing boundary
          RepaintBoundary(
                key: _getShareKey(occasionKey),
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  color: Colors.white.withValues(alpha: 0.05),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'AI Color Analysis',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.share_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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
                          color: Colors.white70,
                        ),
                      ),
                      const Divider(height: 32, color: Colors.white24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Was this analysis accurate?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white60,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _rating == 1
                                      ? Icons.thumb_up_rounded
                                      : Icons.thumb_up_outlined,
                                  color: _rating == 1
                                      ? Colors.green
                                      : Colors.grey,
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
                                  color: _rating == -1
                                      ? Colors.red
                                      : Colors.grey,
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
              )
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.1, end: 0, duration: 400.ms),
          const SizedBox(height: 24),

          // Makeup Palette
          if (rec.makeupPalette != null) ...[
            const Text(
              'Makeup Palette',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 12),
            _buildMakeupSection(rec.makeupPalette!),
            const SizedBox(height: 24),
          ],

          // Hair Color Palette
          if (rec.hairColorPalette.isNotEmpty) ...[
            const Text(
              'Recommended Hair Colors',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 12),
            _buildHairColorSection(rec.hairColorPalette),
            const SizedBox(height: 24),
          ],

          // Colors to Avoid
          if (rec.colorsToAvoid.isNotEmpty) ...[
            const Text(
              'Colors to Avoid',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF5252),
              ),
            ),
            const SizedBox(height: 12),
            _buildAvoidColorsSection(rec.colorsToAvoid),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildMakeupSection(MakeupPalette makeup) {
    final categories = [
      ('Lip', makeup.lip, Icons.face_rounded),
      ('Eye', makeup.eye, Icons.visibility_rounded),
      ('Cheek', makeup.cheek, Icons.favorite_rounded),
      ('Nail', makeup.nail, Icons.pan_tool_rounded),
    ];
    return Column(
      children: categories.map((cat) {
        final label = cat.$1;
        final colors = cat.$2;
        final icon = cat.$3;
        if (colors.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white38, size: 16),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ...colors.map(
                (hex) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: hex.toUpperCase(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHairColorSection(List<String> colors) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((hex) {
        final parsedColor = Color(int.parse(hex.replaceFirst('#', '0xFF')));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: parsedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hex.toUpperCase(),
              style: const TextStyle(
                fontSize: 8,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAvoidColorsSection(List<String> colors) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((hex) {
        final parsedColor = Color(int.parse(hex.replaceFirst('#', '0xFF')));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: parsedColor,
                shape: BoxShape.circle,
                border: Border.all(width: 1.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hex.toUpperCase(),
              style: const TextStyle(
                fontSize: 8,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildColorSwatch(String label, String hexCode, String occasionKey) {
    final parsedColor = Color(int.parse(hexCode.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: () =>
          _showReadyToWearBlueprint(context, label, hexCode, occasionKey),
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
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
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
}
