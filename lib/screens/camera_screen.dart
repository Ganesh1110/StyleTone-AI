import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

import '../screens/preview_screen.dart';

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

class _CameraScreenState extends State<CameraScreen> {
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
    _initCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _switchCamera() async {
    setState(() {
      _isUsingFrontCamera = !_isUsingFrontCamera;
      _isCameraInitialized = false;
    });
    await _controller.dispose();
    await _initCamera();
  }

  Future<void> _takePictureAndProcess() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _controller.takePicture();
      final File originalFile = File(image.path);

      final inputImage = InputImage.fromFile(originalFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      File croppedFile;

      if (faces.isNotEmpty) {
        final face = faces.first;
        final rect = face.boundingBox;

        final bytes = await originalFile.readAsBytes();
        final decodedImage = img.decodeImage(bytes);

        if (decodedImage != null) {
          int x = rect.left.toInt().clamp(0, decodedImage.width - 1);
          int y = rect.top.toInt().clamp(0, decodedImage.height - 1);
          int w = rect.width.toInt().clamp(1, decodedImage.width - x);
          int h = rect.height.toInt().clamp(1, decodedImage.height - y);

          final croppedImg = img.copyCrop(
            decodedImage,
            x: x,
            y: y,
            width: w,
            height: h,
          );

          final tempDir = await getTemporaryDirectory();
          final croppedPath = p.join(tempDir.path, 'face_crop.jpg');
          await File(
            croppedPath,
          ).writeAsBytes(img.encodeJpg(croppedImg, quality: 90));

          croppedFile = File(croppedPath);
        } else {
          croppedFile = originalFile;
        }
      } else {
        croppedFile = originalFile;
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
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
            icon: Icon(_isUsingFrontCamera ? Icons.camera_rear : Icons.camera_front),
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
                // Face guide overlay (semitransparent dim outer, transparent oval center)
                Positioned.fill(
                  child: ClipPath(
                    clipper: FaceOverlayClipper(),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                // White oval guide border and instructional text
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: MediaQuery.of(context).size.height * 0.45,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.elliptical(200, 250)),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 2.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.face,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Position your face here',
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
          // Occasion label + capture button
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
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
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
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
