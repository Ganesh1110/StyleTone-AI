import '../../models/user_profile.dart';
import '../../models/closet_item.dart';

class PromptBuilder {
  final UserProfile profile;
  final String? skinToneSeason;
  final List<ClosetItem> wardrobe;

  PromptBuilder({
    required this.profile,
    this.skinToneSeason,
    this.wardrobe = const [],
  });

  String buildSystemInstructions() {
    final buf = StringBuffer();
    buf.writeln('You are Style Coach, a personal fashion stylist AI.');
    buf.writeln();
    buf.writeln('Rules:');
    buf.writeln(
      '- Give concise, confident, and personalised fashion advice.',
    );
    buf.writeln('- Keep responses under 4 sentences unless asked for detail.');
    buf.writeln('- Be warm, encouraging, and practical.');
    buf.writeln('- Never give medical, health, or dermatological advice.');
    buf.writeln('- Be transparent that you are an AI stylist.');
    buf.writeln('- Do not guarantee specific results or make promises.');
    buf.writeln('- If you lack information, make reasonable assumptions and note them.');
    buf.writeln('- Format responses in plain text (no markdown, no bullet lists unless listing items).');
    return buf.toString();
  }

  String buildUserContext() {
    final buf = StringBuffer();
    buf.writeln('User context:');
    buf.writeln('- Age: ${profile.age}');
    buf.writeln('- Preferred style: ${profile.preferredStyle}');
    if (profile.hairColor != null) {
      buf.writeln('- Hair color: ${profile.hairColor}');
    }
    if (profile.eyeColor != null) {
      buf.writeln('- Eye color: ${profile.eyeColor}');
    }
    if (skinToneSeason != null) {
      buf.writeln('- Seasonal colour type: $skinToneSeason');
    }

    if (wardrobe.isNotEmpty) {
      buf.writeln();
      buf.writeln('Wardrobe:');
      final grouped = <String, List<ClosetItem>>{};
      for (final item in wardrobe) {
        grouped.putIfAbsent(item.category, () => []).add(item);
      }
      for (final entry in grouped.entries) {
        final items = entry.value
            .map((i) => '${i.colorName} ${i.category} (#${i.hexColor})')
            .join(', ');
        buf.writeln('- ${entry.key}: $items');
      }
    }
    return buf.toString();
  }

  static String outfitExplanationPrompt({
    required String item1Name,
    required String item1Color,
    required String item1Category,
    required String item2Name,
    required String item2Color,
    required String item2Category,
    String? accessoryName,
    String? accessoryColor,
    String? season,
    String? occasion,
  }) {
    final buf = StringBuffer();
    buf.write(
      'Explain why this $item1Color $item1Name ($item1Category) goes with '
      'this $item2Color $item2Name ($item2Category)',
    );
    if (accessoryName != null) {
      buf.write(' and $accessoryColor $accessoryName');
    }
    buf.write('.');
    if (occasion != null) buf.write(' Occasion: $occasion.');
    if (season != null) buf.write(' Season: $season.');
    buf.write(
      ' Mention colour harmony, style coherence, and skin tone suitability.'
      ' Keep it to 2-3 sentences.',
    );
    return buf.toString();
  }

  static String shoppingAdvicePrompt({
    required String itemName,
    required String itemColor,
    required String itemCategory,
    String? season,
    int wardrobeCount = 0,
  }) {
    return (
      'I am considering buying this $itemColor $itemName ($itemCategory). '
      'I have $wardrobeCount items in my wardrobe. '
      'Should I buy it? Give advice considering colour versatility, '
      'how it might fit my style, and wardrobe gaps. '
      'Keep it to 3 sentences.'
    );
  }

  static String rateOutfitPrompt({
    required String outfitDescription,
    String? occasion,
  }) {
    return (
      'Rate this outfit: $outfitDescription'
      '${occasion != null ? " for $occasion" : ""}. '
      'Give a score out of 10 and one sentence of feedback.'
    );
  }

  static String weeklyPackingPrompt({
    required String destination,
    required int days,
    required List<String> activities,
    required int wardrobeCount,
  }) {
    final activitiesStr = activities.join(', ');
    return (
      'Suggest a $days-day packing list for a trip to $destination. '
      'Activities: $activitiesStr. '
      'I have $wardrobeCount items in my wardrobe. '
      'List 5-8 essential items. Keep it brief.'
    );
  }
}
