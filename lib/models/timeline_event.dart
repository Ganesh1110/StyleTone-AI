enum TimelineEventType {
  scan,
  closetAdd,
  outfitSaved,
  challengeCompleted,
  tripCompleted,
}

class TimelineEvent {
  final String id;
  final TimelineEventType type;
  final DateTime date;
  final String title;
  final String description;
  final String? imagePath;
  final Map<String, dynamic>? metadata;

  const TimelineEvent({
    required this.id,
    required this.type,
    required this.date,
    required this.title,
    required this.description,
    this.imagePath,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'date': date.toIso8601String(),
        'title': title,
        'description': description,
        'imagePath': imagePath,
        'metadata': metadata?.toString(),
      };

  factory TimelineEvent.fromMap(Map<String, dynamic> map) {
    return TimelineEvent(
      id: map['id'] as String,
      type: TimelineEventType.values[map['type'] as int],
      date: DateTime.parse(map['date'] as String),
      title: map['title'] as String,
      description: map['description'] as String,
      imagePath: map['imagePath'] as String?,
      metadata: null,
    );
  }
}

class StyleAnalytics {
  final int totalScans;
  final int totalClosetItems;
  final int totalChallengesCompleted;
  final int totalOutfitsSaved;
  final String mostWornColorHex;
  final String mostWornColorName;
  final String dominantSeason;
  final int streakDays;

  const StyleAnalytics({
    this.totalScans = 0,
    this.totalClosetItems = 0,
    this.totalChallengesCompleted = 0,
    this.totalOutfitsSaved = 0,
    this.mostWornColorHex = '#CCCCCC',
    this.mostWornColorName = 'Unknown',
    this.dominantSeason = 'Unknown',
    this.streakDays = 0,
  });
}
