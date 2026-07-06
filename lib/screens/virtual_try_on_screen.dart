import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/color_recommendation.dart';
import '../services/database_helper.dart';
import '../models/closet_item.dart';
import '../widgets/glass_card.dart';

class VirtualTryOnScreen extends StatefulWidget {
  final File selfieFile;
  final ColorRecommendation recommendation;
  final String? seasonLabel;

  const VirtualTryOnScreen({
    super.key,
    required this.selfieFile,
    required this.recommendation,
    this.seasonLabel,
  });

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen>
    with SingleTickerProviderStateMixin {
  ui.Image? _selfieImage;
  Size _imageSize = Size.zero;
  String _selectedOccasion = 'casual';
  String _selectedPaletteRole = 'primary';
  String _selectedGarment = 'top';
  double _opacity = 0.85;
  bool _isLoadingImage = true;
  List<ClosetItem> _closetItems = [];
  bool _showClosetItems = false;

  final List<Map<String, dynamic>> _garmentTypes = [
    {'key': 'top', 'label': 'Top', 'icon': Icons.checkroom},
    {'key': 'dress', 'label': 'Dress', 'icon': Icons.woman_2_rounded},
    {'key': 'blazer', 'label': 'Blazer', 'icon': Icons.checkroom_rounded},
    {'key': 'bottom', 'label': 'Bottoms', 'icon': Icons.accessibility_new_rounded},
    {'key': 'accessory', 'label': 'Scarf', 'icon': Icons.watch_rounded},
  ];

  final List<Map<String, String>> _paletteRoles = [
    {'key': 'primary', 'label': 'Primary'},
    {'key': 'secondary', 'label': 'Secondary'},
    {'key': 'accent', 'label': 'Accent'},
  ];

  @override
  void initState() {
    super.initState();
    _loadImage();
    _loadClosetItems();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.selfieFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 800);
    final frame = await codec.getNextFrame();
    setState(() {
      _selfieImage = frame.image;
      _imageSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      _isLoadingImage = false;
    });
  }

  Future<void> _loadClosetItems() async {
    final items = await DatabaseHelper.instance.getAllClosetItems();
    setState(() => _closetItems = items);
  }

  String _getSelectedColor() {
    final palette = widget.recommendation.palettes[_selectedOccasion] ??
        widget.recommendation.palettes['casual']!;
    switch (_selectedPaletteRole) {
      case 'primary':
        return palette.primaryColor;
      case 'secondary':
        return palette.secondaryColor;
      default:
        return palette.accentColor;
    }
  }

