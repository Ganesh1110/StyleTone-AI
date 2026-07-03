import 'closet_item.dart';
import 'color_recommendation.dart';

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
  final List<String> capsuleItemIds;
  final String? seasonPaletteJson;

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
    this.capsuleItemIds = const [],
    this.seasonPaletteJson,
  });

  double get progress => totalDays > 0 ? daysCompleted / totalDays : 0.0;
  int get capsuleSize => capsuleItemIds.length;

  Challenge copyWith({
    int? daysCompleted,
    bool? isActive,
    bool? isCompleted,
    String? badgeName,
    List<String>? capsuleItemIds,
    String? seasonPaletteJson,
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
      capsuleItemIds: capsuleItemIds ?? this.capsuleItemIds,
      seasonPaletteJson: seasonPaletteJson ?? this.seasonPaletteJson,
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
        'capsuleItemIds': capsuleItemIds.join(','),
        'seasonPaletteJson': seasonPaletteJson,
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
      capsuleItemIds: (map['capsuleItemIds'] as String?)?.isNotEmpty == true
          ? (map['capsuleItemIds'] as String).split(',')
          : [],
      seasonPaletteJson: map['seasonPaletteJson'] as String?,
    );
  }
}

class DailyChallenge {
  final int dayNumber;
  final String title;
  final String description;
  final bool isCompleted;
  final String? completedDate;
  final List<String> suggestedItemIds;

  const DailyChallenge({
    required this.dayNumber,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.completedDate,
    this.suggestedItemIds = const [],
  });

  DailyChallenge copyWith({bool? isCompleted, String? completedDate}) {
    return DailyChallenge(
      dayNumber: dayNumber,
      title: title,
      description: description,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
      suggestedItemIds: suggestedItemIds,
    );
  }
}

