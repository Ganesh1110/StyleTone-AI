import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final updatedProfile = UserProfile(
      gender: _gender,
      age: _age,
      preferredStyle: _preferredStyle,
      muteVoiceOutput: _muteVoiceOutput,
    );
    await _profileService.saveProfile(updatedProfile);

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

                  // App Settings
                  _buildSectionTitle('APP SETTINGS'),
                  const SizedBox(height: 8),
                  GlassCard(
                    color: Colors.white.withOpacity(0.05),
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.volume_off_rounded, color: Colors.white70, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Mute AI Voice Output',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                          ],
                        ),
                        Switch(
                          value: _muteVoiceOutput,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            setState(() {
                              _muteVoiceOutput = val;
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
