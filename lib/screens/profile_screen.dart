import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/theme_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  bool _isLoading = true;

  String _gender = 'neutral';
  int _age = 30;
  String _preferredStyle = 'classic';
  bool _muteVoiceOutput = false;
  String _themeName = 'default';
  String? _customPrimaryColor;
  String? _customSecondaryColor;

  static const List<Color> _presetPrimaryColors = [
    Color(0xFF6A1B9A), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFFD32F2F), Color(0xFFE65100), Color(0xFF00838F),
    Color(0xFF4A148C), Color(0xFF37474F), Color(0xFFAD1457),
    Color(0xFF283593),
  ];

  static const List<String> _presetPrimaryHexes = [
    '#6A1B9A', '#1565C0', '#2E7D32', '#D32F2F', '#E65100',
    '#00838F', '#4A148C', '#37474F', '#AD1457', '#283593',
  ];

  static const List<Color> _presetSecondaryColors = [
    Color(0xFFE94057), Color(0xFF00BCD4), Color(0xFFFF8F00),
    Color(0xFFFF5722), Color(0xFF9C27B0), Color(0xFF4CAF50),
    Color(0xFF2196F3), Color(0xFFFF4081), Color(0xFF00E676),
    Color(0xFFFFD600),
  ];

  static const List<String> _presetSecondaryHexes = [
    '#E94057', '#00BCD4', '#FF8F00', '#FF5722', '#9C27B0',
    '#4CAF50', '#2196F3', '#FF4081', '#00E676', '#FFD600',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getProfile();
    setState(() {
      _gender = profile.gender;
      _age = profile.age;
      _preferredStyle = profile.preferredStyle;
      _muteVoiceOutput = profile.muteVoiceOutput;
      _themeName = profile.themeName;
      _customPrimaryColor = profile.customPrimaryColor;
      _customSecondaryColor = profile.customSecondaryColor;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final updatedProfile = UserProfile(
      gender: _gender,
      age: _age,
      preferredStyle: _preferredStyle,
      muteVoiceOutput: _muteVoiceOutput,
      themeName: _themeName,
      customPrimaryColor: _customPrimaryColor,
      customSecondaryColor: _customSecondaryColor,
    );
    await _profileService.saveProfile(updatedProfile);
    await ThemeService.loadTheme();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stylist Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customize Your Stylist',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure your profile details below to receive personalized outfit suggestions and styling advice.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 32),

                  // Gender Selection Card
                  _buildSectionTitle('GENDER'),
                  const SizedBox(height: 8),
                  GlassCard(
                    color: Colors.white.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildGenderChip('male', Icons.male_rounded, 'Male'),
                        _buildGenderChip(
                          'female',
                          Icons.female_rounded,
                          'Female',
                        ),
                        _buildGenderChip(
                          'neutral',
                          Icons.person_rounded,
                          'Neutral',
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),

                  // Age Slider
                  _buildSectionTitle('AGE ($_age years)'),
                  const SizedBox(height: 8),
                  GlassCard(
                    color: Colors.white.withOpacity(0.05),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Slider(
                          value: _age.toDouble(),
                          min: 10.0,
                          max: 90.0,
                          divisions: 80,
                          activeColor: Theme.of(context).colorScheme.primary,
                          inactiveColor: Colors.white24,
                          onChanged: (val) {
                            setState(() {
                              _age = val.toInt();
                            });
                          },
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('10', style: TextStyle(color: Colors.white60)),
                              Text('90', style: TextStyle(color: Colors.white60)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),

                  // Preferred Style Cards
                  _buildSectionTitle('PREFERRED STYLE'),
                  const SizedBox(height: 8),
                  GlassCard(
                    color: Colors.white.withOpacity(0.05),
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStyleChip('classic', 'Classic'),
                        _buildStyleChip('trendy', 'Trendy'),
                        _buildStyleChip('athletic', 'Athletic'),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),

                  // Theme Selection
                  _buildSectionTitle('THEME'),
                  const SizedBox(height: 8),
                  GlassCard(
                    color: Colors.white.withOpacity(0.05),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildThemeCard('default', 'Default', [
                              const Color(0xFF8A2387),
                              const Color(0xFFE94057),
                            ]),
                            _buildThemeCard(
                              'ocean',
                              'Ocean',
                              [
                                const Color(0xFF0066CC),
                                const Color(0xFF00BCD4),
                              ],
                            ),
                            _buildThemeCard(
                              'forest',
                              'Forest',
                              [
                                const Color(0xFF2E7D32),
                                const Color(0xFFFF8F00),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildThemeCard('custom', 'Custom', null),
                        if (_themeName == 'custom') ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Primary Color',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildColorPicker(true),
                          const SizedBox(height: 16),
                          const Text(
                            'Secondary Color',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildColorPicker(false),
                        ],
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 250.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),

                  // App Settings
                  _buildSectionTitle('APP SETTINGS'),
                  const SizedBox(height: 8),
                  GlassCard(
                    color: Colors.white.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                _muteVoiceOutput ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                color: _muteVoiceOutput ? Colors.white60 : Colors.greenAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'AI Voice Assistant',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _muteVoiceOutput
                                                ? Colors.red.withOpacity(0.15)
                                                : Colors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _muteVoiceOutput ? 'MUTED' : 'ENABLED',
                                            style: TextStyle(
                                              color: _muteVoiceOutput ? Colors.redAccent : Colors.greenAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Reads style reports and closet matching recommendations aloud.',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: !_muteVoiceOutput, // ON means voice is active (unmuted)
                          activeColor: Colors.deepPurpleAccent,
                          activeTrackColor: Colors.deepPurple.shade900,
                          onChanged: (val) {
                            setState(() {
                              _muteVoiceOutput = !val; // Toggle mute status accordingly
                            });
                          },
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 48),

                  // Save Profile Button
                  Center(
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 64,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildGenderChip(String value, IconData icon, String label) {
    final isSelected = _gender == value;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      avatar: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.white60,
        size: 18,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: Colors.white10,
      side: BorderSide(color: isSelected ? primaryColor : Colors.white24),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _gender = value;
          });
        }
      },
    );
  }

  Widget _buildThemeCard(String value, String label, List<Color>? colors) {
    final isSelected = _themeName == value;
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.white24;
    return GestureDetector(
      onTap: () {
        setState(() {
          _themeName = value;
          if (value != 'custom') {
            _customPrimaryColor = null;
            _customSecondaryColor = null;
          }
        });
      },
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (colors != null)
              Container(
                height: 32,
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              )
            else
              Container(
                height: 32,
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white38),
                  color: Colors.white10,
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: Colors.white54,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker(bool isPrimary) {
    final colors = isPrimary ? _presetPrimaryColors : _presetSecondaryColors;
    final hexes = isPrimary ? _presetPrimaryHexes : _presetSecondaryHexes;
    final currentHex = isPrimary ? _customPrimaryColor : _customSecondaryColor;
    final defaultHex = isPrimary ? '#6A1B9A' : '#E94057';
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(colors.length, (i) {
        final color = colors[i];
        final hex = hexes[i];
        final isSelected = (currentHex ?? defaultHex) == hex;
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isPrimary) {
                _customPrimaryColor = hex;
              } else {
                _customSecondaryColor = hex;
              }
            });
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white24,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStyleChip(String value, String label) {
    final isSelected = _preferredStyle == value;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: Colors.white10,
      side: BorderSide(color: isSelected ? primaryColor : Colors.white24),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _preferredStyle = value;
          });
        }
      },
    );
  }
}
