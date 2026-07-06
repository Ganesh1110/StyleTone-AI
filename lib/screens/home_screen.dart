import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_screen.dart';
import 'preview_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'closet_screen.dart';
import 'outfit_combinator_screen.dart';
import 'live_matcher_screen.dart';
import 'challenge_screen.dart';
import 'trip_mode_screen.dart';
import 'style_timeline_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/glass_card.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
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

    final List<Widget> pages = [
      _buildScannerTab(theme),
      LiveMatcherScreen(cameras: widget.cameras),
      const ClosetScreen(),
      const OutfitCombinatorScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // Set type to fixed to display all 4 items cleanly
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.face_retouching_natural_rounded),
            label: 'Stylist Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.center_focus_strong_rounded),
            label: 'Live Match',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checkroom_rounded),
            label: 'My Closet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.style_rounded),
            label: 'Outfit Match',
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab(ThemeData theme) {
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
              const SizedBox(height: 24),
              // Feature grid
              const Text(
                'Explore More',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniFeatureCard(
                      icon: Icons.emoji_events_rounded,
                      label: 'Capsule\nChallenge',
                      color: Colors.amber,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengeScreen())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniFeatureCard(
                      icon: Icons.flight_rounded,
                      label: 'Trip\nPacking',
                      color: Colors.lightBlue,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripModeScreen())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniFeatureCard(
                      icon: Icons.timeline_rounded,
                      label: 'Style\nTimeline',
                      color: Colors.teal,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleTimelineScreen())),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }


}

class _MiniFeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniFeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.2)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ).animate().scale(
        curve: Curves.easeOutBack,
        duration: 400.ms,
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

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ).animate().scale(
            curve: Curves.easeOutBack,
            duration: 400.ms,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
