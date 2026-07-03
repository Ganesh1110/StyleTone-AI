class UserProfile {
  final String gender;
  final int age;
  final String preferredStyle;
  final bool muteVoiceOutput;

  UserProfile({
    required this.gender,
    required this.age,
    required this.preferredStyle,
    this.muteVoiceOutput = false,
  });

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'age': age,
        'preferredStyle': preferredStyle,
        'muteVoiceOutput': muteVoiceOutput,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: json['gender'] as String? ?? 'neutral',
      age: json['age'] as int? ?? 30,
      preferredStyle: json['preferredStyle'] as String? ?? 'classic',
      muteVoiceOutput: json['muteVoiceOutput'] as bool? ?? false,
    );
  }

  factory UserProfile.defaultProfile() {
    return UserProfile(
      gender: 'neutral',
      age: 30,
      preferredStyle: 'classic',
      muteVoiceOutput: false,
    );
  }
}
