import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/color_recommendation.dart';
import '../services/history_service.dart';

// =============================================================================
// SelfAnalysisScreen — Manual season discovery via pixel color droppers
// =============================================================================

class SelfAnalysisScreen extends StatefulWidget {
  final File selfieFile;
  final ColorRecommendation recommendation;

  const SelfAnalysisScreen({
    key,
    required this.selfieFile,
    required this.recommendation,
  }) : super(key: key);

  @override
  State<SelfAnalysisScreen> createState() => _SelfAnalysisScreenState();
}

class _SelfAnalysisScreenState extends State<SelfAnalysisScreen> {
  img.Image? _decodedImage;
  bool _isDecoding = true;

  // Dropper positions relative to the displayed canvas (0.0 to 1.0 normalized)
  Offset _skinNormalized = const Offset(0.5, 0.6);
  Offset _hairNormalized = const Offset(0.5, 0.2);
  Offset _eyeNormalized = const Offset(0.42, 0.45);

  // Extracted colors
  Color _skinColor = const Color(0xFFE5B595);
  Color _hairColor = const Color(0xFF3D2E25);
  Color _eyeColor = const Color(0xFF4A6B82);

  String _detectedSeason = 'Autumn';
  double _contrastValue = 0.4;
  bool _isWarmSkin = true;

  // Track active dropper selection for highlight
  String _activeDropper = 'skin'; // 'skin' | 'hair' | 'eye'

  // Color drape overlay configurations
  bool _showDrapes = false;
  Color _drapeColor = const Color(0xFFC24A2F); // Default to Terracotta Red
  double _drapeNormalizedY = 0.70; // Vertical drape alignment Y (0.4 to 0.95)

  static const Map<String, List<Map<String, String>>> _seasonalPalettes = {
    'Spring': [
      {'name': 'Coral Pink', 'hex': '#FF6F61'},
      {'name': 'Peach Cream', 'hex': '#FFD3B6'},
      {'name': 'Bright Teal', 'hex': '#00A86B'},
      {'name': 'Golden Yellow', 'hex': '#FFD700'},
      {'name': 'Mint Green', 'hex': '#98FF98'},
      {'name': 'Sky Blue', 'hex': '#87CEEB'},
      {'name': 'Warm Beige', 'hex': '#F5F5DC'},
      {'name': 'Ivory White', 'hex': '#FFFFF0'},
    ],
    'Summer': [
      {'name': 'Soft Lavender', 'hex': '#E6E6FA'},
      {'name': 'Powder Pink', 'hex': '#FFB6C1'},
      {'name': 'Pastel Blue', 'hex': '#AEC6CF'},
      {'name': 'Rose Quartz', 'hex': '#F7CAC9'},
      {'name': 'Slate Gray', 'hex': '#708090'},
      {'name': 'Muted Sage', 'hex': '#8FBC8F'},
      {'name': 'Chiffon White', 'hex': '#F8F8FF'},
      {'name': 'Muted Navy', 'hex': '#4682B4'},
    ],
    'Autumn': [
      {'name': 'Olive Green', 'hex': '#808000'},
      {'name': 'Mustard Yellow', 'hex': '#E4B22F'},
      {'name': 'Terracotta Red', 'hex': '#C24A2F'},
      {'name': 'Burnt Orange', 'hex': '#CC5500'},
      {'name': 'Forest Green', 'hex': '#228B22'},
      {'name': 'Rust Brown', 'hex': '#8B4513'},
      {'name': 'Warm Sand', 'hex': '#D2B48C'},
      {'name': 'Espresso', 'hex': '#4A2E1B'},
    ],
    'Winter': [
      {'name': 'Royal Blue', 'hex': '#4169E1'},
      {'name': 'Vibrant Magenta', 'hex': '#FF007F'},
      {'name': 'Pure White', 'hex': '#FFFFFF'},
      {'name': 'Ice Blue', 'hex': '#D0F0C0'},
      {'name': 'Emerald green', 'hex': '#50C878'},
      {'name': 'Cabernet red', 'hex': '#800020'},
      {'name': 'Silver Metallic', 'hex': '#C0C0C0'},
      {'name': 'Jet Black', 'hex': '#0F0F0F'},
    ],
  };

