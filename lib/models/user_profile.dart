class UserProfile {
  final String gender;
  final int age;
  final String preferredStyle;
  final bool muteVoiceOutput;
  final String themeName;
  final String? customPrimaryColor;
  final String? customSecondaryColor;
  final String? suggestedTheme;
  final bool themeSuggestionDismissed;

  UserProfile({
    required this.gender,
    required this.age,
    required this.preferredStyle,
    this.muteVoiceOutput = false,
    this.themeName = 'default',
    this.customPrimaryColor,
    this.customSecondaryColor,
    this.suggestedTheme,
    this.themeSuggestionDismissed = false,
  });

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'age': age,
        'preferredStyle': preferredStyle,
        'muteVoiceOutput': muteVoiceOutput,
        'themeName': themeName,
        'customPrimaryColor': customPrimaryColor,
        'customSecondaryColor': customSecondaryColor,
        'suggestedTheme': suggestedTheme,
        'themeSuggestionDismissed': themeSuggestionDismissed,
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
      suggestedTheme: json['suggestedTheme'] as String?,
      themeSuggestionDismissed:
          json['themeSuggestionDismissed'] as bool? ?? false,
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

  UserProfile copyWith({
    String? gender,
    int? age,
    String? preferredStyle,
    bool? muteVoiceOutput,
    String? themeName,
    String? customPrimaryColor,
    String? customSecondaryColor,
    String? suggestedTheme,
    bool? themeSuggestionDismissed,
  }) {
    return UserProfile(
      gender: gender ?? this.gender,
      age: age ?? this.age,
      preferredStyle: preferredStyle ?? this.preferredStyle,
      muteVoiceOutput: muteVoiceOutput ?? this.muteVoiceOutput,
      themeName: themeName ?? this.themeName,
      customPrimaryColor: customPrimaryColor ?? this.customPrimaryColor,
      customSecondaryColor: customSecondaryColor ?? this.customSecondaryColor,
      suggestedTheme: suggestedTheme ?? this.suggestedTheme,
      themeSuggestionDismissed:
          themeSuggestionDismissed ?? this.themeSuggestionDismissed,
    );
  }
}
