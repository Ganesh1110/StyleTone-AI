import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// 12-Season colour system – ported from image_processor.py
// Each subseason has anchor RGB samples representing skin-tone clusters.
// ---------------------------------------------------------------------------

const Map<String, String> _subbaseMap = {
  "Light Spring": "Spring",
  "Warm Spring": "Spring",
  "Bright Spring": "Spring",
  "Light Summer": "Summer",
  "Cool Summer": "Summer",
  "Soft Summer": "Summer",
  "Soft Autumn": "Autumn",
  "Warm Autumn": "Autumn",
  "Deep Autumn": "Autumn",
  "Deep Winter": "Winter",
  "Cool Winter": "Winter",
  "Bright Winter": "Winter",
};

const Map<String, List<String>> _styleArchetypes = {
  "Light Spring": ["The Warm Minimalist", "Delicate warmth with an airy, understated elegance. Think soft luminosity, not loud colour."],
  "Warm Spring": ["The Golden Hour", "Sun-kissed and approachable. Your palette glows with honeyed warmth and cheerful energy."],
  "Bright Spring": ["The Vibrant Optimist", "Bold, clear, and saturated. You radiate confidence and a playful zest for life."],
  "Light Summer": ["The Ethereal Cool", "Graceful, muted, and serene. Your look whispers refinement with a cool, misty palette."],
  "Cool Summer": ["The Elegant Rose", "True cool composure. Dusty pinks and steel blues create a quietly powerful, polished presence."],
  "Soft Summer": ["The Smoky Classic", "Muted sophistication with a hint of mystery. Greyed tones give you an understated, timeless edge."],
  "Soft Autumn": ["The Earthy Minimalist", "Subtle warmth grounded in nature. Olive, clay, and taupe speak a quiet, confident language."],
  "Warm Autumn": ["The Amber Glow", "Rich, golden, and deeply warm. Terracotta and mustard tell a story of harvest abundance."],
  "Deep Autumn": ["The Forest Depth", "Dark, opulent, and grounded. Espresso, rust, and pine project strength without shouting."],
  "Deep Winter": ["The Dark Luxe", "High-contrast depth with icy edge. Midnight and charcoal create a commanding, dramatic silhouette."],
  "Cool Winter": ["The Ice Queen", "Crystal-clear cool that stops the room. Royal blue and emerald demand attention with precision."],
  "Bright Winter": ["The Electric Edge", "Brilliant, chromatic, and fearless. Hot pink and electric blue are your superpowers."],
};

const Map<String, List<List<int>>> _seasonAnchorsRgb = {
  "Light Spring": [
    [250, 225, 195],
    [248, 218, 185],
    [245, 230, 210],
    [255, 235, 205],
    [240, 220, 190],
  ],
  "Warm Spring": [
    [240, 200, 155],
    [235, 195, 145],
    [225, 185, 135],
    [248, 213, 177],
    [230, 190, 148],
  ],
  "Bright Spring": [
    [235, 195, 145],
    [220, 175, 120],
    [240, 205, 165],
    [210, 170, 110],
    [228, 184, 137],
  ],
  "Light Summer": [
    [240, 220, 210],
    [236, 213, 197],
    [245, 230, 225],
    [230, 210, 200],
    [250, 240, 245],
  ],
  "Cool Summer": [
    [225, 200, 190],
    [215, 190, 180],
    [220, 200, 190],
    [210, 185, 175],
    [230, 210, 200],
  ],
  "Soft Summer": [
    [210, 190, 180],
    [200, 180, 170],
    [195, 175, 165],
    [215, 195, 185],
    [205, 185, 175],
  ],
  "Soft Autumn": [
    [195, 150, 105],
    [185, 140, 95],
    [190, 145, 100],
    [200, 155, 110],
    [180, 135, 90],
  ],
  "Warm Autumn": [
    [185, 135, 85],
    [172, 122, 75],
    [165, 115, 68],
    [190, 140, 90],
    [178, 128, 80],
  ],
  "Deep Autumn": [
    [155, 105, 60],
    [145, 95, 55],
    [133, 84, 46],
    [160, 110, 60],
    [140, 90, 50],
  ],
  "Deep Winter": [
    [110, 75, 52],
    [90, 60, 40],
    [80, 55, 40],
    [120, 81, 57],
    [100, 70, 50],
  ],
  "Cool Winter": [
    [174, 144, 118],
    [155, 125, 100],
    [200, 180, 165],
    [165, 135, 110],
    [185, 160, 140],
  ],
  "Bright Winter": [
    [240, 235, 230],
    [250, 244, 240],
    [230, 220, 215],
    [245, 240, 235],
    [235, 225, 220],
  ],
};

