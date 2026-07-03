class UserProfile {
  final String gender;
  final int age;
  final String preferredStyle;
  final bool muteVoiceOutput;
  final String themeName;
  final String? customPrimaryColor;
  final String? customSecondaryColor;

  UserProfile({
    required this.gender,
    required this.age,
    required this.preferredStyle,
    this.muteVoiceOutput = false,
    this.themeName = 'default',
    this.customPrimaryColor,
    this.customSecondaryColor,
  });

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'age': age,
        'preferredStyle': preferredStyle,
        'muteVoiceOutput': muteVoiceOutput,
        'themeName': themeName,
        'customPrimaryColor': customPrimaryColor,
        'customSecondaryColor': customSecondaryColor,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: json['gender'] as String? ?? 'neutral',
      age: json['age'] as int? ?? 30,
      preferredStyle: json['preferredStyle'] as String? ?? 'classic',
      muteVoiceOutput: json['muteVoiceOutput'] as bool? ?? false,
      themeName: json['themeName'] as String? ?? 'default',
      customPrimaryColor: json['customPrimaryColor'] as String?,
      customSecondaryColor: json['customSecondaryColor'] as String?,
    );
  }

  factory UserProfile.defaultProfile() {
    return UserProfile(
      gender: 'neutral',
      age: 30,
      preferredStyle: 'classic',
      muteVoiceOutput: false,
      themeName: 'default',
    );
  }
}
