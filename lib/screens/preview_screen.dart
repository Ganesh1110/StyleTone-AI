import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../screens/result_screen.dart';

class PreviewScreen extends StatefulWidget {
  final File imageFile;
  final String occasion;
  final bool faceDetected;

  const PreviewScreen({
    super.key,
    required this.imageFile,
    required this.occasion,
    this.faceDetected = true,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isChecking = true;
  String _qualityMessage = 'Checking image quality...';
  IconData _qualityIcon = Icons.hourglass_empty;
  Color _qualityColor = Colors.orange;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _checkQuality();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkQuality() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        _updateQuality(false, 'Could not process image', Icons.error_outline, Colors.red);
        return;
      }

      // Dynamically run face detection if not pre-computed (e.g. from gallery pick)
      bool faceDetected = widget.faceDetected;
      if (!faceDetected) {
        final faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: false,
            enableTracking: false,
            minFaceSize: 0.15,
          ),
        );
        try {
          final inputImage = InputImage.fromFile(widget.imageFile);
          final faces = await faceDetector.processImage(inputImage);
          faceDetected = faces.isNotEmpty;
        } catch (e) {
          debugPrint('Dynamic face detection failed: $e');
        } finally {
          await faceDetector.close();
        }
      }

      // Check average brightness
      final sampled = img.copyResize(decoded, width: 50);
      double totalBrightness = 0;
      int pixelCount = 0;

      for (int y = 0; y < sampled.height; y++) {
        for (int x = 0; x < sampled.width; x++) {
          final pixel = sampled.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          totalBrightness += (r * 0.299 + g * 0.587 + b * 0.114);
          pixelCount++;
        }
      }

      final avgBrightness = totalBrightness / pixelCount;

      // Check contrast (simplified)
      double minBright = 255, maxBright = 0;
      for (int y = 0; y < sampled.height; y++) {
        for (int x = 0; x < sampled.width; x++) {
          final pixel = sampled.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          final brightness = r * 0.299 + g * 0.587 + b * 0.114;
          if (brightness < minBright) minBright = brightness;
          if (brightness > maxBright) maxBright = brightness;
        }
      }
      final contrast = maxBright - minBright;

      // Evaluate quality
      if (!faceDetected) {
        _updateQuality(
          false,
          'No face detected — results may be less accurate',
          Icons.warning_amber_rounded,
          Colors.orange,
        );
      } else if (avgBrightness < 40) {
        _updateQuality(false, 'Image is too dark — try better lighting', Icons.brightness_low, Colors.orange);
      } else if (avgBrightness > 220) {
        _updateQuality(false, 'Image is overexposed — reduce brightness', Icons.brightness_high, Colors.orange);
      } else if (contrast < 30) {
        _updateQuality(false, 'Low contrast — try more even lighting', Icons.contrast, Colors.orange);
      } else {
        _updateQuality(true, 'Good lighting and clear face!', Icons.check_circle, Colors.green);
      }
    } catch (e) {
      _updateQuality(true, 'Photo ready for analysis', Icons.check_circle, Colors.green);
    }
  }

  void _updateQuality(bool good, String message, IconData icon, Color color) {
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _qualityMessage = message;
      _qualityIcon = icon;
      _qualityColor = color;
    });
    _animController.forward();
  }

  void _proceedToResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          imageFile: widget.imageFile,
          occasion: widget.occasion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Review Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Image preview
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          // Quality feedback + actions
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quality indicator
                  Row(
                    children: [
                      if (_isChecking)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(_qualityIcon, color: _qualityColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _qualityMessage,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _qualityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Retake'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isChecking ? null : _proceedToResult,
                          icon: const Icon(Icons.check),
                          label: const Text('Analyze'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