const Map<String, Map<String, dynamic>> _seasonPalettes = {
  "Light Spring": {
    "office": ["#C28E75", "#E8D5B7", "#7BA898"],
    "party": ["#FF9B7A", "#FFE066", "#5BA89B"],
    "casual": ["#F0B89A", "#FFF5E0", "#7FC9B6"],
    "explanation_undertone": "warm golden/peach — light value",
    "season_descr": "Delicate, warm colouring with light skin. Soft coral, buttercream, and dusty teal bring out your gentle golden glow without overwhelming your fair features.",
    "makeup_palette": {
      "lip": ["#FF9B7A", "#F0B89A", "#E8A87C"],
      "eye": ["#D4C5A9", "#B8A98A", "#A8C5B0"],
      "cheek": ["#F5C8B0", "#F0B89A", "#E8C4A0"],
      "nail": ["#FFBFA0", "#F5E0C0", "#C0D6C8"],
    },
    "hair_color_palette": ["#C4A882", "#B8976A", "#D4BFA0", "#A08060", "#E8D5B7"],
    "colors_to_avoid": ["#1A1A2E", "#800020", "#4A0E4E", "#2F4F4F", "#000000", "#8B0000", "#191970"],
  },
  "Warm Spring": {
    "office": ["#C28E75", "#D6C5A8", "#477876"],
    "party": ["#FF7F50", "#FFD700", "#008080"],
    "casual": ["#E9967A", "#F5F5DC", "#20B2AA"],
    "explanation_undertone": "warm golden/peach — medium saturation",
    "season_descr": "Your skin radiates soft, golden warmth. Pastel oranges, bright cream, and warm teals will look exceptionally luminous on you.",
    "makeup_palette": {
      "lip": ["#FF7F50", "#E05A47", "#FF9B7A"],
      "eye": ["#D4A858", "#C49A3C", "#A8B89A"],
      "cheek": ["#F0A070", "#E88A60", "#F5C0A0"],
      "nail": ["#FF9955", "#E8C840", "#80B8A0"],
    },
    "hair_color_palette": ["#B8824A", "#A07040", "#C89860", "#D4B080", "#8A6840"],
    "colors_to_avoid": ["#4A4A7A", "#2E1A47", "#1A1A3E", "#3A2A5E", "#6B3A5E", "#0A0A2E", "#5A3A6A"],
  },
  "Bright Spring": {
    "office": ["#D4885A", "#E8D5A0", "#2A9A7A"],
    "party": ["#FF6B40", "#FFD700", "#00A080"],
    "casual": ["#FF8A6A", "#FFF0C0", "#30B8A0"],
    "explanation_undertone": "warm golden/peach — high chroma",
    "season_descr": "Clear, warm colouring with bright contrast. Vivid coral, sunny yellow, and vibrant teal match your energetic, luminous presence.",
    "makeup_palette": {
      "lip": ["#FF6B40", "#FF4500", "#FF8A6A"],
      "eye": ["#D4B050", "#C0A040", "#80B090"],
      "cheek": ["#FF8A5A", "#F07040", "#FFB080"],
      "nail": ["#FF6030", "#FFD700", "#20A880"],
    },
    "hair_color_palette": ["#A06830", "#8A5828", "#B87840", "#C89858", "#785028"],
    "colors_to_avoid": ["#3A3A6A", "#2A1A5E", "#4A3A7A", "#1A1A4E", "#6A3A5A", "#0E0E3A", "#5A2A6A"],
  },
  "Light Summer": {
    "office": ["#B08B9E", "#A8B0C0", "#8AA0A8"],
    "party": ["#DA8A9F", "#B0A0D0", "#7A98B8"],
    "casual": ["#E8B0C0", "#D0D8E8", "#90B0B8"],
    "explanation_undertone": "cool rosy/pink — light value",
    "season_descr": "Your skin features soft, rosy undertones with light value. Dusty rose pinks, soft lavenders, and cool slate grays will enhance your elegant, cool contrast.",
    "makeup_palette": {
      "lip": ["#DA8A9F", "#C890A8", "#E0A0B8"],
      "eye": ["#A8B0C0", "#9098A8", "#B0C0C8"],
      "cheek": ["#E8B0C0", "#D0A0B0", "#F0C0D0"],
      "nail": ["#E0A0B8", "#C8C8D8", "#A0B8C0"],
    },
    "hair_color_palette": ["#C8B8A0", "#B8A890", "#D8C8B0", "#A89880", "#E0D0C0"],
    "colors_to_avoid": ["#FF4500", "#FF8C00", "#FFD700", "#FF6347", "#FFA500", "#8B4513", "#D2691E"],
  },
  "Cool Summer": {
    "office": ["#9A7A8A", "#607080", "#5A7A7A"],
    "party": ["#C87A9A", "#7A70B0", "#4070A0"],
    "casual": ["#D090A8", "#B0B8D0", "#608090"],
    "explanation_undertone": "cool rosy/pink — medium value",
    "season_descr": "True cool undertones with a refined, elegant cast. Muted burgundy, steel gray, and dusty blue harmonise with your natural coolness.",
    "makeup_palette": {
      "lip": ["#C87A9A", "#B06888", "#D088A8"],
      "eye": ["#808890", "#687080", "#A0A8B0"],
      "cheek": ["#D090A8", "#C08098", "#E0A0B8"],
      "nail": ["#C87A9A", "#8888B0", "#7098A8"],
    },
    "hair_color_palette": ["#A09080", "#8A7A6A", "#B8A898", "#7A6A5A", "#C8B8A8"],
    "colors_to_avoid": ["#FF6633", "#FF9933", "#FFCC00", "#FF7043", "#FFA040", "#A0522D", "#CD853F"],
  },
  "Soft Summer": {
    "office": ["#8A7A82", "#687878", "#6A7A7A"],
    "party": ["#B07A8A", "#7A78A0", "#607890"],
    "casual": ["#C08A98", "#A0A0B8", "#788888"],
    "explanation_undertone": "cool rosy/pink — muted",
    "season_descr": "Muted, gentle cool tones with a smoky quality. Dusty mauve, grayed teal, and soft heather suit your understated elegance.",
    "makeup_palette": {
      "lip": ["#B07A8A", "#9A6878", "#C08A98"],
      "eye": ["#788080", "#686868", "#889090"],
      "cheek": ["#C08A98", "#A87888", "#D098A8"],
      "nail": ["#B07A8A", "#8888A0", "#789090"],
    },
    "hair_color_palette": ["#8A8278", "#7A7268", "#9A9288", "#6A6258", "#A8A098"],
    "colors_to_avoid": ["#FF5500", "#FFAA00", "#FFCC33", "#FF7733", "#FFB347", "#B86500", "#D4872A"],
  },
  "Soft Autumn": {
    "office": ["#8A5E38", "#7A8A5A", "#B8A07A"],
    "party": ["#C07A50", "#9A8A30", "#5A8A5A"],
    "casual": ["#C08A5A", "#A8A880", "#8AA08A"],
    "explanation_undertone": "warm bronze/honey — muted",
    "season_descr": "Earthy, muted warmth with olive undertones. Clay brown, sage green, and warm taupe frame your natural subtle glow.",
    "makeup_palette": {
      "lip": ["#C07A50", "#A86840", "#D08860"],
      "eye": ["#8A7A60", "#7A6A50", "#9A8A70"],
      "cheek": ["#C08A5A", "#A87848", "#D09868"],
      "nail": ["#C07A50", "#9A8A50", "#7A9A7A"],
    },
    "hair_color_palette": ["#6A5040", "#5A4030", "#7A6050", "#4A3828", "#8A7060"],
    "colors_to_avoid": ["#FF69B4", "#FFB6C1", "#FFC0CB", "#E6E6FA", "#DDA0DD", "#DA70D6", "#EE82EE"],
  },
  "Warm Autumn": {
    "office": ["#8A5E38", "#556B2F", "#C2A67D"],
    "party": ["#E05A47", "#B8860B", "#2E8B57"],
    "casual": ["#D2691E", "#8FBC8F", "#F5F5DC"],
    "explanation_undertone": "warm bronze/honey — medium saturation",
    "season_descr": "You have rich golden undertones and deep features. Terracotta, mustard gold, and earthy olive greens complement your natural warmth perfectly.",
    "makeup_palette": {
      "lip": ["#E05A47", "#C84A38", "#D06848"],
      "eye": ["#8A7050", "#7A6040", "#9A8060"],
      "cheek": ["#D07A4A", "#C06838", "#D88858"],
      "nail": ["#C85A38", "#B89030", "#4A8A4A"],
    },
    "hair_color_palette": ["#5A4030", "#4A3020", "#6A5040", "#3A2818", "#7A6050"],
    "colors_to_avoid": ["#FF1493", "#FF69B4", "#DB7093", "#FFB6C1", "#FFC0CB", "#E6E6FA", "#DDA0DD"],
  },
  "Deep Autumn": {
    "office": ["#6A4030", "#4A6030", "#9A8060"],
    "party": ["#C84A30", "#8A7000", "#2A6A3A"],
    "casual": ["#A85830", "#6A8A5A", "#C8B090"],
    "explanation_undertone": "warm bronze/honey — deep value",
    "season_descr": "Deep, rich warmth with strong golden undertones. Rust red, olive green, and warm chocolate bring out your dramatic depth.",
    "makeup_palette": {
      "lip": ["#C84A30", "#B03828", "#D05840"],
      "eye": ["#6A5840", "#5A4830", "#7A6850"],
      "cheek": ["#A85830", "#984828", "#B86840"],
      "nail": ["#C84A30", "#7A6830", "#3A7A4A"],
    },
    "hair_color_palette": ["#3A2820", "#2A1A10", "#4A3830", "#1A1008", "#5A4840"],
    "colors_to_avoid": ["#FFB6C1", "#FFC0CB", "#E6E6FA", "#D8BFD8", "#FFD700", "#00FFFF", "#FF00FF"],
  },
  "Deep Winter": {
    "office": ["#1F3A60", "#0E5033", "#4A4A4A"],
    "party": ["#3050C0", "#008050", "#A04060"],
    "casual": ["#3A5880", "#206040", "#585858"],
    "explanation_undertone": "cool high-contrast — deep value",
    "season_descr": "Striking cool undertones with deep, rich colouring. Midnight blue, pine green, and charcoal create your powerful dark palette.",
    "makeup_palette": {
      "lip": ["#A04060", "#882850", "#B84870"],
      "eye": ["#404860", "#383850", "#505870"],
      "cheek": ["#804860", "#703850", "#905870"],
      "nail": ["#A04060", "#3040A0", "#207050"],
    },
    "hair_color_palette": ["#1A1010", "#0A0808", "#2A2020", "#000000", "#3A3030"],
    "colors_to_avoid": ["#FFD700", "#FFA500", "#FF8C00", "#FF6347", "#F4A460", "#CD853F", "#D2691E"],
  },
  "Cool Winter": {
    "office": ["#2A4070", "#1A5A40", "#3A5080"],
    "party": ["#4060D0", "#208058", "#B04870"],
    "casual": ["#4A6A90", "#387050", "#606878"],
    "explanation_undertone": "cool high-contrast — clear cool",
    "season_descr": "True cool, clear colouring with icy clarity. Royal blue, emerald green, and vivid ruby red make you stand out beautifully.",
    "makeup_palette": {
      "lip": ["#B04870", "#983060", "#C05880"],
      "eye": ["#506080", "#485070", "#607090"],
      "cheek": ["#905870", "#804860", "#A06880"],
      "nail": ["#B04870", "#4050B8", "#308068"],
    },
    "hair_color_palette": ["#2A2020", "#1A1010", "#3A3030", "#0A0808", "#4A4040"],
    "colors_to_avoid": ["#FFD700", "#FFA500", "#FF8C00", "#F4A460", "#CD853F", "#D2691E", "#B8860B"],
  },
  "Bright Winter": {
    "office": ["#2A4890", "#206848", "#4A5A80"],
    "party": ["#3058E0", "#009868", "#C85080"],
    "casual": ["#5078A8", "#489070", "#687090"],
    "explanation_undertone": "cool high-contrast — bright/chromatic",
    "season_descr": "Cool, brilliant colouring with dramatic contrast. Electric blue, vivid emerald, and hot pink match your bold, icy presence.",
    "makeup_palette": {
      "lip": ["#C85080", "#B03868", "#D86090"],
      "eye": ["#607898", "#586888", "#7088A8"],
      "cheek": ["#A06880", "#905870", "#B07890"],
      "nail": ["#C85080", "#3860D0", "#28A078"],
    },
    "hair_color_palette": ["#1A1018", "#0A0808", "#2A2030", "#181020", "#3A3040"],
    "colors_to_avoid": ["#FFD700", "#FFA500", "#FF8C00", "#CD853F", "#D2691E", "#B8860B", "#8B4513"],
  },
};

