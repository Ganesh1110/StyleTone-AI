class ColorRecommendation {
  final String detectedCategory;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String message;

  ColorRecommendation({
    required this.detectedCategory,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.message,
  });

  factory ColorRecommendation.fromJson(Map<String, dynamic> json) {
    return ColorRecommendation(
      detectedCategory: json['detected_category'] ?? 'Unknown',
      primaryColor: json['primary_color'] ?? '#CCCCCC',
      secondaryColor: json['secondary_color'] ?? '#AAAAAA',
      accentColor: json['accent_color'] ?? '#888888',
      message: json['message'] ?? 'Stay stylish!',
    );
  }
}
