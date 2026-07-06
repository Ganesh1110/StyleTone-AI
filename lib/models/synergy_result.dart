/// Models for the Closet Synergy & Gap-Filler Engine (v2.0).

// ---------------------------------------------------------------------------
// GapFiller — a missing wardrobe category with a palette-recommended color
// ---------------------------------------------------------------------------
class GapFiller {
  final String category;
  final String categoryLabel;
  final String recommendedHex;
  final String recommendedColorName;
  final String reason;

  const GapFiller({
    required this.category,
    required this.categoryLabel,
    required this.recommendedHex,
    required this.recommendedColorName,
    required this.reason,
  });

  factory GapFiller.fromJson(Map<String, dynamic> json) {
    return GapFiller(
      category: json['category'] as String? ?? '',
      categoryLabel:
          json['category_label'] as String? ?? json['category'] as String? ?? '',
      recommendedHex: json['recommended_hex'] as String? ?? '#CCCCCC',
      recommendedColorName:
          json['recommended_color_name'] as String? ?? 'Neutral',
      reason: json['reason'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// OutfitCombo — a valid color pair between the new garment & a closet item
// ---------------------------------------------------------------------------
class OutfitCombo {
  final String newItemHex;
  final String existingItemHex;
  final String existingItemName;
  final String existingCategory;
  final int matchScore;
  final String comboType; // "Analogous" | "Contrasting"

  const OutfitCombo({
    required this.newItemHex,
    required this.existingItemHex,
    required this.existingItemName,
    required this.existingCategory,
    required this.matchScore,
    required this.comboType,
  });

  factory OutfitCombo.fromJson(Map<String, dynamic> json) {
    return OutfitCombo(
      newItemHex: json['new_item_hex'] as String? ?? '#CCCCCC',
      existingItemHex: json['existing_item_hex'] as String? ?? '#CCCCCC',
      existingItemName: json['existing_item_name'] as String? ?? 'Item',
      existingCategory: json['existing_category'] as String? ?? 'top',
      matchScore: json['match_score'] as int? ?? 50,
      comboType: json['combo_type'] as String? ?? 'Analogous',
    );
  }
}

// ---------------------------------------------------------------------------
// SynergyResult — top-level result from /analyze-synergy
// ---------------------------------------------------------------------------
class SynergyResult {
  final int synergyScore;
  final String newItemHex;
  final String newItemColorName;
  final List<String> matchedPaletteColors;
  final int newCombosCount;
  final List<OutfitCombo> newCombos;
  final List<GapFiller> gapFillers;

  const SynergyResult({
    required this.synergyScore,
    required this.newItemHex,
    required this.newItemColorName,
    required this.matchedPaletteColors,
    required this.newCombosCount,
    required this.newCombos,
    required this.gapFillers,
  });

  factory SynergyResult.fromJson(Map<String, dynamic> json) {
    return SynergyResult(
      synergyScore: json['synergy_score'] as int? ?? 0,
      newItemHex: json['new_item_hex'] as String? ?? '#CCCCCC',
      newItemColorName:
          json['new_item_color_name'] as String? ?? 'New Item',
      matchedPaletteColors:
          (json['matched_palette_colors'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
      newCombosCount: json['new_combos_count'] as int? ?? 0,
      newCombos: (json['new_combos'] as List<dynamic>?)
              ?.map((e) => OutfitCombo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      gapFillers: (json['gap_fillers'] as List<dynamic>?)
              ?.map((e) => GapFiller.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
