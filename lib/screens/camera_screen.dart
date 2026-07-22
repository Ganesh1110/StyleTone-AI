import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

import '../screens/preview_screen.dart';
import '../services/tts_service.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String initialOccasion;

  const CameraScreen({
    super.key,
    required this.cameras,
    this.initialOccasion = 'office',
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  late CameraController _controller;
  bool _isCameraInitialized = false;

  late String _selectedOccasion;
  bool _isProcessing = false;
  bool _isUsingFrontCamera = true;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      enableTracking: false,
      minFaceSize: 0.15,
    ),
  );

  // Voice guidance
  final TtsService _tts = TtsService();
  DateTime _lastGuidanceTime = DateTime.now().subtract(const Duration(seconds: 10));
  bool _voiceGuidanceEnabled = true;

  // White-balance calibration
  bool _calibrationPhase = false;
  double _wbGainR = 1.0;
  double _wbGainG = 1.0;
  double _wbGainB = 1.0;
  bool _isCalibrated = false;

  CameraDescription _getCamera() {
    if (_isUsingFrontCamera) {
      return widget.cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras[0],
      );
    }
    return widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras[0],
    );
  }

  Future<void> _initCamera() async {
    try {
      final camera = _getCamera();
      _controller = CameraController(camera, ResolutionPreset.medium);
      await _controller.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        if (_voiceGuidanceEnabled) {
          _startVoiceGuidance();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedOccasion = widget.initialOccasion;
    _calibrationPhase = true;
    _initCamera();
    _tts.init();
  }

  @override
  void dispose() {
    _controller.stopImageStream();
    _controller.dispose();
    _faceDetector.close();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _switchCamera() async {
    await _controller.stopImageStream();
    await _controller.dispose();
    setState(() {
      _isUsingFrontCamera = !_isUsingFrontCamera;
      _isCameraInitialized = false;
    });
    await _initCamera();
  }

  void _startVoiceGuidance() {
    _controller.startImageStream(_processGuidanceFrame);
  }

  DateTime _lastGuidanceFrame = DateTime.now();

  void _processGuidanceFrame(CameraImage image) {
    if (!_voiceGuidanceEnabled || !mounted) return;

    final now = DateTime.now();
    if (now.difference(_lastGuidanceFrame).inMilliseconds < 2000) return;
    _lastGuidanceFrame = now;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      _faceDetector.processImage(inputImage).then((faces) {
        if (!mounted) return;
        final guidance = _analyzeFaceGuidance(faces, image.width, image.height);
        if (guidance != null && now.difference(_lastGuidanceTime).inSeconds >= 4) {
          _lastGuidanceTime = now;
          _tts.speak(guidance);
        }
      });
    } catch (_) {}
  }

  InputImage? _buildInputImage(CameraImage image) {
    final camera = _getCamera();
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (sensorOrientation == 90) {
      rotation = InputImageRotation.rotation90deg;
    } else if (sensorOrientation == 180) {
      rotation = InputImageRotation.rotation180deg;
    } else if (sensorOrientation == 270) {
      rotation = InputImageRotation.rotation270deg;
    } else {
      rotation = InputImageRotation.rotation0deg;
    }

    final format = InputImageFormat.values.firstWhere(
      (f) => f.name == image.format.raw.toString(),
      orElse: () => InputImageFormat.nv21,
    );

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  String? _analyzeFaceGuidance(List<Face> faces, int width, int height) {
    if (faces.isEmpty) {
      return 'Center your face in the oval.';
    }

    final face = faces.first;
    final rect = face.boundingBox;
    final centerX = rect.center.dx;
    final centerY = rect.center.dy;
    final frameCenterX = width / 2;
    final frameCenterY = height / 2;
    final faceArea = rect.width * rect.height;
    const idealMinArea = 0.08;
    const idealMaxArea = 0.30;
    final frameArea = width * height;
    final areaRatio = faceArea / frameArea;

    final dx = (centerX - frameCenterX).abs() / width;
    final dy = (centerY - frameCenterY).abs() / height;

    if (areaRatio < idealMinArea) {
      return 'Move closer to the camera.';
    }
    if (areaRatio > idealMaxArea) {
      return 'Move slightly farther from the camera.';
    }
    if (dx > 0.12 || dy > 0.12) {
      return 'Center your face in the oval.';
    }
    if (face.smilingProbability != null && face.smilingProbability! < 0.3) {
      return 'A slight smile helps with accurate analysis.';
    }
    return 'Good position. Hold still and tap capture.';
  }

  Future<void> _calibrateWhiteBalance() async {
    try {
      final image = await _controller.takePicture();
      final file = File(image.path);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      final cx = decoded.width ~/ 2;
      final cy = decoded.height ~/ 2;
      int sumR = 0, sumG = 0, sumB = 0, count = 0;

      for (int dy = -10; dy <= 10; dy++) {
        for (int dx = -10; dx <= 10; dx++) {
          final p = decoded.getPixel((cx + dx).clamp(0, decoded.width - 1), (cy + dy).clamp(0, decoded.height - 1));
          sumR += p.r.toInt();
          sumG += p.g.toInt();
          sumB += p.b.toInt();
          count++;
        }
      }

      final avgR = sumR / count;
      final avgG = sumG / count;
      final avgB = sumB / count;

      setState(() {
        _wbGainR = 255.0 / avgR;
        _wbGainG = 255.0 / avgG;
        _wbGainB = 255.0 / avgB;
        _isCalibrated = true;
        _calibrationPhase = false;
      });

      if (_voiceGuidanceEnabled && mounted) {
        _tts.speak('White balance calibrated. You can now take your selfie.');
      }

      file.delete();
    } catch (e) {
      debugPrint('Calibration failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calibration failed. Using default white balance.')),
        );
        setState(() => _calibrationPhase = false);
      }
    }
  }

  img.Image _applyWhiteBalance(img.Image source) {
    if (_wbGainR == 1.0 && _wbGainG == 1.0 && _wbGainB == 1.0) return source;
    final corrected = img.Image(width: source.width, height: source.height);
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final p = source.getPixel(x, y);
        final r = (p.r.toInt() * _wbGainR).clamp(0, 255).toInt();
        final g = (p.g.toInt() * _wbGainG).clamp(0, 255).toInt();
        final b = (p.b.toInt() * _wbGainB).clamp(0, 255).toInt();
        corrected.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return corrected;
  }

  Future<void> _takePictureAndProcess() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _controller.takePicture();
      final File originalFile = File(image.path);

      // Apply white-balance correction if calibrated
      File processedFile;
      if (_isCalibrated) {
        final bytes = await originalFile.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final corrected = _applyWhiteBalance(decoded);
          final tempDir = await getTemporaryDirectory();
          final correctedPath = p.join(tempDir.path, 'wb_corrected.jpg');
          await File(correctedPath).writeAsBytes(img.encodeJpg(corrected, quality: 90));
          processedFile = File(correctedPath);
        } else {
          processedFile = originalFile;
        }
      } else {
        processedFile = originalFile;
      }

      final inputImage = InputImage.fromFile(processedFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      File croppedFile;
      if (faces.isNotEmpty) {
        final face = faces.first;
        final rect = face.boundingBox;

        final bytes = await processedFile.readAsBytes();
        final decodedImage = img.decodeImage(bytes);

        if (decodedImage != null) {
          int x = rect.left.toInt().clamp(0, decodedImage.width - 1);
          int y = rect.top.toInt().clamp(0, decodedImage.height - 1);
          int w = rect.width.toInt().clamp(1, decodedImage.width - x);
          int h = rect.height.toInt().clamp(1, decodedImage.height - y);

          final croppedImg = img.copyCrop(decodedImage, x: x, y: y, width: w, height: h);

          final tempDir = await getTemporaryDirectory();
          final croppedPath = p.join(tempDir.path, 'face_crop.jpg');
          await File(croppedPath).writeAsBytes(img.encodeJpg(croppedImg, quality: 90));
          croppedFile = File(croppedPath);
        } else {
          croppedFile = processedFile;
        }
      } else {
        croppedFile = processedFile;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              imageFile: croppedFile,
              occasion: _selectedOccasion,
              faceDetected: faces.isNotEmpty,
            ),
          ),
        );
      }

      // Clean up temp files
      if (processedFile.path != originalFile.path) {
        originalFile.delete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final File file = File(pickedFile.path);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              imageFile: file,
              occasion: _selectedOccasion,
              faceDetected: true,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('StyleTone AI'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _voiceGuidanceEnabled ? Icons.volume_up : Icons.volume_off,
            ),
            onPressed: () {
              setState(() => _voiceGuidanceEnabled = !_voiceGuidanceEnabled);
              if (_voiceGuidanceEnabled) {
                _tts.speak('Voice guidance enabled.');
                _startVoiceGuidance();
              } else {
                _controller.stopImageStream();
                _tts.stop();
              }
            },
            tooltip: _voiceGuidanceEnabled ? 'Mute guidance' : 'Enable guidance',
          ),
          IconButton(
            icon: Icon(
              _isUsingFrontCamera ? Icons.camera_rear : Icons.camera_front,
            ),
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _pickFromGallery,
            tooltip: 'Pick from Gallery',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isCameraInitialized)
                  CameraPreview(_controller)
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                // Face guide overlay
                Positioned.fill(
                  child: ClipPath(
                    clipper: FaceOverlayClipper(),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                // Oval guide + text
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: MediaQuery.of(context).size.height * 0.45,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(200, 250),
                      ),
                      border: Border.all(
                        color: _calibrationPhase
                            ? Colors.amber.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.8),
                        width: _calibrationPhase ? 3.0 : 2.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _calibrationPhase ? Icons.wb_sunny : Icons.face,
                          size: 48,
                          color: (_calibrationPhase ? Colors.amber : Colors.white)
                              .withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _calibrationPhase
                              ? 'Hold a white/gray object in frame'
                              : 'Position your face here',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                // Processing overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          // Bottom bar
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                // Occasion chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedOccasion.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_calibrationPhase) ...[
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _calibrateWhiteBalance,
                    icon: const Icon(Icons.wb_sunny),
                    label: const Text('Calibrate White Balance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _calibrationPhase = false),
                    child: const Text(
                      'Skip calibration',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ] else ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isCalibrated
                                ? Colors.amber.withValues(alpha: 0.6)
                                : Colors.white,
                            width: _isCalibrated ? 2.5 : 3,
                          ),
                        ),
                      ),
                      FloatingActionButton(
                        onPressed: _isProcessing ? null : _takePictureAndProcess,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepPurple,
                        child: const Icon(Icons.camera_alt, size: 32),
                      ),
                    ],
                  ),
                  if (_isCalibrated)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          const Text(
                            'WB calibrated',
                            style: TextStyle(color: Colors.amber, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FaceOverlayClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ovalPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width * 0.7,
          height: size.height * 0.45,
        ),
      );
    return Path.combine(PathOperation.difference, path, ovalPath);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