const Map<String, String> _skinToneLabels = {
  "Light Spring": "Light Spring — Warm Golden/Peach (Light)",
  "Warm Spring": "Warm Spring — Warm Golden/Peach (True Warm)",
  "Bright Spring": "Bright Spring — Warm Golden/Peach (Bright)",
  "Light Summer": "Light Summer — Cool Rosy/Pink (Light)",
  "Cool Summer": "Cool Summer — Cool Rosy/Pink (True Cool)",
  "Soft Summer": "Soft Summer — Cool Rosy/Pink (Soft)",
  "Soft Autumn": "Soft Autumn — Warm Bronze/Honey (Soft)",
  "Warm Autumn": "Warm Autumn — Warm Bronze/Honey (True Warm)",
  "Deep Autumn": "Deep Autumn — Warm Bronze/Honey (Deep)",
  "Deep Winter": "Deep Winter — Cool High-Contrast (Deep)",
  "Cool Winter": "Cool Winter — Cool High-Contrast (True Cool)",
  "Bright Winter": "Bright Winter — Cool High-Contrast (Bright)",
};

// ---------------------------------------------------------------------------
// Colour-space conversions (CIE L*a*b* with D65 illuminant)
// ---------------------------------------------------------------------------
double _linearizeSrgb(double c) {
  if (c <= 0.04045) return c / 12.92;
  return pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _labF(double t) {
  const double delta = 6.0 / 29.0;
  const double delta3 = delta * delta * delta;
  if (t > delta3) return pow(t, 1.0 / 3.0).toDouble();
  return t / (3.0 * delta * delta) + 4.0 / 29.0;
}

List<double> rgbToLab(int r, int g, int b) {
  final rLin = _linearizeSrgb(r / 255.0);
  final gLin = _linearizeSrgb(g / 255.0);
  final bLin = _linearizeSrgb(b / 255.0);

  // XYZ (D65)
  final x = rLin * 0.4124564 + gLin * 0.3575761 + bLin * 0.1804375;
  final y = rLin * 0.2126729 + gLin * 0.7151522 + bLin * 0.0721750;
  final z = rLin * 0.0193339 + gLin * 0.1191920 + bLin * 0.9503041;

  final fx = _labF(x / 0.95047);
  final fy = _labF(y / 1.00000);
  final fz = _labF(z / 1.08883);

  return [
    116.0 * fy - 16.0,
    500.0 * (fx - fy),
    200.0 * (fy - fz),
  ];
}

List<double> _rgbToHsv(int r, int g, int b) {
  final rn = r / 255.0;
  final gn = g / 255.0;
  final bn = b / 255.0;
  final mx = max(rn, max(gn, bn));
  final mn = min(rn, min(gn, bn));
  final d = mx - mn;

  double h = 0.0;
  final s = mx == 0.0 ? 0.0 : d / mx;
  final v = mx;

  if (d != 0.0) {
    if (mx == rn) {
      h = 60.0 * (((gn - bn) / d) % 6);
    } else if (mx == gn) {
      h = 60.0 * (((bn - rn) / d) + 2);
    } else {
      h = 60.0 * (((rn - gn) / d) + 4);
    }
  }
  return [h, s, v];
}

// ---------------------------------------------------------------------------
// CIEDE2000 colour-difference (Sharma, Wu & Dalal 2005)
// ---------------------------------------------------------------------------
double deltaE2000(List<double> lab1, List<double> lab2) {
  final L1 = lab1[0], a1 = lab1[1], b1 = lab1[2];
  final L2 = lab2[0], a2 = lab2[1], b2 = lab2[2];

  final C1 = sqrt(a1 * a1 + b1 * b1);
  final C2 = sqrt(a2 * a2 + b2 * b2);
  final CBar = (C1 + C2) / 2.0;

  final CBar7 = pow(CBar, 7).toDouble();
  final G = 0.5 * (1.0 - sqrt(CBar7 / (CBar7 + pow(25, 7).toDouble())));

  final a1p = a1 * (1.0 + G);
  final a2p = a2 * (1.0 + G);

  final C1p = sqrt(a1p * a1p + b1 * b1);
  final C2p = sqrt(a2p * a2p + b2 * b2);

  double hp(double a, double b) {
    if (a == 0.0 && b == 0.0) return 0.0;
    final h = atan2(b, a) * 180 / pi;
    return h >= 0.0 ? h : h + 360.0;
  }

  final h1p = hp(a1p, b1);
  final h2p = hp(a2p, b2);

  final dLp = L2 - L1;
  final dCp = C2p - C1p;

  double dhp;
  if (C1p * C2p == 0.0) {
    dhp = 0.0;
  } else {
    dhp = h2p - h1p;
    if (dhp > 180.0) {
      dhp -= 360.0;
    } else if (dhp < -180.0) {
      dhp += 360.0;
    }
  }

  final dHp = 2.0 * sqrt(C1p * C2p) * sin(dhp / 2.0 * pi / 180);

  final LBar = (L1 + L2) / 2.0;
  final SL = 1.0 +
      0.015 * pow(LBar - 50.0, 2) /
          sqrt(20.0 + pow(LBar - 50.0, 2));

  final CpBar = (C1p + C2p) / 2.0;
  final SC = 1.0 + 0.045 * CpBar;

  double hBar;
  if (C1p * C2p == 0.0) {
    hBar = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180.0) {
    hBar = (h1p + h2p) / 2.0;
  } else if ((h1p + h2p) < 360.0) {
    hBar = (h1p + h2p + 360.0) / 2.0;
  } else {
    hBar = (h1p + h2p - 360.0) / 2.0;
  }

  final T = 1.0 -
      0.17 * cos((hBar - 30.0) * pi / 180) +
      0.24 * cos(2.0 * hBar * pi / 180) +
      0.32 * cos((3.0 * hBar + 6.0) * pi / 180) -
      0.20 * cos((4.0 * hBar - 63.0) * pi / 180);

  final SH = 1.0 + 0.015 * CpBar * T;

  final dtheta = 30.0 * exp(-pow((hBar - 275.0) / 25.0, 2));
  final CpBar7 = pow(CpBar, 7).toDouble();
  final RC = 2.0 * sqrt(CpBar7 / (CpBar7 + pow(25, 7).toDouble()));
  final RT = -RC * sin(2.0 * dtheta * pi / 180);

  return sqrt(
    pow(dLp / SL, 2) +
        pow(dCp / SC, 2) +
        pow(dHp / SH, 2) +
        RT * (dCp / SC) * (dHp / SH),
  );
}

// ---------------------------------------------------------------------------
// K-Means (Lloyd's algorithm)
// ---------------------------------------------------------------------------
({List<List<double>> centroids, List<int> labels, List<int> counts}) kMeans(
  List<List<int>> pixels,
  int k, {
  int maxIter = 20,
}) {
  final n = pixels.length;
  final centers = List.generate(k, (i) {
    final p = pixels[i.clamp(0, n - 1)];
    return [p[0].toDouble(), p[1].toDouble(), p[2].toDouble()];
  });
  final labels = List.filled(n, 0);

  for (int iter = 0; iter < maxIter; iter++) {
    bool changed = false;
    for (int i = 0; i < n; i++) {
      final p = pixels[i];
      var minDist = double.infinity;
      var best = 0;
      for (int j = 0; j < k; j++) {
        final c = centers[j];
        final d = (p[0] - c[0]) * (p[0] - c[0]) +
            (p[1] - c[1]) * (p[1] - c[1]) +
            (p[2] - c[2]) * (p[2] - c[2]);
        if (d < minDist) {
          minDist = d;
          best = j;
        }
      }
      if (labels[i] != best) {
        labels[i] = best;
        changed = true;
      }
    }
    if (!changed) break;

    final sums = List.generate(k, (_) => [0.0, 0.0, 0.0]);
    final cnts = List.filled(k, 0);
    for (int i = 0; i < n; i++) {
      final l = labels[i];
      sums[l][0] += pixels[i][0].toDouble();
      sums[l][1] += pixels[i][1].toDouble();
      sums[l][2] += pixels[i][2].toDouble();
      cnts[l]++;
    }
    for (int j = 0; j < k; j++) {
      if (cnts[j] > 0) {
        centers[j][0] = sums[j][0] / cnts[j];
        centers[j][1] = sums[j][1] / cnts[j];
        centers[j][2] = sums[j][2] / cnts[j];
      }
    }
  }

  final cnts = List.filled(k, 0);
  for (final l in labels) {
    cnts[l]++;
  }

  return (centroids: centers, labels: labels, counts: cnts);
}

// ---------------------------------------------------------------------------
// Skin segmentation (HSV + YCrCb dual-mask, ported from image_processor.py)
// ---------------------------------------------------------------------------
({List<List<int>> skinPixels, int count}) _segmentSkin(img.Image image) {
  final skin = <List<int>>[];
  final w = image.width;
  final h = image.height;

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      // HSV check (OpenCV-style: H/2, S*255, V*255)
      final hsv = _rgbToHsv(r, g, b);
      final hCv = (hsv[0] / 2).round();
      final sCv = (hsv[1] * 255).round();
      final vCv = (hsv[2] * 255).round();
      final inHsv = hCv >= 0 && hCv <= 20 && sCv >= 20 && sCv <= 150 && vCv >= 20;

      // YCrCb check (OpenCV COLORMAP_BGR2YCrCb)
      final yC = 0.299 * r + 0.587 * g + 0.114 * b;
      final cr = (r - yC) * 0.713 + 128;
      final cb = (b - yC) * 0.564 + 128;
      final inYCrCb = yC >= 0 && cr >= 133 && cr <= 173 && cb >= 77 && cb <= 127;

      if (inHsv && inYCrCb) {
        skin.add([r, g, b]);
      }
    }
  }

  return (skinPixels: skin, count: skin.length);
}

