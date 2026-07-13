import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Seasonal anchor colours (RGB) – ported from image_processor.py
// ---------------------------------------------------------------------------
const Map<String, List<List<int>>> _seasonAnchorsRgb = {
  "Spring": [
    [248, 213, 177],
    [243, 225, 196],
    [228, 184, 137],
    [255, 224, 178],
    [235, 195, 145],
    [218, 175, 120],
    [200, 155, 100],
  ],
  "Summer": [
    [236, 213, 197],
    [255, 240, 245],
    [188, 163, 146],
    [220, 200, 190],
    [210, 190, 180],
    [195, 175, 165],
    [175, 160, 150],
  ],
  "Autumn": [
    [208, 158, 114],
    [172, 122, 75],
    [133, 84, 46],
    [190, 140, 90],
    [160, 110, 60],
    [145, 95, 55],
    [115, 75, 40],
    [95, 60, 35],
  ],
  "Winter": [
    [250, 244, 240],
    [174, 144, 118],
    [120, 81, 57],
    [80, 55, 40],
    [230, 220, 215],
    [200, 180, 165],
    [155, 125, 100],
    [100, 70, 50],
    [60, 40, 30],
  ],
};

const Map<String, Map<String, dynamic>> _seasonPalettes = {
  "Spring": {
    "office": ["#C28E75", "#D6C5A8", "#477876"],
    "party": ["#FF7F50", "#FFD700", "#008080"],
    "casual": ["#E9967A", "#F5F5DC", "#20B2AA"],
    "explanation_undertone": "warm golden/peach",
    "season_descr":
        "Your skin radiates soft, golden warmth. Pastel oranges, bright cream, and warm teals will look exceptionally luminous on you.",
  },
  "Summer": {
    "office": ["#B08B9E", "#708090", "#6A7B83"],
    "party": ["#DA8A9F", "#9370DB", "#4682B4"],
    "casual": ["#FFB6C1", "#E6E6FA", "#778899"],
    "explanation_undertone": "cool rosy/pink",
    "season_descr":
        "Your skin features soft, rosy undertones. Dusty rose pinks, soft lavenders, and cool slate grays will enhance your elegant, cool contrast.",
  },
  "Autumn": {
    "office": ["#8A5E38", "#556B2F", "#C2A67D"],
    "party": ["#E05A47", "#B8860B", "#2E8B57"],
    "casual": ["#D2691E", "#8FBC8F", "#F5F5DC"],
    "explanation_undertone": "warm bronze/honey",
    "season_descr":
        "You have rich golden undertones and deep features. Terracotta, mustard gold, and earthy olive greens complement your natural warmth perfectly.",
  },
  "Winter": {
    "office": ["#1F3A60", "#0E5033", "#4A4A4A"],
    "party": ["#4169E1", "#00A86B", "#C71585"],
    "casual": ["#4682B4", "#2E8B57", "#E0115F"],
    "explanation_undertone": "cool high-contrast",
    "season_descr":
        "Your skin has a striking cool undertone. Bold, saturated colors like royal blue, emerald green, and vivid ruby red will make you stand out beautifully.",
  },
};

const Map<String, String> _skinToneLabels = {
  "Spring": "Warm Golden/Peach Skin Tone",
  "Summer": "Cool Rosy/Pink Skin Tone",
  "Autumn": "Warm Bronze/Honey Skin Tone",
  "Winter": "Cool High-Contrast Skin Tone",
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

    final distances = _classifySeason(skinLab);
    String detectedSeason = "Spring";
    var bestDist = double.infinity;
    for (final entry in distances.entries) {
      if (entry.value < bestDist) {
        bestDist = entry.value;
        detectedSeason = entry.key;
      }
    }

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

    return {
      "detected_category": _skinToneLabels[detectedSeason] ?? "$detectedSeason Season",
      "confidence": confidence,
      "explanation": explanation,
      "palettes": palettesOut,
    };
  } catch (e) {
    debugPrint("SkinAnalyzer.processSelfie failed: $e");
    return null;
  }
}
