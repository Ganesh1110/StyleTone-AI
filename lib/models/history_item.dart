import 'color_recommendation.dart';

class HistoryItem {
  final String id;
  final DateTime date;
  final String occasion;
  final String imagePath;
  final ColorRecommendation recommendation;

  HistoryItem({
    required this.id,
    required this.date,
    required this.occasion,
    required this.imagePath,
    required this.recommendation,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'occasion': occasion,
        'imagePath': imagePath,
        'recommendation': {
          'detected_category': recommendation.detectedCategory,
          'primary_color': recommendation.primaryColor,
          'secondary_color': recommendation.secondaryColor,
          'accent_color': recommendation.accentColor,
          'confidence': recommendation.confidence,
          'explanation': recommendation.explanation,
          'message': recommendation.message,
        }
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      occasion: json['occasion'] as String,
      imagePath: json['imagePath'] as String,
      recommendation: ColorRecommendation.fromJson(
        json['recommendation'] as Map<String, dynamic>,
      ),
    );
  }
}
