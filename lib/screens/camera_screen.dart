import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

import '../screens/result_screen.dart';

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
  late Future<void> _initializeControllerFuture;

  late String _selectedOccasion;
  bool _isProcessing = false;

  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector(
    FaceDetectorOptions(
      enableClassification: false,
      enableTracking: false,
      minFaceSize: 0.15,
    ),
  );

  @override
  void initState() {
    super.initState();
    _selectedOccasion = widget.initialOccasion;
    _controller = CameraController(widget.cameras[0], ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _takePictureAndProcess() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Take the picture
      final image = await _controller.takePicture();
      final File originalFile = File(image.path);

      // 2. Detect face in the image
      final inputImage = InputImage.fromFile(originalFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      File croppedFile;

      if (faces.isNotEmpty) {
        // 3. Crop the face region (using the first face)
        final face = faces.first;
        final rect = face.boundingBox;

        // Read the image to crop
        final bytes = await originalFile.readAsBytes();
        final decodedImage = img.decodeImage(bytes);

        if (decodedImage != null) {
          // Ensure crop bounds are within image
          int x = rect.left.toInt().clamp(0, decodedImage.width - 1);
          int y = rect.top.toInt().clamp(0, decodedImage.height - 1);
          int w = rect.width.toInt().clamp(1, decodedImage.width - x);
          int h = rect.height.toInt().clamp(1, decodedImage.height - y);

          // Crop just the face region (ML Kit bounding box)
          final croppedImg = img.copyCrop(
            decodedImage,
            x: x,
            y: y,
            width: w,
            height: h,
          );

          // Save cropped image to temp file
          final tempDir = await getTemporaryDirectory();
          final croppedPath = p.join(tempDir.path, 'face_crop.jpg');
          await File(
            croppedPath,
          ).writeAsBytes(img.encodeJpg(croppedImg, quality: 90));

          croppedFile = File(croppedPath);
        } else {
          // Fallback if decoding fails
          croppedFile = originalFile;
        }
      } else {
        // 4. No face found: show a warning but still use the full image
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No face detected. Using full image. Please ensure good lighting.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        croppedFile = originalFile;
      }

      // 5. Navigate to Result Screen with the cropped image
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              imageFile: croppedFile,
              occasion: _selectedOccasion,
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

  // Optional: Pick from gallery for testing
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final File file = File(pickedFile.path);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ResultScreen(imageFile: file, occasion: _selectedOccasion),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StyleTone AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _pickFromGallery,
            tooltip: 'Pick from Gallery',
          ),
        ],
      ),
      body: Column(
        children: [
          // Occasion Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOccasionChip('Office', 'office'),
                const SizedBox(width: 8),
                _buildOccasionChip('Party', 'party'),
                const SizedBox(width: 8),
                _buildOccasionChip('Casual', 'casual'),
              ],
            ),
          ),
          // Camera Preview
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          // Capture Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isProcessing) const CircularProgressIndicator(),
                FloatingActionButton(
                  onPressed: _isProcessing ? null : _takePictureAndProcess,
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccasionChip(String label, String value) {
    final isSelected = _selectedOccasion == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedOccasion = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.deepPurple[100],
      checkmarkColor: Colors.deepPurple,
    );
  }
}