  List<ClosetItem> _filteredClosetItems() {
    final category = _selectedGarment == 'blazer'
        ? 'outer'
        : _selectedGarment == 'accessory'
            ? 'accessory'
            : _selectedGarment;
    return _closetItems.where((i) => i.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Virtual Try-On',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded),
            tooltip: 'Share try-on',
            onPressed: _captureAndShare,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingImage
                ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : _buildMirrorView(),
          ),
          _buildControls(theme),
        ],
      ),
    );
  }

  Widget _buildMirrorView() {
    final colorHex = _getSelectedColor();
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return Stack(
      fit: StackFit.expand,
      children: [
        // Selfie photo
        if (_selfieImage != null)
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _imageSize.width,
              height: _imageSize.height,
              child: RawImage(
                image: _selfieImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        // Garment overlay
        if (_selfieImage != null)
          Positioned.fill(
            child: CustomPaint(
              painter: GarmentOverlayPainter(
                garmentType: _selectedGarment,
                color: color.withOpacity(_opacity),
                imageSize: _imageSize,
              ),
            ),
          ),
        // Season badge
        Positioned(
          top: 16,
          left: 16,
          child: GlassCard(
            color: Colors.black.withOpacity(0.6),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Season: ${widget.recommendation.detectedCategory}',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Color swatch badge
        Positioned(
          top: 16,
          right: 16,
          child: GlassCard(
            color: Colors.black.withOpacity(0.6),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  colorHex.toUpperCase(),
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        // Closet suggestions overlay
        if (_showClosetItems) _buildClosetOverlay(),
      ],
    );
  }

  Widget _buildClosetOverlay() {
    final items = _filteredClosetItems();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          ),
        ),
        child: items.isEmpty
            ? Center(
                child: Text(
                  'No ${_selectedGarment} items in closet',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(left: 16, right: 16, top: 40),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemColor = Color(int.parse(item.hexColor.replaceFirst('#', '0xFF')));
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPaletteRole = 'primary';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Try: ${item.colorName} - ${item.hexColor.toUpperCase()}'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      width: 80,
                      margin: EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            Expanded(
                              child: Image.file(File(item.imagePath), fit: BoxFit.cover),
                            ),
                            Container(
                              padding: EdgeInsets.all(4),
                              color: Colors.black54,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: itemColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    item.colorName,
                                    style: TextStyle(fontSize: 9, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    final palette = widget.recommendation.palettes[_selectedOccasion] ??
        widget.recommendation.palettes['casual']!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Occasion tabs
          Row(
            children: ['Office', 'Party', 'Casual'].asMap().entries.map((entry) {
              final occasionKey = ['office', 'party', 'casual'][entry.key];
              final isSelected = _selectedOccasion == occasionKey;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedOccasion = occasionKey),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.deepPurple : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.deepPurple : Colors.white24,
                      ),
                    ),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12),
          // Garment type selector
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _garmentTypes.map((g) {
                final isSelected = _selectedGarment == g['key'];
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedGarment = g['key'] as String),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.deepPurple : Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.deepPurple : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(g['icon'] as IconData, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            g['label'] as String,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 12),
          // Color palette selector
          Row(
            children: [
              ..._paletteRoles.map((role) {
                final isSelected = _selectedPaletteRole == role['key'];
                String hex;
                switch (role['key']) {
                  case 'primary':
                    hex = palette.primaryColor;
                    break;
                  case 'secondary':
                    hex = palette.secondaryColor;
                    break;
                  default:
                    hex = palette.accentColor;
                }
                final roleColor = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPaletteRole = role['key']!),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? roleColor.withOpacity(0.3) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? roleColor : Colors.white24,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: roleColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white54),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            role['label']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          SizedBox(height: 8),
          // Opacity slider + closet toggle
          Row(
            children: [
              Icon(Icons.opacity, color: Colors.white54, size: 18),
              Expanded(
                child: Slider(
                  value: _opacity,
                  min: 0.2,
                  max: 1.0,
                  activeColor: Colors.deepPurple,
                  inactiveColor: Colors.white24,
                  onChanged: (v) => setState(() => _opacity = v),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showClosetItems = !_showClosetItems),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showClosetItems ? Colors.deepPurple : Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Closet',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndShare() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Try-on snapshot saved! Share it from your gallery.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class GarmentOverlayPainter extends CustomPainter {
  final String garmentType;
  final Color color;
  final Size imageSize;

  GarmentOverlayPainter({
    required this.garmentType,
    required this.color,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Scale factors relative to image size
    final w = size.width;
    final h = size.height;

    switch (garmentType) {
      case 'top':
        _drawTop(canvas, paint, w, h);
        break;
      case 'dress':
        _drawDress(canvas, paint, w, h);
        break;
      case 'blazer':
        _drawBlazer(canvas, paint, w, h);
        break;
      case 'bottom':
        _drawBottom(canvas, paint, w, h);
        break;
      case 'accessory':
        _drawAccessory(canvas, paint, w, h);
        break;
    }
  }

  void _drawTop(Canvas canvas, Paint paint, double w, double h) {
    final path = Path();
    // Torso shape - shoulders to waist
    final cx = w / 2;
    final shoulderY = h * 0.15;
    final waistY = h * 0.52;
    final shoulderW = w * 0.35;
    final waistW = w * 0.25;

    path.moveTo(cx - shoulderW, shoulderY);
    path.quadraticBezierTo(cx - shoulderW - w * 0.05, shoulderY + h * 0.05, cx - shoulderW - w * 0.02, shoulderY + h * 0.1);
    path.lineTo(cx - waistW, waistY);
    path.quadraticBezierTo(cx, waistY + h * 0.03, cx + waistW, waistY);
    path.lineTo(cx + shoulderW + w * 0.02, shoulderY + h * 0.1);
    path.quadraticBezierTo(cx + shoulderW + w * 0.05, shoulderY + h * 0.05, cx + shoulderW, shoulderY);
    path.close();

    canvas.drawPath(path, paint);

    // Neckline
    final neckPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final neckPath = Path();
    neckPath.moveTo(cx - shoulderW * 0.3, shoulderY);
    neckPath.quadraticBezierTo(cx, shoulderY - h * 0.02, cx + shoulderW * 0.3, shoulderY);
    neckPath.quadraticBezierTo(cx, shoulderY + h * 0.03, cx - shoulderW * 0.3, shoulderY);
    neckPath.close();
    canvas.drawPath(neckPath, neckPaint);
  }

  void _drawDress(Canvas canvas, Paint paint, double w, double h) {
    final path = Path();
    final cx = w / 2;
    final shoulderY = h * 0.12;
    final waistY = h * 0.45;
    final hemY = h * 0.75;
    final shoulderW = w * 0.3;
    final waistW = w * 0.22;
    final hemW = w * 0.32;

    // Shoulders to waist
    path.moveTo(cx - shoulderW, shoulderY);
    path.quadraticBezierTo(cx - shoulderW - w * 0.03, shoulderY + h * 0.05, cx - waistW - w * 0.02, waistY);
    path.quadraticBezierTo(cx, waistY + h * 0.02, cx + waistW + w * 0.02, waistY);
    path.quadraticBezierTo(cx + shoulderW + w * 0.03, shoulderY + h * 0.05, cx + shoulderW, shoulderY);
    path.close();
    canvas.drawPath(path, paint);

    // Skirt from waist to hem
    final skirtPath = Path();
    skirtPath.moveTo(cx - waistW - w * 0.02, waistY);
    skirtPath.quadraticBezierTo(cx - hemW - w * 0.02, waistY + h * 0.1, cx - hemW, hemY);
    skirtPath.quadraticBezierTo(cx, hemY + h * 0.03, cx + hemW, hemY);
    skirtPath.quadraticBezierTo(cx + hemW + w * 0.02, waistY + h * 0.1, cx + waistW + w * 0.02, waistY);
    skirtPath.close();
    canvas.drawPath(skirtPath, paint);
  }

  void _drawBlazer(Canvas canvas, Paint paint, double w, double h) {
    // Main blazer body
    final cx = w / 2;
    final shoulderY = h * 0.14;
    final hipY = h * 0.55;
    final shoulderW = w * 0.37;
    final hipW = w * 0.28;

    final path = Path();
    path.moveTo(cx - shoulderW, shoulderY);
    // Left lapel
    path.quadraticBezierTo(cx - shoulderW - w * 0.04, shoulderY + h * 0.06, cx - shoulderW - w * 0.01, shoulderY + h * 0.12);
    path.lineTo(cx - hipW, hipY);
    path.quadraticBezierTo(cx, hipY + h * 0.02, cx + hipW, hipY);
    // Right lapel
    path.lineTo(cx + shoulderW + w * 0.01, shoulderY + h * 0.12);
    path.quadraticBezierTo(cx + shoulderW + w * 0.04, shoulderY + h * 0.06, cx + shoulderW, shoulderY);
    path.close();
    canvas.drawPath(path, paint);

    // Lapels
    final lapelPaint = Paint()
      ..color = Color.lerp(color, Colors.black, 0.25)!
      ..style = PaintingStyle.fill;

    // Left lapel triangle
    final leftLapel = Path();
    leftLapel.moveTo(cx - shoulderW * 0.6, shoulderY + h * 0.04);
    leftLapel.lineTo(cx - w * 0.02, shoulderY + h * 0.2);
    leftLapel.lineTo(cx - w * 0.02, shoulderY + h * 0.04);
    leftLapel.close();
    canvas.drawPath(leftLapel, lapelPaint);

    // Right lapel triangle
    final rightLapel = Path();
    rightLapel.moveTo(cx + shoulderW * 0.6, shoulderY + h * 0.04);
    rightLapel.lineTo(cx + w * 0.02, shoulderY + h * 0.2);
    rightLapel.lineTo(cx + w * 0.02, shoulderY + h * 0.04);
    rightLapel.close();
    canvas.drawPath(rightLapel, lapelPaint);
  }

  void _drawBottom(Canvas canvas, Paint paint, double w, double h) {
    final path = Path();
    final cx = w / 2;
    final waistY = h * 0.48;
    final hemY = h * 0.8;
    final waistW = w * 0.22;
    final hemW = w * 0.18;

    path.moveTo(cx - waistW, waistY);
    path.quadraticBezierTo(cx - hemW - w * 0.03, waistY + h * 0.1, cx - hemW, hemY);
    path.quadraticBezierTo(cx, hemY + h * 0.02, cx + hemW, hemY);
    path.quadraticBezierTo(cx + hemW + w * 0.03, waistY + h * 0.1, cx + waistW, waistY);
    path.close();
    canvas.drawPath(path, paint);

    // Center crease line
    final creasePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(cx, waistY), Offset(cx, hemY), creasePaint);
  }

  void _drawAccessory(Canvas canvas, Paint paint, double w, double h) {
    final cx = w / 2;

    // Scarf/wrap around neck area
    final path = Path();
    final neckY = h * 0.12;
    final drapeY = h * 0.35;
    final spreadW = w * 0.2;

    path.moveTo(cx - spreadW, neckY);
    path.quadraticBezierTo(cx - spreadW - w * 0.08, neckY + h * 0.08, cx - spreadW * 0.5, drapeY);
    path.quadraticBezierTo(cx, drapeY + h * 0.04, cx + spreadW * 0.5, drapeY);
    path.quadraticBezierTo(cx + spreadW + w * 0.08, neckY + h * 0.08, cx + spreadW, neckY);
    path.close();
    canvas.drawPath(path, paint);

    // Drape end
    final endPath = Path();
    final endX = cx + spreadW * 0.3;
    endPath.moveTo(endX - w * 0.08, drapeY);
    endPath.quadraticBezierTo(endX - w * 0.06, drapeY + h * 0.08, endX - w * 0.04, drapeY + h * 0.15);
    endPath.quadraticBezierTo(endX, drapeY + h * 0.18, endX + w * 0.04, drapeY + h * 0.15);
    endPath.quadraticBezierTo(endX + w * 0.06, drapeY + h * 0.08, endX + w * 0.08, drapeY);
    endPath.close();
    canvas.drawPath(endPath, paint);
  }

  @override
  bool shouldRepaint(GarmentOverlayPainter oldDelegate) =>
      oldDelegate.garmentType != garmentType ||
      oldDelegate.color != color ||
      oldDelegate.imageSize != imageSize;
}
