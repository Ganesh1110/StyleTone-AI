import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

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
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final updatedProfile = UserProfile(
      gender: _gender,
      age: _age,
      preferredStyle: _preferredStyle,
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
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure your profile details below to receive personalized outfit suggestions and styling advice.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 32),

                  // Gender Selection Card
                  _buildSectionTitle('GENDER'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
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
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Age Slider
                  _buildSectionTitle('AGE ($_age years)'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Slider(
                            value: _age.toDouble(),
                            min: 10.0,
                            max: 90.0,
                            divisions: 80,
                            activeColor: Colors.deepPurple,
                            inactiveColor: Colors.deepPurple.withOpacity(0.1),
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
                                Text('10', style: TextStyle(color: Colors.grey[600])),
                                Text('90', style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preferred Style Cards
                  _buildSectionTitle('PREFERRED STYLE'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStyleChip('classic', 'Classic'),
                          _buildStyleChip('trendy', 'Trendy'),
                          _buildStyleChip('athletic', 'Athletic'),
                        ],
                      ),
                    ),
                  ),
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
    final primaryColor = Colors.deepPurple;

    return ChoiceChip(
      avatar: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.grey[600],
        size: 18,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
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
    final primaryColor = Colors.deepPurple;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
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
