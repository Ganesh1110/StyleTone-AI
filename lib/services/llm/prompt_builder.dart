import '../../models/user_profile.dart';
import '../../models/closet_item.dart';

class PromptBuilder {
  final UserProfile profile;
  final String? skinToneCategory;
  final String? skinToneSeason;
  final List<ClosetItem> wardrobe;

  PromptBuilder({
    required this.profile,
    this.skinToneCategory,
    this.skinToneSeason,
    this.wardrobe = const [],
  });

  String buildSystemPrompt() {
    final buf = StringBuffer();
    buf.writeln('You are Style Coach, a personal fashion stylist AI.');
    buf.writeln('You give concise, confident, and personalised fashion advice.');
    buf.writeln('Keep responses under 4 sentences unless asked for detail.');
    buf.writeln('Be warm, encouraging, and practical.');
    buf.writeln();
    buf.writeln('--- USER PROFILE ---');

    final gender = profile.gender;
    final age = profile.age;
    final style = profile.preferredStyle;

    if (gender != 'neutral') buf.writeln('Gender: $gender');
    buf.writeln('Age: $age');
    buf.writeln('Preferred style: $style');
    buf.writeln('Hair color: ${profile.hairColor ?? "unknown"}');
    buf.writeln('Eye color: ${profile.eyeColor ?? "unknown"}');

    if (skinToneCategory != null) {
      buf.writeln('Skin tone category: $skinToneCategory');
    }
    if (skinToneSeason != null) {
      buf.writeln('Seasonal colour type: $skinToneSeason');
    }

    if (wardrobe.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- WARDROBE INVENTORY ---');
      final grouped = <String, List<ClosetItem>>{};
      for (final item in wardrobe) {
        grouped.putIfAbsent(item.category, () => []).add(item);
      }
      for (final entry in grouped.entries) {
        final items = entry.value
            .map((i) => '${i.colorName} ${i.category} (#${i.hexColor})')
            .join(', ');
        buf.writeln('${entry.key}: $items');
      }
    }

    buf.writeln();
    buf.writeln(
      'Use the profile and wardrobe above to give personalised advice.',
    );
    buf.writeln(
      'If you lack information, make reasonable assumptions and note them.',
    );
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
