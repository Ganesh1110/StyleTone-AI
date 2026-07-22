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

class MakeupPalette {
  final List<String> lip;
  final List<String> eye;
  final List<String> cheek;
  final List<String> nail;

  MakeupPalette({
    required this.lip,
    required this.eye,
    required this.cheek,
    required this.nail,
  });

  factory MakeupPalette.fromJson(Map<String, dynamic> json) {
    return MakeupPalette(
      lip: (json['lip'] as List?)?.cast<String>() ?? [],
      eye: (json['eye'] as List?)?.cast<String>() ?? [],
      cheek: (json['cheek'] as List?)?.cast<String>() ?? [],
      nail: (json['nail'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'lip': lip,
        'eye': eye,
        'cheek': cheek,
        'nail': nail,
      };
}

class ColorRecommendation {
  final String detectedCategory;
  final String? detectedSubseason;
  final String? baseSeason;
  final int confidence;
  final String explanation;
  final Map<String, OccasionPalette> palettes;
  final MakeupPalette? makeupPalette;
  final List<String> hairColorPalette;
  final List<String> colorsToAvoid;

  ColorRecommendation({
    required this.detectedCategory,
    this.detectedSubseason,
    this.baseSeason,
    required this.confidence,
    required this.explanation,
    required this.palettes,
    this.makeupPalette,
    this.hairColorPalette = const [],
    this.colorsToAvoid = const [],
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

    MakeupPalette? makeup;
    if (json['makeup_palette'] != null) {
      makeup = MakeupPalette.fromJson(json['makeup_palette'] as Map<String, dynamic>);
    }

    return ColorRecommendation(
      detectedCategory: json['detected_category'] ?? 'Unknown',
      detectedSubseason: json['detected_subseason'] as String?,
      baseSeason: json['base_season'] as String?,
      confidence: json['confidence'] ?? 100,
      explanation: json['explanation'] ?? '',
      palettes: palettesMap,
      makeupPalette: makeup,
      hairColorPalette: (json['hair_color_palette'] as List?)?.cast<String>() ?? [],
      colorsToAvoid: (json['colors_to_avoid'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'detected_category': detectedCategory,
        'detected_subseason': detectedSubseason,
        'base_season': baseSeason,
        'confidence': confidence,
        'explanation': explanation,
        'palettes': palettes.map((key, value) => MapEntry(key, value.toJson())),
        if (makeupPalette != null) 'makeup_palette': makeupPalette!.toJson(),
        'hair_color_palette': hairColorPalette,
        'colors_to_avoid': colorsToAvoid,
      };
}
