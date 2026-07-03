class Challenge {
  final String id;
  final String title;
  final String description;
  final int totalDays;
  final int daysCompleted;
  final DateTime startDate;
  final bool isActive;
  final bool isCompleted;
  final String? badgeName;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.totalDays,
    this.daysCompleted = 0,
    required this.startDate,
    this.isActive = false,
    this.isCompleted = false,
    this.badgeName,
  });

  double get progress => totalDays > 0 ? daysCompleted / totalDays : 0.0;

  Challenge copyWith({
    int? daysCompleted,
    bool? isActive,
    bool? isCompleted,
    String? badgeName,
  }) {
    return Challenge(
      id: id,
      title: title,
      description: description,
      totalDays: totalDays,
      daysCompleted: daysCompleted ?? this.daysCompleted,
      startDate: startDate,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      badgeName: badgeName ?? this.badgeName,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'totalDays': totalDays,
        'daysCompleted': daysCompleted,
        'startDate': startDate.toIso8601String(),
        'isActive': isActive ? 1 : 0,
        'isCompleted': isCompleted ? 1 : 0,
        'badgeName': badgeName,
      };

  factory Challenge.fromMap(Map<String, dynamic> map) {
    return Challenge(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      totalDays: map['totalDays'] as int,
      daysCompleted: map['daysCompleted'] as int? ?? 0,
      startDate: DateTime.parse(map['startDate'] as String),
      isActive: (map['isActive'] as int? ?? 0) == 1,
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      badgeName: map['badgeName'] as String?,
    );
  }
}

class DailyChallenge {
  final int dayNumber;
  final String title;
  final String description;
  final bool isCompleted;
  final String? completedDate;

  const DailyChallenge({
    required this.dayNumber,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.completedDate,
  });

  DailyChallenge copyWith({bool? isCompleted, String? completedDate}) {
    return DailyChallenge(
      dayNumber: dayNumber,
      title: title,
      description: description,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
    );
  }
}

const List<DailyChallenge> capsuleWardrobeChallenges = [
  DailyChallenge(dayNumber: 1, title: 'Know Your Palette', description: 'Open your latest StyleTone scan and memorise your 3 occasion palettes. Write them down.'),
  DailyChallenge(dayNumber: 2, title: 'One Base, Three Ways', description: 'Pick one neutral bottom and style it with 3 different tops from your closet.'),
  DailyChallenge(dayNumber: 3, title: 'Accent Hunt', description: 'Find 3 items in your accent colour and style them together.'),
  DailyChallenge(dayNumber: 4, title: 'Layering Lab', description: 'Layer 3 pieces in colours from your palette. Photograph the result.'),
  DailyChallenge(dayNumber: 5, title: 'Monochromatic Moment', description: 'Dress in varying shades of a single colour from your palette.'),
  DailyChallenge(dayNumber: 6, title: 'Colour Block', description: 'Pair your primary + secondary colours in one outfit. No neutrals allowed.'),
  DailyChallenge(dayNumber: 7, title: 'Week in Review', description: 'Scroll your Style Timeline. Which outfit felt most "you" this week?'),
  DailyChallenge(dayNumber: 8, title: 'Accessory Focus', description: 'Let your accent colour take centre stage — use it for your main statement piece.'),
  DailyChallenge(dayNumber: 9, title: 'Texture Play', description: 'Combine 3 different fabric textures in one palette-approved outfit.'),
  DailyChallenge(dayNumber: 10, title: 'Pattern Mix', description: 'Mix two patterns that share at least one colour from your palette.'),
  DailyChallenge(dayNumber: 11, title: 'Double Duty', description: 'Style one item for both office and casual. Photograph both looks.'),
  DailyChallenge(dayNumber: 12, title: 'Colour Refresh', description: 'Do a new selfie scan and compare your season with your first scan.'),
  DailyChallenge(dayNumber: 13, title: 'Shop Your Closet', description: 'Find 3 forgotten items in your closet and restyle them with palette colours.'),
  DailyChallenge(dayNumber: 14, title: 'Two-Week Wrap', description: 'Create a look combining your most-worn colour + a colour you rarely wear.'),
  DailyChallenge(dayNumber: 15, title: 'Evening Edit', description: 'Style a party/evening look using only 3 items + 1 accent accessory.'),
  DailyChallenge(dayNumber: 16, title: 'Neutral Base + Bold Pop', description: 'Wear all neutrals with one bold palette colour as the hero piece.'),
  DailyChallenge(dayNumber: 17, title: 'Shoe Swap', description: 'Wear the same outfit with 2 different shoe styles. Compare the vibe.'),
  DailyChallenge(dayNumber: 18, title: 'Colour Temperature', description: 'Identify which colours in your palette lean warm vs cool. Style accordingly.'),
  DailyChallenge(dayNumber: 19, title: 'Outerweight', description: 'Make your outerwear the focal point. Layer it over a complementary palette piece.'),
  DailyChallenge(dayNumber: 20, title: 'Print Remix', description: 'Photograph a printed item alongside your palette swatches. Note the shared hues.'),
  DailyChallenge(dayNumber: 21, title: 'Three-Item Challenge', description: 'Create 3 different outfits from just 3 tops + 3 bottoms + 3 accessories.'),
  DailyChallenge(dayNumber: 22, title: 'Travel Edit', description: 'Pack a capsule of 10 items for a 5-day trip. All must fit your palette.'),
  DailyChallenge(dayNumber: 23, title: 'Colour Proportion', description: 'Wear your primary colour on 60% of your body, secondary on 30%, accent on 10%.'),
  DailyChallenge(dayNumber: 24, title: 'Thrift Flip', description: 'Find one secondhand/vintage piece that matches your palette exactly.'),
  DailyChallenge(dayNumber: 25, title: 'Silhouette Experiment', description: 'Try a silhouette you normally avoid, but keep it in your palette colours.'),
  DailyChallenge(dayNumber: 26, title: 'Gift of Style', description: 'Style an outfit for a friend using their own closet + your palette knowledge.'),
  DailyChallenge(dayNumber: 27, title: 'Digital Detox Dress', description: 'Create a no-screen-day outfit that makes you feel confident without validation.'),
  DailyChallenge(dayNumber: 28, title: 'Colour Story', description: 'Write 3 sentences describing the mood your palette creates. Style to match.'),
  DailyChallenge(dayNumber: 29, title: 'Future Fit', description: 'Plan 3 outfits for upcoming events using your capsule. Add items to your wishlist.'),
  DailyChallenge(dayNumber: 30, title: 'Graduation Day', description: 'Wear your favourite capsule outfit. Take a photo. Share your journey. You earned the badge!'),
];
