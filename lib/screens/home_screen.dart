import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_screen.dart';
import 'preview_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _selectedOccasion = 'casual';

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            imageFile: File(pickedFile.path),
            occasion: _selectedOccasion,
            faceDetected: false, // Perform dynamic face detection inside PreviewScreen
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
            tooltip: 'View History',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            tooltip: 'My Stylist Profile',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 48),
              const StyleToneLogo(size: 90),
              const SizedBox(height: 16),
              Text(
                'StyleTone AI',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Discover your perfect color palette',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(height: 24),
              // Take Photo Card
              _OptionCard(
                icon: Icons.camera_alt_rounded,
                title: 'Take Photo',
                subtitle: 'Use your camera to capture a selfie',
                color: theme.colorScheme.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CameraScreen(
                        cameras: widget.cameras,
                        initialOccasion: _selectedOccasion,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Pick from Gallery Card
              _OptionCard(
                icon: Icons.photo_library_rounded,
                title: 'Pick from Gallery',
                subtitle: 'Choose an existing photo',
                color: theme.colorScheme.secondary,
                onTap: _pickFromGallery,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }


}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(77)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class StyleToneLogo extends StatelessWidget {
  final double size;

  const StyleToneLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: const LinearGradient(
          colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE94057).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.checkroom_rounded,
          size: size * 0.55,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
