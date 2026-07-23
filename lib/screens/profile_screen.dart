import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/theme_service.dart';
import '../theme/theme_constants.dart';

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
  String? _hairColor;
  String? _eyeColor;

  static const List<Color> _presetPrimaryColors = [
    Color(0xFF8B5CF6),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFD32F2F),
    Color(0xFFE65100),
    Color(0xFF00838F),
    Color(0xFF4A148C),
    Color(0xFF37474F),
    Color(0xFFAD1457),
    Color(0xFF283593),
  ];

  static const List<String> _presetPrimaryHexes = [
    '#8B5CF6',
    '#1565C0',
    '#2E7D32',
    '#D32F2F',
    '#E65100',
    '#00838F',
    '#4A148C',
    '#37474F',
    '#AD1457',
    '#283593',
  ];

  static const List<String> _presetPrimaryLabels = [
    'Violet',
    'Royal Blue',
    'Forest Green',
    'Ruby Red',
    'Burnt Orange',
    'Teal',
    'Deep Purple',
    'Charcoal',
    'Magenta',
    'Navy',
  ];

  // Hair colour presets
  static const List<Color> _hairPresetColors = [
    Color(0xFF1A1010),  // Jet Black
    Color(0xFF3A2820),  // Dark Brown
    Color(0xFF5A4030),  // Medium Brown
    Color(0xFF8A6840),  // Light Brown
    Color(0xFFC4A060),  // Blonde
    Color(0xFFE8D5A0),  // Light Blonde
    Color(0xFFA04030),  // Auburn
    Color(0xFF8A3020),  // Red
    Color(0xFF6A4850),  // Dark Auburn
    Color(0xFFD0C0B0),  // Grey/Silver
  ];

  static const List<String> _hairPresetHexes = [
    '#1A1010', '#3A2820', '#5A4030', '#8A6840', '#C4A060',
    '#E8D5A0', '#A04030', '#8A3020', '#6A4850', '#D0C0B0',
  ];

  static const List<String> _hairPresetLabels = [
    'Jet Black', 'Dark Brown', 'Med. Brown', 'Light Brown', 'Blonde',
    'Light Blonde', 'Auburn', 'Red', 'Dark Auburn', 'Grey/Silver',
  ];

  // Eye colour presets
  static const List<Color> _eyePresetColors = [
    Color(0xFF3A2818),  // Dark Brown
    Color(0xFF6A4828),  // Hazel
    Color(0xFF4A7A28),  // Green
    Color(0xFF3870B0),  // Blue
    Color(0xFF7090B8),  // Light Blue
    Color(0xFF687050),  // Grey
    Color(0xFF8A6830),  // Amber
    Color(0xFF5A4830),  // Brown
    Color(0xFF4880A0),  // Teal
    Color(0xFF808080),  // Grey-Blue
  ];

  static const List<String> _eyePresetHexes = [
    '#3A2818', '#6A4828', '#4A7A28', '#3870B0', '#7090B8',
    '#687050', '#8A6830', '#5A4830', '#4880A0', '#808080',
  ];

  static const List<String> _eyePresetLabels = [
    'Dark Brown', 'Hazel', 'Green', 'Blue', 'Light Blue',
    'Grey', 'Amber', 'Brown', 'Teal', 'Grey-Blue',
  ];

  static const List<Color> _presetSecondaryColors = [
    Color(0xFFEC4899),
    Color(0xFF00BCD4),
    Color(0xFFFF8F00),
    Color(0xFFFF5722),
    Color(0xFF9C27B0),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF4081),
    Color(0xFF00E676),
    Color(0xFFFFD600),
  ];

  static const List<String> _presetSecondaryHexes = [
    '#EC4899',
    '#00BCD4',
    '#FF8F00',
    '#FF5722',
    '#9C27B0',
    '#4CAF50',
    '#2196F3',
    '#FF4081',
    '#00E676',
    '#FFD600',
  ];

  static const List<String> _presetSecondaryLabels = [
    'Hot Pink',
    'Cyan',
    'Amber',
    'Deep Orange',
    'Purple',
    'Green',
    'Blue',
    'Neon Pink',
    'Emerald',
    'Yellow',
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
      _hairColor = profile.hairColor;
      _eyeColor = profile.eyeColor;
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
      hairColor: _hairColor,
      eyeColor: _eyeColor,
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
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final textSecondary =
        theme.textTheme.bodyMedium?.color ??
        (isDark ? Colors.white70 : Colors.black54);
    final sectionTextColor = isDark ? Colors.grey : Colors.black45;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stylist Profile'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customize Your Stylist',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure your profile details below to receive personalized outfit suggestions and styling advice.',
                    style: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionTitle('GENDER'),
                  const SizedBox(height: 8),
                  GlassCard(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 16.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildGenderChip(
                              'male',
                              Icons.male_rounded,
                              'Male',
                            ),
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
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),

                  _buildSectionTitle('AGE ($_age years)'),
                  const SizedBox(height: 8),
                  GlassCard(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Slider(
                              value: _age.toDouble(),
                              min: 10.0,
                              max: 90.0,
                              divisions: 80,
                              activeColor: cs.primary,
                              inactiveColor: textSecondary.withValues(alpha: 0.3),
                              onChanged: (val) {
                                setState(() {
                                  _age = val.toInt();
                                });
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '10',
                                    style: TextStyle(color: textSecondary),
                                  ),
                                  Text(
                                    '90',
                                    style: TextStyle(color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),

                  _buildSectionTitle('PREFERRED STYLE'),
                  const SizedBox(height: 8),
                  GlassCard(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStyleChip('classic', 'Classic'),
                            _buildStyleChip('trendy', 'Trendy'),
                            _buildStyleChip('athletic', 'Athletic'),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),

                  _buildSectionTitle('THEME'),
                  const SizedBox(height: 8),
                  _buildThemeSection(cs, theme),
                  const SizedBox(height: 24),

                  _buildSectionTitle('HAIR & EYE COLOR'),
                  const SizedBox(height: 8),
                  GlassCard(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hair Color',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildHairEyeColorPicker('hair'),
                        const SizedBox(height: 16),
                        Text(
                          'Eye Color',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildHairEyeColorPicker('eye'),
                        const SizedBox(height: 8),
                        Text(
                          'These help the AI fine-tune your 12-season classification.',
                          style: TextStyle(fontSize: 11, color: textSecondary.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),

                  _buildSectionTitle('APP SETTINGS'),
                  const SizedBox(height: 8),
                  GlassCard(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    _muteVoiceOutput
                                        ? Icons.volume_off_rounded
                                        : Icons.volume_up_rounded,
                                    color: _muteVoiceOutput
                                        ? textSecondary
                                        : Colors.greenAccent,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'AI Voice Assistant',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color:
                                                    theme.brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _muteVoiceOutput
                                                    ? Colors.red.withValues(alpha: 
                                                        0.15,
                                                      )
                                                    : Colors.green.withValues(alpha: 
                                                        0.15,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _muteVoiceOutput
                                                    ? 'MUTED'
                                                    : 'ENABLED',
                                                style: TextStyle(
                                                  color: _muteVoiceOutput
                                                      ? Colors.redAccent
                                                      : Colors.greenAccent,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Reads style reports and closet matching recommendations aloud.',
                                          style: TextStyle(
                                            color:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? Colors.white38
                                                : Colors.black38,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: !_muteVoiceOutput,
                              activeThumbColor: cs.primary,
                              activeTrackColor: cs.primary.withValues(alpha: 0.5),
                              onChanged: (val) {
                                setState(() {
                                  _muteVoiceOutput = !val;
                                });
                              },
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 300.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 48),

                  Center(
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: isDark ? Colors.grey : Colors.black45,
      ),
    );
  }

  Widget _buildThemeSection(ColorScheme cs, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final allThemes = ThemeConstants.orderedThemes;

    return GlassCard(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.03),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: allThemes
                .map((t) => _buildThemePreviewTile(t, cs))
                .toList(),
          ),
          const SizedBox(height: 12),
          _buildThemeCard('custom', 'Custom', null, cs),
          if (_themeName == 'custom') ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Primary Color',
                  style: TextStyle(
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetCustomColors,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text(
                    'Restore Defaults',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildColorPicker(true, cs),
            const SizedBox(height: 16),
            Text(
              'Secondary Color',
              style: TextStyle(
                color:
                    Theme.of(context).textTheme.bodyMedium?.color ??
                    Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorPicker(false, cs),
          ],
        ],
      ),
    );
  }

  Widget _buildThemePreviewTile(ThemeConfig t, ColorScheme cs) {
    final isSelected = _themeName == t.id;
    final isMinimalWhite = t.id == 'minimal_white';

    return GestureDetector(
      onTap: () {
        setState(() {
          _themeName = t.id;
          _customPrimaryColor = null;
          _customSecondaryColor = null;
        });
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? cs.primary : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: t.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
              child: Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [t.primary, t.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: isMinimalWhite
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Aa',
                            style: TextStyle(
                              color: t.background,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.description,
                    style: TextStyle(fontSize: 8, color: t.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetCustomColors() {
    setState(() {
      _customPrimaryColor = null;
      _customSecondaryColor = null;
    });
  }

  Widget _buildThemeCard(
    String value,
    String label,
    List<Color>? colors,
    ColorScheme cs,
  ) {
    final isSelected = _themeName == value;
    final borderColor = isSelected ? cs.primary : Colors.white24;
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
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
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

  Widget _buildColorPicker(bool isPrimary, ColorScheme cs) {
    final colors = isPrimary ? _presetPrimaryColors : _presetSecondaryColors;
    final hexes = isPrimary ? _presetPrimaryHexes : _presetSecondaryHexes;
    final labels = isPrimary ? _presetPrimaryLabels : _presetSecondaryLabels;
    final currentHex = isPrimary ? _customPrimaryColor : _customSecondaryColor;
    final defaultHex = isPrimary ? '#8B5CF6' : '#EC4899';
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: List.generate(colors.length, (i) {
        final color = colors[i];
        final hex = hexes[i];
        final label = labels[i];
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
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
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.white60,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHairEyeColorPicker(String type) {
    final colors = type == 'hair' ? _hairPresetColors : _eyePresetColors;
    final hexes = type == 'hair' ? _hairPresetHexes : _eyePresetHexes;
    final labels = type == 'hair' ? _hairPresetLabels : _eyePresetLabels;
    final currentHex = type == 'hair' ? _hairColor : _eyeColor;
    final isCustom = currentHex != null && !hexes.contains(currentHex);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _pickColorFromPhoto(type),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.cyan, Colors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white38, width: 1),
                ),
                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 48,
                child: Text(
                  'Photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white60,
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (isCustom)
          GestureDetector(
            onTap: () {
              setState(() {
                if (type == 'hair') {
                  _hairColor = null;
                } else {
                  _eyeColor = null;
                }
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(
                      int.parse(currentHex.substring(1), radix: 16),
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Color(
                          int.parse(currentHex.substring(1), radix: 16),
                        ).withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white70),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 48,
                  child: Text(
                    currentHex.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 7,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white60,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ...List.generate(colors.length, (i) {
          final color = colors[i];
          final hex = hexes[i];
          final label = labels[i];
          final isSelected = currentHex == hex;
          return GestureDetector(
            onTap: () {
              setState(() {
                if (type == 'hair') {
                  _hairColor = isSelected ? null : hex;
                } else {
                  _eyeColor = isSelected ? null : hex;
                }
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white24,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 48,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white60,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<Uint8List?> _applySelfieMask(img.Image image) async {
    try {
      final segmenter = SelfieSegmenter(mode: SegmenterMode.single);
      final inputImage = InputImage.fromFilePath(
        (await _saveTempImage(image)).path,
      );
      final mask = await segmenter.processImage(inputImage);
      await segmenter.close();
      if (mask == null) return null;

      final masked = img.Image(width: image.width, height: image.height);
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final maskIdx = y * mask.width + x;
          final confidence = maskIdx < mask.confidences.length ? mask.confidences[maskIdx] : 0.0;
          final p = image.getPixel(x, y);
          if (confidence >= 0.5) {
            masked.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
          } else {
            final gray = (p.r.toInt() * 0.3 + p.g.toInt() * 0.59 + p.b.toInt() * 0.11).round();
            masked.setPixelRgba(x, y, gray, gray, gray, 255);
          }
        }
      }
      return img.encodeJpg(masked, quality: 90);
    } catch (_) {
      return null;
    }
  }

  Future<File> _saveTempImage(img.Image image) async {
    final dir = await Directory.systemTemp.createTemp('style_tone_');
    final file = File('${dir.path}/temp.jpg');
    await file.writeAsBytes(img.encodeJpg(image, quality: 90));
    return file;
  }

  Future<void> _pickColorFromPhoto(String type) async {
    try {
      final picker = ImagePicker();
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Pick ${type == 'hair' ? 'Hair' : 'Eye'} Color'),
          content: const Text('Choose a photo source'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              child: const Text('Gallery'),
            ),
          ],
        ),
      );
      if (source == null || !mounted) return;

      final picked = await picker.pickImage(source: source);
      if (picked == null || !mounted) return;

      final bytes = await File(picked.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      final maskedBytes = await _applySelfieMask(decoded);
      final displayBytes = maskedBytes ?? bytes;

      if (!mounted) return;
      final isHair = type == 'hair';
      final hint = isHair
          ? 'Tap on your hair to sample its color'
          : 'Tap on your iris (the colored part of your eye)';
      final hex = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => _ColorPickerScreen(
            imageBytes: displayBytes,
            title: isHair ? 'Pick Hair Color' : 'Pick Eye Color',
            hint: hint,
          ),
        ),
      );
      if (hex == null || !mounted) return;

      setState(() {
        if (type == 'hair') {
          _hairColor = hex;
        } else {
          _eyeColor = hex;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick color: $e')),
        );
      }
    }
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

class _ColorPickerScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;
  final String hint;

  const _ColorPickerScreen({
    required this.imageBytes,
    required this.title,
    required this.hint,
  });

  @override
  State<_ColorPickerScreen> createState() => _ColorPickerScreenState();
}

class _ColorPickerScreenState extends State<_ColorPickerScreen>
    with SingleTickerProviderStateMixin {
  img.Image? _decoded;
  Color _sampledColor = Colors.white;
  String _hexColor = '#FFFFFF';
  bool _loaded = false;
  Offset? _dropperPos;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _decoded = img.decodeImage(widget.imageBytes);
    _loaded = true;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _sampleAt(Offset localPosition, Size imageSize) {
    if (_decoded == null) return Colors.white;

    final x = (localPosition.dx / imageSize.width * _decoded!.width).round().clamp(0, _decoded!.width - 1);
    final y = (localPosition.dy / imageSize.height * _decoded!.height).round().clamp(0, _decoded!.height - 1);

    int sumR = 0, sumG = 0, sumB = 0, count = 0;
    for (int dy = -3; dy <= 3; dy++) {
      for (int dx = -3; dx <= 3; dx++) {
        final p = _decoded!.getPixel(
          (x + dx).clamp(0, _decoded!.width - 1),
          (y + dy).clamp(0, _decoded!.height - 1),
        );
        sumR += p.r.toInt();
        sumG += p.g.toInt();
        sumB += p.b.toInt();
        count++;
      }
    }

    final r = (sumR ~/ count).clamp(0, 255);
    final g = (sumG ~/ count).clamp(0, 255);
    final b = (sumB ~/ count).clamp(0, 255);

    return Color.fromARGB(255, r, g, b);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _hexColor),
            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final Size imageArea = Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    onTapUp: (details) {
                      final color = _sampleAt(details.localPosition, imageArea);
                      setState(() {
                        _dropperPos = details.localPosition;
                        _sampledColor = color;
                        final r = (color.r * 255).round().clamp(0, 255);
                        final g = (color.g * 255).round().clamp(0, 255);
                        final b = (color.b * 255).round().clamp(0, 255);
                        _hexColor = '#${r.toRadixString(16).padLeft(2, '0')}'
                            '${g.toRadixString(16).padLeft(2, '0')}'
                            '${b.toRadixString(16).padLeft(2, '0')}';
                      });
                    },
                    child: Stack(
                      children: [
                        Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.contain,
                          width: imageArea.width,
                          height: imageArea.height,
                        ),
                        if (_dropperPos != null)
                          Positioned(
                            left: _dropperPos!.dx - 28,
                            top: _dropperPos!.dy - 28,
                            child: AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (context, child) {
                                final s = _pulseAnim.value;
                                return Transform.scale(
                                  scale: s,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(alpha: 0.1),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black45,
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _sampledColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 2),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _hexColor.toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                      ),
                    ),
                    Text(
                      widget.hint,
                      style: TextStyle(
                        fontSize: 12,
                        color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white60).withValues(alpha: 0.7),
                      ),
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