  static const Map<String, List<Map<String, String>>> _avoidPalettes = {
    'Spring': [
      {'name': 'Dusty Pink', 'hex': '#D4A5A5'},
      {'name': 'Slate Gray', 'hex': '#708090'},
      {'name': 'Mustard', 'hex': '#E4B22F'},
      {'name': 'Dark Olive', 'hex': '#556B2F'},
      {'name': 'Ice Blue', 'hex': '#AFEEEE'},
      {'name': 'Muted Purple', 'hex': '#9B8EAA'},
      {'name': 'Burgundy', 'hex': '#800020'},
    ],
    'Summer': [
      {'name': 'Electric Orange', 'hex': '#FF4500'},
      {'name': 'Mustard', 'hex': '#E4B22F'},
      {'name': 'Coral Red', 'hex': '#FF7F50'},
      {'name': 'Bright Gold', 'hex': '#FFD700'},
      {'name': 'Lime Green', 'hex': '#32CD32'},
      {'name': 'Coffee Brown', 'hex': '#6F4E37'},
      {'name': 'Jet Black', 'hex': '#0A0A0A'},
    ],
    'Autumn': [
      {'name': 'Bubblegum Pink', 'hex': '#FFC0CB'},
      {'name': 'Ice Blue', 'hex': '#AFEEEE'},
      {'name': 'Lilac', 'hex': '#D8BFD8'},
      {'name': 'Gray', 'hex': '#BEBEBE'},
      {'name': 'Jet Black', 'hex': '#0A0A0A'},
      {'name': 'Magenta', 'hex': '#FF00FF'},
      {'name': 'Pure White', 'hex': '#FFFFFF'},
    ],
    'Winter': [
      {'name': 'Mustard', 'hex': '#E4B22F'},
      {'name': 'Golden Brown', 'hex': '#996515'},
      {'name': 'Terracotta', 'hex': '#C24A2F'},
      {'name': 'Coral Orange', 'hex': '#FF7F50'},
      {'name': 'Warm Beige', 'hex': '#F5F5DC'},
      {'name': 'Olive Green', 'hex': '#808000'},
      {'name': 'Peach Cream', 'hex': '#FFD3B6'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _decodeSelfie();
  }

  Future<void> _decodeSelfie() async {
    try {
      final bytes = await widget.selfieFile.readAsBytes();
      final decoded = await compute(_decodeImageBytes, bytes);
      if (decoded != null) {
        setState(() {
          _decodedImage = decoded;
          _isDecoding = false;
        });
        _sampleAllColors();
      }
    } catch (e) {
      debugPrint('Self-analysis image decode failed: $e');
      if (mounted) {
        setState(() => _isDecoding = false);
      }
    }
  }

  void _sampleAllColors({bool updateSeason = true}) {
    if (_decodedImage == null) return;
    setState(() {
      _skinColor = _getColorAtNormalized(_skinNormalized);
      _hairColor = _getColorAtNormalized(_hairNormalized);
      _eyeColor = _getColorAtNormalized(_eyeNormalized);
      if (updateSeason) {
        _updateSeasonProfile();
      }
    });
  }

  Color _getColorAtNormalized(Offset norm) {
    if (_decodedImage == null) return Colors.grey;
    final int x = (norm.dx * _decodedImage!.width)
        .clamp(0, _decodedImage!.width - 1)
        .toInt();
    final int y = (norm.dy * _decodedImage!.height)
        .clamp(0, _decodedImage!.height - 1)
        .toInt();

    final pixel = _decodedImage!.getPixel(x, y);
    final int r = pixel.r.toInt();
    final int g = pixel.g.toInt();
    final int b = pixel.b.toInt();

    return Color.fromARGB(255, r, g, b);
  }

  void _updateSeasonProfile() {
    final hslSkin = HSLColor.fromColor(_skinColor);
    // Golden-yellow and peach tones (warm) typically hue between 15.0 and 55.0
    _isWarmSkin = hslSkin.hue >= 15.0 && hslSkin.hue <= 55.0;

    final skinL = HSLColor.fromColor(_skinColor).lightness;
    final hairL = HSLColor.fromColor(_hairColor).lightness;
    final eyeL = HSLColor.fromColor(_eyeColor).lightness;

    _contrastValue = max((skinL - hairL).abs(), (skinL - eyeL).abs());
    final bool isHighContrast = _contrastValue > 0.28;

    setState(() {
      if (_isWarmSkin) {
        _detectedSeason = isHighContrast ? 'Autumn' : 'Spring';
      } else {
        _detectedSeason = isHighContrast ? 'Winter' : 'Summer';
      }
    });
  }

  bool get _isLightingSuboptimal {
    final hslSkin = HSLColor.fromColor(_skinColor);
    return hslSkin.lightness < 0.22 || hslSkin.lightness > 0.88;
  }

  void _onDropperDragged(String type, Offset delta, Size canvasSize) {
    if (_decodedImage == null) return;

    setState(() {
      _activeDropper = type;
      Offset oldNorm;
      if (type == 'skin')
        oldNorm = _skinNormalized;
      else if (type == 'hair')
        oldNorm = _hairNormalized;
      else
        oldNorm = _eyeNormalized;

      final double dx = oldNorm.dx + (delta.dx / canvasSize.width);
      final double dy = oldNorm.dy + (delta.dy / canvasSize.height);

      final newNorm = Offset(dx.clamp(0.02, 0.98), dy.clamp(0.02, 0.98));

      if (type == 'skin') {
        _skinNormalized = newNorm;
        _skinColor = _getColorAtNormalized(newNorm);
      } else if (type == 'hair') {
        _hairNormalized = newNorm;
        _hairColor = _getColorAtNormalized(newNorm);
      } else {
        _eyeNormalized = newNorm;
        _eyeColor = _getColorAtNormalized(newNorm);
      }

      _updateSeasonProfile();
    });
  }

  // ─── Scaffold & Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF130D2E),
      appBar: AppBar(
        title: const Text('Self-Analysis Palette Picker'),
        backgroundColor: const Color(0xFF130D2E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How to use',
            onPressed: _showUsageInstructions,
          ),
        ],
      ),
      body: _isDecoding
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : Column(
              children: [
                _buildDynamicHeader(),

                // Canvas showing selfie and draggable droppers
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double imgAspect =
                              _decodedImage!.width / _decodedImage!.height;
                          double canvasW = constraints.maxWidth;
                          double canvasH = constraints.maxHeight;

                          if (canvasW / canvasH > imgAspect) {
                            canvasW = canvasH * imgAspect;
                          } else {
                            canvasH = canvasW / imgAspect;
                          }

                          final size = Size(canvasW, canvasH);

                          return Center(
                            child: SizedBox(
                              width: canvasW,
                              height: canvasH,
                              child: Stack(
                                children: [
                                  // Selfie Image (fits canvas exactly)
                                  Positioned.fill(
                                    child: Image.file(
                                      widget.selfieFile,
                                      fit: BoxFit.fill,
                                    ),
                                  ),

                                  // Color Drape Overlay (draggable vertical neck collar)
                                  if (_showDrapes)
                                    Positioned(
                                      top: _drapeNormalizedY * size.height,
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        onVerticalDragUpdate: (details) {
                                          setState(() {
                                            final double deltaY = details.delta.dy / size.height;
                                            _drapeNormalizedY = (_drapeNormalizedY + deltaY).clamp(0.4, 0.95);
                                          });
                                        },
                                        child: ClipPath(
                                          clipper: NeckDrapeClipper(),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  _drapeColor,
                                                  _drapeColor.withOpacity(0.85),
                                                ],
                                              ),
                                            ),
                                            child: Stack(
                                              children: [
                                                // Subtle fine linen texture lines
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: FabricTexturePainter(),
                                                  ),
                                                ),
                                                // Drag handle bar indicator at top center
                                                Align(
                                                  alignment: Alignment.topCenter,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(top: 8.0),
                                                    child: Container(
                                                      width: 36,
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white60,
                                                        borderRadius: BorderRadius.circular(2),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Align(
                                                  alignment: Alignment.bottomCenter,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(bottom: 6.0),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.5),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'Drape: #${_drapeColor.value.toRadixString(16).substring(2).toUpperCase()}',
                                                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Draggable dropper & tooltip based on active user selection (hidden when draping is active)
                                  if (!_showDrapes) ...[
                                    if (_activeDropper == 'skin') ...[
                                      _buildDropper(
                                        type: 'skin',
                                        norm: _skinNormalized,
                                        color: _skinColor,
                                        canvasSize: size,
                                      ),
                                      _buildDropperTooltip(
                                        type: 'skin',
                                        label: 'Skin',
                                        norm: _skinNormalized,
                                        canvasSize: size,
                                      ),
                                    ] else if (_activeDropper == 'hair') ...[
                                      _buildDropper(
                                        type: 'hair',
                                        norm: _hairNormalized,
                                        color: _hairColor,
                                        canvasSize: size,
                                      ),
                                      _buildDropperTooltip(
                                        type: 'hair',
                                        label: 'Hair',
                                        norm: _hairNormalized,
                                        canvasSize: size,
                                      ),
                                    ] else if (_activeDropper == 'eye') ...[
                                      _buildDropper(
                                        type: 'eye',
                                        norm: _eyeNormalized,
                                        color: _eyeColor,
                                        canvasSize: size,
                                      ),
                                      _buildDropperTooltip(
                                        type: 'eye',
                                        label: 'Eye',
                                        norm: _eyeNormalized,
                                        canvasSize: size,
                                      ),
                                    ],
                                  ],

                                  // Suboptimal Lighting Warning Banner
                                  if (_isLightingSuboptimal)
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      right: 70, // leave space for drape toggle
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade900
                                              .withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.amberAccent
                                                .withOpacity(0.4),
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.wb_sunny_rounded,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Lighting Alert: Area is dark or shadowed. Drag Skin dropper to a naturally lit spot.',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Drape Toggle FAB Icon
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: Ink(
                                        decoration: ShapeDecoration(
                                          color: const Color(
                                            0xFF130D2E,
                                          ).withOpacity(0.85),
                                          shape: const CircleBorder(
                                            side: BorderSide(
                                              color: Colors.white24,
                                              width: 0.8,
                                            ),
                                          ),
                                        ),
                                        child: IconButton(
                                          onPressed: () => setState(
                                            () => _showDrapes = !_showDrapes,
                                          ),
                                          icon: const Icon(
                                            Icons.checkroom_rounded,
                                          ),
                                          color: _showDrapes
                                              ? Colors.greenAccent
                                              : Colors.white,
                                          iconSize: 20,
                                          tooltip: 'Toggle Color Drape Overlay',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                _buildColorBar(),
                _buildBottomPalettePanel(),
              ],
            ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildDynamicHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF130D2E),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          const Text(
            'Drag droppers to sample skin, hair, and eye colors from your selfie.',
            style: TextStyle(color: Colors.white54, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _metricBadge(
                label: 'Undertone',
                value: _isWarmSkin ? 'Warm' : 'Cool',
                color: _isWarmSkin ? Colors.amber : Colors.blueAccent,
              ),
              const SizedBox(width: 14),
              _metricBadge(
                label: 'Contrast',
                value: '${(_contrastValue * 100).round()}%',
                color: _contrastValue > 0.28
                    ? Colors.greenAccent
                    : Colors.tealAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Draggable Dropper Widget ─────────────────────────────────────────────

  Widget _buildDropper({
    required String type,
    required Offset norm,
    required Color color,
    required Size canvasSize,
  }) {
    final double left = norm.dx * canvasSize.width;
    final double top = norm.dy * canvasSize.height;
    final bool isActive = _activeDropper == type;

    return Positioned(
      left: left - 28,
      top: top - 28,
      child: GestureDetector(
        onPanUpdate: (details) =>
            _onDropperDragged(type, details.delta, canvasSize),
        onTapDown: (_) => setState(() => _activeDropper = type),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.1),
            border: Border.all(
              color: isActive ? Colors.white : Colors.white60,
              width: isActive ? 2.5 : 1.5,
            ),
          ),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(
                  0.1,
                ), // Semi-transparent overlay to keep the plus readable
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded, // Plus / Crosshair icon for precision picker
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Dropper Tooltip Bubble ───────────────────────────────────────────────

  Widget _buildDropperTooltip({
    required String type,
    required String label,
    required Offset norm,
    required Size canvasSize,
  }) {
    final double left = norm.dx * canvasSize.width;
    final double top = norm.dy * canvasSize.height;
    final bool isActive = _activeDropper == type;

    return Positioned(
      left: left - 30, // center-aligned assuming 60px tooltip width
      top: top - 54, // positioned above the dropper circle
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isActive ? 1.0 : 0.6,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24, width: 0.8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            // Tooltip pointer arrow
            CustomPaint(
              size: const Size(6, 4),
              painter: _TooltipArrowPainter(),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoadPaletteDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _LoadPaletteDialog(
          initialSeason: _detectedSeason,
          onSeasonSelected: (String newSeason) {
            setState(() {
              _detectedSeason = newSeason;
              _isWarmSkin = (newSeason == 'Spring' || newSeason == 'Autumn');
              _contrastValue = (newSeason == 'Autumn' || newSeason == 'Winter')
                  ? 0.42
                  : 0.18;
              _sampleAllColors(updateSeason: false);
            });
          },
        );
      },
    );
  }

  // ─── Extracted Colors Display ─────────────────────────────────────────────

  Widget _buildColorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: const Color(0xFF130D2E).withOpacity(0.4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _colorBadge(
            'Skin',
            _skinColor,
            _activeDropper == 'skin',
            () => setState(() => _activeDropper = 'skin'),
          ),
          _colorBadge(
            'Hair',
            _hairColor,
            _activeDropper == 'hair',
            () => setState(() => _activeDropper = 'hair'),
          ),
          _colorBadge(
            'Eye',
            _eyeColor,
            _activeDropper == 'eye',
            () => setState(() => _activeDropper = 'eye'),
          ),
        ],
      ),
    );
  }

  Widget _colorBadge(
    String label,
    Color color,
    bool active,
    VoidCallback onTap,
  ) {
    final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? Colors.deepPurple.shade300 : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
                Text(
                  hex,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Seasonal Palette Panel ───────────────────────────────────────────────

  Widget _buildBottomPalettePanel() {
    final pal =
        _seasonalPalettes[_detectedSeason] ?? _seasonalPalettes['Autumn']!;
    final avoid = _avoidPalettes[_detectedSeason] ?? _avoidPalettes['Autumn']!;
    final sColor = _seasonColor(_detectedSeason);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF130D2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Calculated Season (InkWell clickable to load palette)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _showLoadPaletteDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calculated Season Profile',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  _skinToneLabel(_detectedSeason),
                                  style: TextStyle(
                                    color: sColor,
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.edit_note_rounded,
                                  color: sColor.withOpacity(0.8),
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Lock Season button
                ElevatedButton.icon(
                  onPressed: _lockManualSelection,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Save Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. BEST COLORS SECTION
            const Text(
              'Best Colors',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pal.length,
                itemBuilder: (context, index) {
                  final item = pal[index];
                  final color = Color(
                    int.parse(item['hex']!.replaceFirst('#', '0xFF')),
                  );

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _drapeColor = color;
                        _showDrapes = true; // Auto-enable drape overlay!
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _drapeColor == color && _showDrapes
                                    ? Colors.greenAccent
                                    : Colors.white24,
                                width: _drapeColor == color && _showDrapes
                                    ? 2.0
                                    : 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['name']!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // 2. COLORS TO AVOID SECTION
            const Text(
              'Colors to Avoid',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: avoid.length,
                itemBuilder: (context, index) {
                  final item = avoid[index];
                  final color = Color(
                    int.parse(item['hex']!.replaceFirst('#', '0xFF')),
                  );

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _drapeColor = color;
                        _showDrapes = true; // Auto-enable drape overlay!
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _drapeColor == color && _showDrapes
                                    ? Colors.greenAccent
                                    : const Color(0xFFFF5252).withOpacity(0.6),
                                width: _drapeColor == color && _showDrapes
                                    ? 2.0
                                    : 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.close_rounded,
                                color: Color(0xFFFF5252),
                                size: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['name']!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Save / Lock Season Callback ──────────────────────────────────────────

  String _skinToneLabel(String season) {
    const labels = {
      'Spring': 'Warm Golden/Peach Skin Tone',
      'Summer': 'Cool Rosy/Pink Skin Tone',
      'Autumn': 'Warm Bronze/Honey Skin Tone',
      'Winter': 'Cool High-Contrast Skin Tone',
    };
    return labels[season] ?? '$season Season';
  }

  Future<void> _lockManualSelection() async {
    final mockRec = ColorRecommendation(
      detectedCategory: _skinToneLabel(_detectedSeason),
      confidence: 100,
      explanation:
          'Determined manually using the Interactive Self-Analysis color picker tool.',
      palettes: {
        'office': OccasionPalette(
          primaryColor: _seasonalPalettes[_detectedSeason]![0]['hex']!,
          secondaryColor: _seasonalPalettes[_detectedSeason]![1]['hex']!,
          accentColor: _seasonalPalettes[_detectedSeason]![2]['hex']!,
          message:
              'Manually calibrated palette coordinates representing your personal undertone.',
        ),
        'party': OccasionPalette(
          primaryColor: _seasonalPalettes[_detectedSeason]![3]['hex']!,
          secondaryColor: _seasonalPalettes[_detectedSeason]![4]['hex']!,
          accentColor: _seasonalPalettes[_detectedSeason]![2]['hex']!,
          message:
              'Manually calibrated palette coordinates representing your personal undertone.',
        ),
        'casual': OccasionPalette(
          primaryColor: _seasonalPalettes[_detectedSeason]![5]['hex']!,
          secondaryColor: _seasonalPalettes[_detectedSeason]![6]['hex']!,
          accentColor: _seasonalPalettes[_detectedSeason]![7]['hex']!,
          message:
              'Manually calibrated palette coordinates representing your personal undertone.',
        ),
      },
    );

    try {
      final historyService = HistoryService();
      await historyService.saveItem(widget.selfieFile, 'casual', mockRec);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Saved manually-calibrated $_detectedSeason profile!',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, mockRec);
      }
    } catch (e) {
      debugPrint('Save manual profile failed: $e');
    }
  }

  void _showUsageInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF130D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'How to Self-Analyze',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Drag the markers directly onto your selfie:\n'
              '   • Face icon 🫱 onto skin (avoid cheeks/shadows)\n'
              '   • Scissors icon 💇 onto hair\n'
              '   • Eye icon 👁️ onto iris/eye color\n',
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            Text(
              '2. Undertone is warm if skin has golden hues, and cool if skin leans pink/blue.\n',
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            Text(
              '3. Contrast is high if there is a major difference between hair/eyes and skin lightness.\n',
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            Text(
              '4. Locking will save this seasonal profile and color palettes to your history cache.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(color: Colors.deepPurpleAccent),
            ),
          ),
        ],
      ),
    );
  }

  static Color _seasonColor(String season) {
    switch (season) {
      case 'Spring':
        return Colors.amber.shade300;
      case 'Summer':
        return Colors.blue.shade300;
      case 'Autumn':
        return Colors.orange.shade400;
      case 'Winter':
        return Colors.deepPurpleAccent.shade100;
      default:
        return Colors.grey;
    }
  }
}

// ─── Custom Painter for Tooltip Pointer ──────────────────────────────────────

class _TooltipArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// =============================================================================
// Load Palette Selection Dialog — 12 sub-seasons selection overlay
// =============================================================================

class _LoadPaletteDialog extends StatefulWidget {
  final String initialSeason;
  final ValueChanged<String> onSeasonSelected;

  const _LoadPaletteDialog({
    required this.initialSeason,
    required this.onSeasonSelected,
  });

  @override
  State<_LoadPaletteDialog> createState() => _LoadPaletteDialogState();
}

class _LoadPaletteDialogState extends State<_LoadPaletteDialog> {
  late String _selectedSubSeason;

  static const List<String> _subSeasons = [
    'Clear Winter',
    'Cool Winter',
    'Deep Winter',
    'Soft Summer',
    'Cool Summer',
    'Light Summer',
    'Clear Spring',
    'Warm Spring',
    'Light Spring',
    'Soft Autumn',
    'Warm Autumn',
    'Deep Autumn',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSubSeason = 'Warm ${_selectedMainSeason(widget.initialSeason)}';
    if (!_subSeasons.contains(_selectedSubSeason)) {
      _selectedSubSeason = _subSeasons.firstWhere(
        (s) => s.contains(widget.initialSeason),
        orElse: () => _subSeasons[0],
      );
    }
  }

  String _selectedMainSeason(String sub) {
    if (sub.contains('Winter')) return 'Winter';
    if (sub.contains('Summer')) return 'Summer';
    if (sub.contains('Spring')) return 'Spring';
    return 'Autumn';
  }

  @override
  Widget build(BuildContext context) {
    final main = _selectedMainSeason(_selectedSubSeason);
    final pal = _SelfAnalysisScreenState._seasonalPalettes[main] ?? [];

    return AlertDialog(
      backgroundColor: const Color(0xFF130D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Load Palette',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a palette to load it into the Self-Analysis Studio.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '12-Season Palettes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            Flexible(
              child: SizedBox(
                height: 280,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _subSeasons.length,
                  itemBuilder: (context, index) {
                    final sub = _subSeasons[index];
                    final isSel = _selectedSubSeason == sub;
                    return InkWell(
                      onTap: () => setState(() => _selectedSubSeason = sub),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSel
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isSel
                                  ? Colors.deepPurpleAccent
                                  : Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              sub,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontWeight: isSel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 24),

            const Text(
              'Palette Preview',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pal.length,
                itemBuilder: (context, index) {
                  final color = Color(
                    int.parse(pal[index]['hex']!.replaceFirst('#', '0xFF')),
                  );
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 30,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              widget.onSeasonSelected(main);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// NeckDrapeClipper — Custom path clipper to outline drape fabric collar under chin
// =============================================================================

class NeckDrapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Starts at top-left
    path.moveTo(0, 0);
    // Curves down to form the collar hollow cutout under the face
    path.quadraticBezierTo(
      size.width / 2,
      size.height * 0.55, // dip in the center for the chin/neck
      size.width,
      0,
    );
    // Line to bottom-right
    path.lineTo(size.width, size.height);
    // Line to bottom-left
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// =============================================================================
// FabricTexturePainter — Custom painter drawing vertical stripes for linen texture
// =============================================================================

class FabricTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;
    // Draw vertical stripes to simulate fine linen texture
    for (double i = 0; i < size.width; i += 6) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Top-level function for background isolate image decoding
img.Image? _decodeImageBytes(Uint8List bytes) {
  return img.decodeImage(bytes);
}
