import 'color_recommendation.dart';

class HistoryItem {
  final String id;
  final DateTime date;
  final String occasion;
  final String imagePath;
  final ColorRecommendation recommendation;
  final int rating; // 0 = unrated, 1 = liked, -1 = disliked

  HistoryItem({
    required this.id,
    required this.date,
    required this.occasion,
    required this.imagePath,
    required this.recommendation,
    this.rating = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'occasion': occasion,
        'imagePath': imagePath,
        'rating': rating,
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
      rating: json['rating'] as int? ?? 0,
      recommendation: ColorRecommendation.fromJson(
        json['recommendation'] as Map<String, dynamic>,
      ),
    );
  }

  HistoryItem copyWith({
    int? rating,
  }) {
    return HistoryItem(
      id: id,
      date: date,
      occasion: occasion,
      imagePath: imagePath,
      recommendation: recommendation,
      rating: rating ?? this.rating,
    );
  }
}
