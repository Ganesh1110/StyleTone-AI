class Trip {
  final String id;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> activities;
  final List<String> packedItemIds;
  final bool isCompleted;

  const Trip({
    required this.id,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.activities = const [],
    this.packedItemIds = const [],
    this.isCompleted = false,
  });

  int get duration => endDate.difference(startDate).inDays + 1;

  Trip copyWith({
    List<String>? packedItemIds,
    bool? isCompleted,
  }) {
    return Trip(
      id: id,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      activities: activities,
      packedItemIds: packedItemIds ?? this.packedItemIds,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'destination': destination,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'activities': activities.join(','),
        'packedItemIds': packedItemIds.join(','),
        'isCompleted': isCompleted ? 1 : 0,
      };

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as String,
      destination: map['destination'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      activities: (map['activities'] as String?)?.isNotEmpty == true
          ? (map['activities'] as String).split(',')
          : [],
      packedItemIds: (map['packedItemIds'] as String?)?.isNotEmpty == true
          ? (map['packedItemIds'] as String).split(',')
          : [],
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
    );
  }
}

class DayOutfit {
  final int day;
  final DateTime date;
  final String? topId;
  final String? bottomId;
  final String? outerId;
  final String? shoesId;
  final String? accessoryId;
  final String? activityLabel;

  const DayOutfit({
    required this.day,
    required this.date,
    this.topId,
    this.bottomId,
    this.outerId,
    this.shoesId,
    this.accessoryId,
    this.activityLabel,
  });
}