// ---------------------------------------------------------------------------
// Best-cluster selection (L* penalty + chroma prior)
// ---------------------------------------------------------------------------
List<int>? _selectBestCluster(
  List<List<double>> centroids,
  List<int> counts,
  int total,
) {
  double bestScore = -1.0;
  List<int>? bestRgb;

  for (int i = 0; i < centroids.length; i++) {
    final rgb = centroids[i];
    final r = rgb[0].round();
    final g = rgb[1].round();
    final b = rgb[2].round();
    final lab = rgbToLab(r, g, b);
    final lStar = lab[0];
    final aStar = lab[1];
    final bStar = lab[2];

    final clusterRatio = counts[i] / total;

    double lPenalty = 1.0;
    if (lStar > 74.5) {
      lPenalty = max(0.0, 1.0 - (lStar - 74.5) / 7.8);
    } else if (lStar < 19.6) {
      lPenalty = max(0.0, 1.0 - (19.6 - lStar) / 9.8);
    }

    double chromaPrior = 1.0;
    if (aStar > 2.0 && bStar > 2.0) {
      chromaPrior = 1.2;
    }

    final score = clusterRatio * lPenalty * chromaPrior;
    if (score > bestScore) {
      bestScore = score;
      bestRgb = [r, g, b];
    }
  }

  return bestRgb;
}

