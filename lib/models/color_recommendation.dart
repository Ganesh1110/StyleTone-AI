class ColorRecommendation {
  final String detectedCategory;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String message;
  final int confidence;
  final String explanation;

  ColorRecommendation({
    required this.detectedCategory,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.message,
    required this.confidence,
    required this.explanation,
  });

  factory ColorRecommendation.fromJson(Map<String, dynamic> json) {
    return ColorRecommendation(
      detectedCategory: json['detected_category'] ?? 'Unknown',
      primaryColor: json['primary_color'] ?? '#CCCCCC',
      secondaryColor: json['secondary_color'] ?? '#AAAAAA',
      accentColor: json['accent_color'] ?? '#888888',
      message: json['message'] ?? 'Stay stylish!',
      confidence: json['confidence'] ?? 100,
      explanation: json['explanation'] ?? '',
    );
  }
}
