import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'home_screen.dart';
import '../widgets/glass_card.dart';
import '../theme/theme_constants.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const OnboardingScreen({super.key, required this.cameras});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Analyze Skin Tone',
      description:
          'Take a quick selfie or choose an existing photo to instantly analyze your natural skin undertones using advanced on-device AI.',
      icon: Icons.face_retouching_natural_rounded,
      gradient: const [Color(0xFF8A2387), Color(0xFFE94057)],
    ),
    OnboardingData(
      title: 'Lighting Calibration',
      description:
          'For the best results, stand facing a window with natural daylight. Avoid warm indoor bulbs or harsh shadows.',
      icon: Icons.wb_sunny_rounded,
      gradient: const [Color(0xFFF6D365), Color(0xFFFDA085)],
    ),
    OnboardingData(
      title: 'Personalized Palettes',
      description:
          'Receive custom-curated color recommendations tailored specifically to your skin category for office, party, or casual wear.',
      icon: Icons.palette_rounded,
      gradient: const [Color(0xFFE94057), Color(0xFFF27121)],
    ),
    OnboardingData(
      title: 'Voice Assistant & Privacy',
      description:
          'Listen to your stylist tips read aloud. All processing is done locally on your device, ensuring complete privacy.',
      icon: Icons.shield_rounded,
      gradient: const [Color(0xFFF27121), Color(0xFF8A2387)],
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => HomeScreen(cameras: widget.cameras),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background Color/Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ThemeConstants.defaultTheme.background, const Color(0xFF2A2A35)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Pager content
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon Container with elegant gradient
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: page.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: page.gradient[0].withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Icon(
                        page.icon,
                        size: 80,
                        color: Colors.white,
                      ),
                    ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack).fadeIn(),
                    
                    const SizedBox(height: 64),
                    
                    // Glass Card for Content
                    GlassCard(
                      child: Column(
                        children: [
                          Text(
                            page.title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().slideY(begin: 0.5, end: 0, duration: 400.ms).fadeIn(),
                          const SizedBox(height: 16),
                          Text(
                            page.description,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().slideY(begin: 0.5, end: 0, duration: 500.ms, delay: 100.ms).fadeIn(),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms),
                  ],
                ),
              );
            },
          ),

          // Controls & Indicators at the bottom
          Positioned(
            bottom: 48,
            left: 32,
            right: 32,
            child: Column(
              children: [
                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: _currentPage == index ? 24.0 : 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4.0),
                        color: _currentPage == index
                            ? ThemeConstants.defaultTheme.secondary
                            : Colors.white24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Skip button or empty space
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 60),

                    // Next/Get Started button
                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _completeOnboarding();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConstants.defaultTheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 10,
                        shadowColor: ThemeConstants.defaultTheme.secondary.withValues(alpha: 0.5),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ).animate(target: _currentPage == _pages.length - 1 ? 1 : 0)
                     .shimmer(duration: 1.seconds, color: Colors.white30),
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

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}