// ---------------------------------------------------------------------------
// Seasonal classification
// ---------------------------------------------------------------------------
Map<String, double> _classifySeason(List<double> skinLab) {
  final distances = <String, double>{};
  for (final entry in _seasonAnchorsRgb.entries) {
    var minDist = double.infinity;
    for (final anchorRgb in entry.value) {
      final anchorLab = rgbToLab(anchorRgb[0], anchorRgb[1], anchorRgb[2]);
      final d = deltaE2000(skinLab, anchorLab);
      if (d < minDist) minDist = d;
    }
    distances[entry.key] = minDist;
  }
  return distances;
}

// ---------------------------------------------------------------------------
// Lightness description (ported with L*→true L*a*b* threshold conversion)
// ---------------------------------------------------------------------------
String _describeLightness(double lStar) {
  if (lStar > 74.5) return "fair porcelain";
  if (lStar > 54.9) return "light";
  if (lStar > 37.3) return "medium/tan";
  return "deep/rich";
}

// ---------------------------------------------------------------------------
// Skin-tone palette adjustment
// ---------------------------------------------------------------------------
String _adjustForSkinTone(String hexColor, double lStar) {
  final hex = hexColor.replaceFirst('#', '');
  final r = int.parse(hex.substring(0, 2), radix: 16);
  final g = int.parse(hex.substring(2, 4), radix: 16);
  final b = int.parse(hex.substring(4, 6), radix: 16);

  final hsv = _rgbToHsv(r, g, b);
  var h = hsv[0];
  var s = hsv[1];
  var v = hsv[2];

  if (lStar < 37.3) {
    s = min(1.0, s * 1.3);
    v = min(1.0, v * 1.25);
  } else if (lStar < 54.9) {
    s = min(1.0, s * 1.1);
    v = min(1.0, v * 1.1);
  } else if (lStar > 74.5) {
    s = max(0.25, s * 0.7);
    v = max(0.35, v * 0.85);
  } else {
    s = max(0.3, s * 0.85);
    v = max(0.4, v * 0.95);
  }

  // HSV → RGB
  final hh = (h / 60.0) % 6.0;
  final hi = hh.floor();
  final f = hh - hi;
  final pv = v * (1.0 - s);
  final qv = v * (1.0 - s * f);
  final tv = v * (1.0 - s * (1.0 - f));

  double rr, gg, bb;
  switch (hi) {
    case 0:
      rr = v; gg = tv; bb = pv; break;
    case 1:
      rr = qv; gg = v; bb = pv; break;
    case 2:
      rr = pv; gg = v; bb = tv; break;
    case 3:
      rr = pv; gg = qv; bb = v; break;
    case 4:
      rr = tv; gg = pv; bb = v; break;
    default:
      rr = v; gg = pv; bb = qv; break;
  }

  final outR = (rr * 255).round().clamp(0, 255);
  final outG = (gg * 255).round().clamp(0, 255);
  final outB = (bb * 255).round().clamp(0, 255);

  return '#${outR.toRadixString(16).padLeft(2, '0')}'
      '${outG.toRadixString(16).padLeft(2, '0')}'
      '${outB.toRadixString(16).padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Stylist tips (gender-neutral for offline — user can add gender later)
// ---------------------------------------------------------------------------
String _getGenderedStylistTip(String detectedSeason, String occasion, String gender) {
  final g = gender.toLowerCase();
  if (g == "male") {
    if (occasion == "office") {
      return "$detectedSeason Office Style: Muted, professional tones. Pair a primary-colored suit or blazer with clean tailored trousers, a subtle accent tie, and a brown leather watch strap.";
    } else if (occasion == "party") {
      return "$detectedSeason Party Look: Bold, high-contrast styling. Rock a primary-colored sports coat over a dark shirt, accented with a pocketsquare and matching watch straps.";
    } else {
      return "$detectedSeason Casual: Relaxed, natural shades. Try a casual knit sweater in your primary color combined with dark denim and classic leather boots.";
    }
  } else if (g == "female") {
    if (occasion == "office") {
      return "$detectedSeason Office Style: Muted, professional tones. Wear a structured primary blazer over a neutral blouse, paired with delicate gold or silver jewelry and a matching handbag.";
    } else if (occasion == "party") {
      return "$detectedSeason Party Look: Vibrant, high-contrast styling. Let your primary color shine on a gorgeous dress or bold top, accessorized with statement earrings and bronze makeup accents.";
    } else {
      return "$detectedSeason Casual: Relaxed, natural shades. Layer a primary-colored oversized cardigan or jacket over light linens, completed with amber or leather accessories.";
    }
  } else {
    if (occasion == "office") {
      return "$detectedSeason Office Style: Muted, professional tones that project polished confidence and balanced coordination.";
    } else if (occasion == "party") {
      return "$detectedSeason Party Look: Vibrant, high-contrast palette styled to command attention and make a memorable statement.";
    } else {
      return "$detectedSeason Casual: Relaxed, natural shades curated for everyday comfort and clean color harmony.";
    }
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Run the full skin-tone analysis pipeline on-device.
///
/// Returns the same Map shape as the `/recommend` API endpoint, or `null`
/// if the analysis cannot be completed (e.g. no skin pixels found).
Future<Map<String, dynamic>?> processSelfie(img.Image image, {String gender = "neutral"}) async {
  try {
    final (skinPixels: skinPixels, count: skinCount) = _segmentSkin(image);
    if (skinCount < 100) return null;

    final result = kMeans(skinPixels, 3);
    final bestRgb = _selectBestCluster(result.centroids, result.counts, skinPixels.length);
    if (bestRgb == null) return null;

    final skinLab = rgbToLab(bestRgb[0], bestRgb[1], bestRgb[2]);
    final lStar = skinLab[0];

    // 12-season classification
    final distances = _classifySeason(skinLab);
    String detectedSeason = "Light Spring";
    var bestDist = double.infinity;
    for (final entry in distances.entries) {
      if (entry.value < bestDist) {
        bestDist = entry.value;
        detectedSeason = entry.key;
      }
    }
    final baseSeason = _subbaseMap[detectedSeason] ?? detectedSeason;

    const gamma = 0.04;
    var sumSim = 0.0;
    final similarities = <String, double>{};
    for (final entry in distances.entries) {
      final sim = exp(-gamma * entry.value);
      similarities[entry.key] = sim;
      sumSim += sim;
    }
    final confidence = ((similarities[detectedSeason]! / sumSim) * 100).round();

    final lightnessDescr = _describeLightness(lStar);
    final palette = _seasonPalettes[detectedSeason]!;
    final undertone = palette["explanation_undertone"] as String;
    final seasonDescr = palette["season_descr"] as String;
    final explanation =
        "We detected $undertone undertones and a $lightnessDescr skin level. "
        "This places you in the $detectedSeason seasonal color family. $seasonDescr";

    final palettesOut = <String, Map<String, String>>{};
    for (final occ in ["office", "party", "casual"]) {
      final occPalette = palette[occ] as List<String>;
      palettesOut[occ] = {
        "primary_color": _adjustForSkinTone(occPalette[0], lStar),
        "secondary_color": _adjustForSkinTone(occPalette[1], lStar),
        "accent_color": _adjustForSkinTone(occPalette[2], lStar),
        "message": _getGenderedStylistTip(detectedSeason, occ, gender),
      };
    }

    // Makeup palette
    final makeupRaw = palette["makeup_palette"] as Map<String, dynamic>?;
    final makeupOut = <String, List<String>>{};
    if (makeupRaw != null) {
      for (final mtype in ["lip", "eye", "cheek", "nail"]) {
        final colors = (makeupRaw[mtype] as List?)?.cast<String>() ?? [];
        makeupOut[mtype] = colors.map((c) => _adjustForSkinTone(c, lStar)).toList();
      }
    }

    // Hair color palette
    final hairRaw = (palette["hair_color_palette"] as List?)?.cast<String>() ?? [];
    final hairOut = hairRaw.map((c) => _adjustForSkinTone(c, lStar)).toList();

    // Colors to avoid
    final avoidOut = (palette["colors_to_avoid"] as List?)?.cast<String>() ?? [];

    final archetype = _styleArchetypes[detectedSeason] ?? ["The Stylist", "Your personal colour story is still being written."];

    return {
      "detected_category": _skinToneLabels[detectedSeason] ?? "$detectedSeason Season",
      "detected_subseason": detectedSeason,
      "base_season": baseSeason,
      "confidence": confidence,
      "explanation": explanation,
      "palettes": palettesOut,
      "makeup_palette": makeupOut,
      "hair_color_palette": hairOut,
      "colors_to_avoid": avoidOut,
      "style_archetype": archetype[0],
      "style_archetype_description": archetype[1],
      "skin_lightness": lStar,
    };
  } catch (e) {
    debugPrint("SkinAnalyzer.processSelfie failed: $e");
    return null;
  }
}

Future<Map<String, dynamic>?> processSelfieFromBytes(Uint8List bytes, String gender) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = img.copyResize(decoded, width: 400, height: 400);
  return processSelfie(resized, gender: gender);
}
