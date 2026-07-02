class OccasionPalette {
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String message;

  OccasionPalette({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.message,
  });

  factory OccasionPalette.fromJson(Map<String, dynamic> json) {
    return OccasionPalette(
      primaryColor: json['primary_color'] ?? '#CCCCCC',
      secondaryColor: json['secondary_color'] ?? '#AAAAAA',
      accentColor: json['accent_color'] ?? '#888888',
      message: json['message'] ?? 'Stay stylish!',
    );
  }

  Map<String, dynamic> toJson() => {
        'primary_color': primaryColor,
        'secondary_color': secondaryColor,
        'accent_color': accentColor,
        'message': message,
      };
}

class ColorRecommendation {
  final String detectedCategory;
  final int confidence;
  final String explanation;
  final Map<String, OccasionPalette> palettes;

  ColorRecommendation({
    required this.detectedCategory,
    required this.confidence,
    required this.explanation,
    required this.palettes,
  });

  // Getter shortcuts to retain backwards compatibility for parts of the app
  // expecting legacy flat properties (redirects to 'casual' by default)
  String get primaryColor => palettes['casual']?.primaryColor ?? '#CCCCCC';
  String get secondaryColor => palettes['casual']?.secondaryColor ?? '#AAAAAA';
  String get accentColor => palettes['casual']?.accentColor ?? '#888888';
  String get message => palettes['casual']?.message ?? 'Stay stylish!';

  factory ColorRecommendation.fromJson(Map<String, dynamic> json) {
    final Map<String, OccasionPalette> palettesMap = {};

    if (json['palettes'] != null) {
      final palettesJson = json['palettes'] as Map<String, dynamic>;
      palettesJson.forEach((key, value) {
        palettesMap[key] = OccasionPalette.fromJson(value as Map<String, dynamic>);
      });
    } else {
      // Legacy fallback for records created in v1.0 / v1.5
      final fallbackPalette = OccasionPalette(
        primaryColor: json['primary_color'] ?? '#CCCCCC',
        secondaryColor: json['secondary_color'] ?? '#AAAAAA',
        accentColor: json['accent_color'] ?? '#888888',
        message: json['message'] ?? 'Stay stylish!',
      );
      palettesMap['office'] = fallbackPalette;
      palettesMap['party'] = fallbackPalette;
      palettesMap['casual'] = fallbackPalette;
    }

    return ColorRecommendation(
      detectedCategory: json['detected_category'] ?? 'Unknown',
      confidence: json['confidence'] ?? 100,
      explanation: json['explanation'] ?? '',
      palettes: palettesMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'detected_category': detectedCategory,
        'confidence': confidence,
        'explanation': explanation,
        'palettes': palettes.map((key, value) => MapEntry(key, value.toJson())),
      };
}