List<DailyChallenge> generatePersonalizedChallenges({
  required List<ClosetItem> capsuleItems,
  required ColorRecommendation? recommendation,
}) {
  final categorized = _categorize(capsuleItems);
  final itemsByCategory = categorized;
  final tops = itemsByCategory['top'] ?? [];
  final bottoms = itemsByCategory['bottom'] ?? [];
  final outers = itemsByCategory['outer'] ?? [];
  final shoesList = itemsByCategory['shoes'] ?? [];
  final accessories = itemsByCategory['accessory'] ?? [];

  final palette = recommendation?.palettes['casual'];
  final primaryHex = palette?.primaryColor ?? '#CCCCCC';
  final secondaryHex = palette?.secondaryColor ?? '#AAAAAA';
  final accentHex = palette?.accentColor ?? '#888888';
  final season = recommendation?.detectedCategory ?? 'your season';

  String _itemName(List<ClosetItem> items, int index) {
    if (items.isEmpty) return 'an item';
    final i = index % items.length;
    return '${items[i].colorName} ${items[i].category}';
  }

  String _findNeutral(List<ClosetItem> items) {
    final neutrals = items.where((i) =>
        ['Beige', 'Cream White', 'Pure White', 'Light Gray', 'Charcoal Gray', 'Jet Black', 'Tan Brown']
            .any((n) => i.colorName.contains(n)));
    return neutrals.isNotEmpty ? '${neutrals.first.colorName} ${neutrals.first.category}' : 'a neutral piece';
  }

  String _findColor(List<ClosetItem> items, String hex) {
    final colorVal = int.parse(hex.replaceFirst('#', '0xFF'));
    final matches = items.where((i) {
      final itemColor = int.parse(i.hexColor.replaceFirst('#', '0xFF'));
      return (itemColor - colorVal).abs() < 0x333333;
    });
    return matches.isNotEmpty ? '${matches.first.colorName} ${matches.first.category}' : 'an item in this shade';
  }

  String _findColorName(List<ClosetItem> items, String hex) {
    final colorVal = int.parse(hex.replaceFirst('#', '0xFF'));
    final matches = items.where((i) {
      final itemColor = int.parse(i.hexColor.replaceFirst('#', '0xFF'));
      return (itemColor - colorVal).abs() < 0x333333;
    });
    return matches.isNotEmpty ? matches.first.colorName : 'this shade';
  }

  return [
    DailyChallenge(
      dayNumber: 1,
      title: 'Know Your Capsule',
      description: 'You selected ${capsuleItems.length} capsule items. Review your ${season} palette. Your key colours: $primaryHex (primary), $secondaryHex (secondary), $accentHex (accent). Memorise them.',
      suggestedItemIds: capsuleItems.take(5).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 2,
      title: 'One Bottom, Three Tops',
      description: 'Take ${_findNeutral(bottoms)} and style it with 3 different tops: ${_itemName(tops, 0)}, ${_itemName(tops, 1)}, and ${_itemName(tops, 2)}.',
      suggestedItemIds: [
        if (bottoms.isNotEmpty) bottoms.first.id,
        ...tops.take(3).map((i) => i.id),
      ],
    ),
    DailyChallenge(
      dayNumber: 3,
      title: 'Accent Hunt',
      description: 'Find items close to your accent colour $accentHex. Try ${_findColor(capsuleItems, accentHex)}. Style them together.',
      suggestedItemIds: capsuleItems.where((i) {
        final itemColor = int.parse(i.hexColor.replaceFirst('#', '0xFF'));
        final accentVal = int.parse(accentHex.replaceFirst('#', '0xFF'));
        return (itemColor - accentVal).abs() < 0x333333;
      }).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 4,
      title: '3-Layer Lab',
      description: 'Layer these 3: ${_itemName(tops, 0)} + ${_itemName(outers, 0)} + ${_itemName(accessories, 0)}. All must come from your palette colours.',
      suggestedItemIds: [
        if (tops.isNotEmpty) tops[0].id,
        if (outers.isNotEmpty) outers[0].id,
        if (accessories.isNotEmpty) accessories[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 5,
      title: 'Monochromatic Moment',
      description: 'Wear varying shades of one palette colour. ${_findColorName(capsuleItems, primaryHex)} is your primary — build an outfit using only tones close to $primaryHex.',
      suggestedItemIds: capsuleItems.take(5).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 6,
      title: 'Colour Block',
      description: 'Pair your primary ($primaryHex) + secondary ($secondaryHex). Use ${_findColor(capsuleItems, primaryHex)} and ${_findColor(capsuleItems, secondaryHex)}. No neutrals.',
      suggestedItemIds: [
        if (tops.isNotEmpty) tops[0].id,
        if (bottoms.isNotEmpty) bottoms[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 7,
      title: 'Week in Review',
      description: 'Check your Style Timeline. Which ${season} outfit felt best this week? Recreate your favourite look and note what worked.',
      suggestedItemIds: [],
    ),
    DailyChallenge(
      dayNumber: 8,
      title: 'Accessory Focus',
      description: 'Let your accent colour $accentHex take centre stage. Wear ${_findColor(capsuleItems, accentHex)} as your main statement piece.',
      suggestedItemIds: accessories.take(3).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 9,
      title: 'Texture Play',
      description: 'Combine 3 textures from your capsule: ${_itemName(tops, 0)}, ${_itemName(bottoms, 0)}, ${_itemName(outers, 0)}. Keep them in your palette.',
      suggestedItemIds: [
        if (tops.isNotEmpty) tops[0].id,
        if (bottoms.isNotEmpty) bottoms[0].id,
        if (outers.isNotEmpty) outers[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 10,
      title: 'Mix Your Patterns',
      description: 'Pick two items that share ${_findColorName(capsuleItems, primaryHex)}. Style ${_itemName(tops, 1)} with ${_itemName(bottoms, 1)}.',
      suggestedItemIds: [
        if (tops.length > 1) tops[1].id,
        if (bottoms.length > 1) bottoms[1].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 11,
      title: 'Double Duty',
      description: 'Style ${_findNeutral(bottoms)} + ${_itemName(tops, 0)} for office AND casual. Swap shoes + accessories to transform the look.',
      suggestedItemIds: [
        if (bottoms.isNotEmpty) bottoms[0].id,
        if (tops.isNotEmpty) tops[0].id,
        if (shoesList.isNotEmpty) shoesList[0].id,
        if (accessories.isNotEmpty) accessories[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 12,
      title: 'Season Recheck',
      description: 'Do a fresh selfie scan and compare your new ${season} result with your first scan. Has anything shifted?',
      suggestedItemIds: [],
    ),
    DailyChallenge(
      dayNumber: 13,
      title: 'Forgotten Gems',
      description: 'Find 3 capsule items you have not worn yet: ${_itemName(capsuleItems, 5)}, ${_itemName(capsuleItems, 6)}, ${_itemName(capsuleItems, 7)}. Restyle them.',
      suggestedItemIds: capsuleItems.skip(5).take(3).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 14,
      title: 'Two-Week Wrap',
      description: 'Combine your most-worn + least-worn items: ${_itemName(capsuleItems, 0)} + ${_itemName(capsuleItems.reversed.toList(), 0)}.',
      suggestedItemIds: [
        if (capsuleItems.isNotEmpty) capsuleItems[0].id,
        if (capsuleItems.length > 1) capsuleItems.last.id,
      ],
    ),
    DailyChallenge(
      dayNumber: 15,
      title: 'Evening Edit',
      description: 'Style a party look using only 3 capsule items: ${_itemName(tops, 0)} + ${_itemName(bottoms, 0)} + ${_findColor(accessories, accentHex)}.',
      suggestedItemIds: [
        if (tops.isNotEmpty) tops[0].id,
        if (bottoms.isNotEmpty) bottoms[0].id,
        if (accessories.isNotEmpty) accessories[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 16,
      title: 'Neutral + Bold Pop',
      description: 'Wear ${_findNeutral(capsuleItems)} + make ${_findColorName(capsuleItems, primaryHex)} the hero piece. Let that colour pop.',
      suggestedItemIds: [
        if (capsuleItems.isNotEmpty) capsuleItems[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 17,
      title: 'Shoe Swap',
      description: 'Wear the same outfit with 2 different shoe styles from your capsule: ${_itemName(shoesList, 0)} then ${_itemName(shoesList, 1)}.',
      suggestedItemIds: shoesList.take(2).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 18,
      title: 'Warm vs Cool',
      description: 'Identify warm vs cool tones in your $season palette. Style ${_findColorName(capsuleItems, primaryHex)} with a warm-toned ${_itemName(tops, 2)}.',
      suggestedItemIds: capsuleItems.take(3).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 19,
      title: 'Outerwear Hero',
      description: 'Make ${_itemName(outers, 0)} the focal point. Layer it over ${_itemName(tops, 0)} in a complementary palette colour.',
      suggestedItemIds: [
        if (outers.isNotEmpty) outers[0].id,
        if (tops.isNotEmpty) tops[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 20,
      title: 'Print & Palette',
      description: 'Hold your capsule items next to your palette. Note which items share hues with $primaryHex, $secondaryHex, $accentHex.',
      suggestedItemIds: capsuleItems.map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 21,
      title: '3×3×3 Remix',
      description: 'Using 3 tops, 3 bottoms, 3 accessories — create 3 different outfits. Use ${_itemName(tops, 0)}, ${_itemName(bottoms, 0)}, ${_itemName(accessories, 0)}.',
      suggestedItemIds: [
        ...tops.take(3).map((i) => i.id),
        ...bottoms.take(3).map((i) => i.id),
        ...accessories.take(3).map((i) => i.id),
      ],
    ),
    DailyChallenge(
      dayNumber: 22,
      title: 'Travel Capsule',
      description: 'Pack 10 capsule items for a 5-day trip. Include ${_itemName(tops, 0)}, ${_itemName(bottoms, 0)}, ${_itemName(shoesList, 0)}. All must fit $season.',
      suggestedItemIds: capsuleItems.take(10).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 23,
      title: '60-30-10 Rule',
      description: 'Wear your primary colour $primaryHex on 60% of your body, secondary $secondaryHex on 30%, accent $accentHex on 10%.',
      suggestedItemIds: [
        if (tops.isNotEmpty) tops[0].id,
        if (bottoms.isNotEmpty) bottoms[0].id,
        if (accessories.isNotEmpty) accessories[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 24,
      title: 'Capsule Gap Hunt',
      description: 'Review your 30 capsule items. What palette colour is missing? Find one item (borrow/thrift) that fills that gap in $primaryHex range.',
      suggestedItemIds: capsuleItems.take(5).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 25,
      title: 'New Silhouette',
      description: 'Try a silhouette you normally avoid, using capsule items. Pair ${_itemName(tops, 0)} with ${_itemName(bottoms, 1)} in a way you have never worn before.',
      suggestedItemIds: [
        if (tops.isNotEmpty) tops[0].id,
        if (bottoms.length > 1) bottoms[1].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 26,
      title: 'Style A Friend',
      description: 'Using your $season knowledge, style a friend with your capsule items. Explain why each piece works for their tone.',
      suggestedItemIds: capsuleItems.take(5).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 27,
      title: 'Confidence Outfit',
      description: 'Create a no-validation-needed outfit. Wear your favourite capsule pieces: ${_itemName(tops, 0)} + ${_itemName(bottoms, 0)} + ${_itemName(shoesList, 0)}.',
      suggestedItemIds: [
        if (tops.isNotEmpty) tops[0].id,
        if (bottoms.isNotEmpty) bottoms[0].id,
        if (shoesList.isNotEmpty) shoesList[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 28,
      title: 'Colour Mood Story',
      description: 'Your $season palette creates a mood. Style an outfit that tells a story using $primaryHex (mood), $secondaryHex (contrast), $accentHex (surprise).',
      suggestedItemIds: capsuleItems.take(5).map((i) => i.id).toList(),
    ),
    DailyChallenge(
      dayNumber: 29,
      title: 'Future Look Plan',
      description: 'Plan 3 outfits for upcoming events. Must use: ${_itemName(tops, 0)}, ${_itemName(bottoms, 0)}, ${_itemName(shoesList, 0)}. Add missing items to wishlist.',
      suggestedItemIds: [
        if (tops.isNotEmpty) tops[0].id,
        if (bottoms.isNotEmpty) bottoms[0].id,
        if (shoesList.isNotEmpty) shoesList[0].id,
      ],
    ),
    DailyChallenge(
      dayNumber: 30,
      title: 'Graduation Day',
      description: 'Wear your favourite capsule outfit from these 30 days. Take a photo. You mastered the ${season} capsule — badge earned!',
      suggestedItemIds: capsuleItems.take(5).map((i) => i.id).toList(),
    ),
  ];
}

Map<String, List<ClosetItem>> _categorize(List<ClosetItem> items) {
  return {
    'top': items.where((i) => i.category == 'top').toList(),
    'bottom': items.where((i) => i.category == 'bottom').toList(),
    'outer': items.where((i) => i.category == 'outer').toList(),
    'shoes': items.where((i) => i.category == 'shoes').toList(),
    'accessory': items.where((i) => i.category == 'accessory').toList(),
  };
}
