class UserProfile {
  final String gender;
  final int age;
  final String preferredStyle;

  UserProfile({
    required this.gender,
    required this.age,
    required this.preferredStyle,
  });

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'age': age,
        'preferredStyle': preferredStyle,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: json['gender'] as String? ?? 'neutral',
      age: json['age'] as int? ?? 30,
      preferredStyle: json['preferredStyle'] as String? ?? 'classic',
    );
  }

  factory UserProfile.defaultProfile() {
    return UserProfile(
      gender: 'neutral',
      age: 30,
      preferredStyle: 'classic',
    );
  }
}
