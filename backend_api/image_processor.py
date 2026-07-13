import os
import cv2
import numpy as np
import base64
import colorsys
import logging
from sklearn.cluster import KMeans

logger = logging.getLogger(__name__)


def delta_e_2000(lab1: tuple[float, float, float], lab2: tuple[float, float, float]) -> float:
    """CIEDE2000 colour-difference between two CIE L*a*b* samples.

    Implementation follows the Sharma, Wu & Dalal (2005) paper.
    Parametric factors kL = kC = kH = 1 (reference viewing conditions).
    """
    L1, a1, b1 = lab1
    L2, a2, b2 = lab2

    # Chroma
    C1 = (a1 ** 2 + b1 ** 2) ** 0.5
    C2 = (a2 ** 2 + b2 ** 2) ** 0.5
    C_bar = (C1 + C2) / 2.0

    # G (blue-hue adjustment)
    C_bar7 = C_bar ** 7
    G = 0.5 * (1.0 - (C_bar7 / (C_bar7 + 25 ** 7)) ** 0.5)

    a1p = a1 * (1.0 + G)
    a2p = a2 * (1.0 + G)

    C1p = (a1p ** 2 + b1 ** 2) ** 0.5
    C2p = (a2p ** 2 + b2 ** 2) ** 0.5

    def _hp(a: float, b: float) -> float:
        if a == 0.0 and b == 0.0:
            return 0.0
        h = np.degrees(np.arctan2(b, a))
        return h if h >= 0.0 else h + 360.0

    h1p = _hp(a1p, b1)
    h2p = _hp(a2p, b2)

    # Delta L', Delta C', Delta H'
    dLp = L2 - L1
    dCp = C2p - C1p
    dhp = _compute_dhp(h1p, h2p, C1p, C2p)
    dHp = 2.0 * (C1p * C2p) ** 0.5 * np.sin(np.radians(dhp / 2.0))

    # Lightness-weighting function SL
    L_bar = (L1 + L2) / 2.0
    SL = 1.0 + (0.015 * (L_bar - 50.0) ** 2) / (20.0 + (L_bar - 50.0) ** 2) ** 0.5

    # Chroma-weighting function SC
    Cp_bar = (C1p + C2p) / 2.0
    SC = 1.0 + 0.045 * Cp_bar

    # Hue-weighting function SH
    h_bar = _compute_hp_bar(h1p, h2p, C1p, C2p)
    T = (
        1.0
        - 0.17 * np.cos(np.radians(h_bar - 30.0))
        + 0.24 * np.cos(np.radians(2.0 * h_bar))
        + 0.32 * np.cos(np.radians(3.0 * h_bar + 6.0))
        - 0.20 * np.cos(np.radians(4.0 * h_bar - 63.0))
    )
    SH = 1.0 + 0.015 * Cp_bar * T

    # Rotation term RT
    dtheta = 30.0 * np.exp(-(((h_bar - 275.0) / 25.0) ** 2))
    Cp_bar7 = Cp_bar ** 7
    RC = 2.0 * (Cp_bar7 / (Cp_bar7 + 25 ** 7)) ** 0.5
    RT = -RC * np.sin(np.radians(2.0 * dtheta))

    # Parametric factors (reference conditions → 1.0)
    kL = kC = kH = 1.0

    return ((dLp / (kL * SL)) ** 2
            + (dCp / (kC * SC)) ** 2
            + (dHp / (kH * SH)) ** 2
            + RT * (dCp / (kC * SC)) * (dHp / (kH * SH))) ** 0.5


def _compute_dhp(h1p: float, h2p: float, C1p: float, C2p: float) -> float:
    """Hue-angle difference in degrees."""
    if C1p * C2p == 0.0:
        return 0.0
    dhp = h2p - h1p
    if dhp > 180.0:
        dhp -= 360.0
    elif dhp < -180.0:
        dhp += 360.0
    return dhp


def _compute_hp_bar(h1p: float, h2p: float, C1p: float, C2p: float) -> float:
    """Mean hue angle in degrees."""
    if C1p * C2p == 0.0:
        return h1p + h2p
    if abs(h1p - h2p) <= 180.0:
        return (h1p + h2p) / 2.0
    if (h1p + h2p) < 360.0:
        return (h1p + h2p + 360.0) / 2.0
    return (h1p + h2p - 360.0) / 2.0


def hex_to_rgb(hex_code: str) -> tuple[int, int, int]:
    hex_code = hex_code.lstrip('#')
    return tuple(int(hex_code[i:i+2], 16) for i in (0, 2, 4))


def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    return '#{:02x}{:02x}{:02x}'.format(int(rgb[0]), int(rgb[1]), int(rgb[2]))


def decode_base64_image(b64_string: str) -> np.ndarray | None:
    """Decode a base64 image string (optionally with a data URI prefix) into an OpenCV BGR array."""
    if "," in b64_string:
        b64_string = b64_string.split(",")[1]
    try:
        img_bytes = base64.b64decode(b64_string)
    except Exception:
        return None
    np_arr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    return img


def extract_dominant_color(img: np.ndarray) -> dict:
    """Extract the dominant non-white/non-black colour from an image via centre-crop K-Means.

    Returns a dict with keys: hex_color, rgb (list), color_name.
    """
    h, w, _ = img.shape
    cy, cx = h // 2, w // 2
    dy, dx = int(h * 0.3), int(w * 0.3)
    crop = img[cy - dy:cy + dy, cx - dx:cx + dx]

    pixels = crop.reshape(-1, 3).astype(np.float32)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0)
    _, labels, centers = cv2.kmeans(pixels, 3, None, criteria, 10, cv2.KMEANS_RANDOM_CENTERS)
    _, counts = np.unique(labels, return_counts=True)
    sorted_idx = np.argsort(-counts)

    selected_bgr = None
    for idx in sorted_idx:
        bgr = centers[idx]
        b, g, r = int(bgr[0]), int(bgr[1]), int(bgr[2])
        is_white = r > 220 and g > 220 and b > 220 and max(r, g, b) - min(r, g, b) < 20
        is_black = r < 45 and g < 45 and b < 45
        if not is_white and not is_black:
            selected_bgr = bgr
            break
    if selected_bgr is None:
        selected_bgr = centers[sorted_idx[0]]

    r, g, b = int(selected_bgr[2]), int(selected_bgr[1]), int(selected_bgr[0])
    hex_color = '#{:02x}{:02x}{:02x}'.format(r, g, b)
    color_name = get_color_name(r, g, b)

    return {
        "hex_color": hex_color,
        "rgb": [r, g, b],
        "color_name": color_name,
    }


def adjust_color_for_occasion(hex_color: str, occasion: str) -> str:
    r, g, b = hex_to_rgb(hex_color)
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    if occasion == "office":
        s = max(0.3, s * 0.6)
        v = max(0.4, v * 0.75)
    elif occasion == "party":
        s = min(1.0, s * 1.4)
        v = min(1.0, v * 1.3)
    else:
        s = s * 0.9
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return rgb_to_hex((r * 255, g * 255, b * 255))


def _get_cascade_path() -> str:
    """Return a path to haarcascade_frontalface_default.xml,
    preferring a local copy over the OpenCV data directory."""
    local_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        'haarcascade_frontalface_default.xml'
    )
    if os.path.exists(local_path):
        return local_path
    try:
        return cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    except AttributeError:
        return local_path


def _detect_face(img: np.ndarray) -> np.ndarray:
    """Detect the largest face and return a cropped region expanded by 30%.
    Falls back to returning the full image if face detection is unavailable."""
    cascade_path = _get_cascade_path()
    if not os.path.exists(cascade_path):
        logger.warning("Haar cascade file not found at %s; using full image", cascade_path)
        return img
    try:
        face_cascade = cv2.CascadeClassifier(cascade_path)
        if face_cascade.empty():
            logger.warning("Failed to load Haar cascade; using full image")
            return img
    except AttributeError:
        logger.warning("CascadeClassifier not available in this OpenCV build; using full image")
        return img
    except Exception as ex:
        logger.warning("Face detection init failed (%s); using full image", ex)
        return img

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.1, 5, minSize=(80, 80))
    if len(faces) == 0:
        logger.warning("No faces detected by Haar cascade; falling back to full image")
        return img
    (x, y, w, h) = max(faces, key=lambda f: f[2] * f[3])
    pad = int(0.3 * max(w, h))
    x = max(0, x - pad)
    y = max(0, y - pad)
    w = min(img.shape[1] - x, w + 2 * pad)
    h = min(img.shape[0] - y, h + 2 * pad)
    return img[y:y + h, x:x + w]


SEASON_ANCHORS_RGB = {
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
}

SEASON_PALETTES = {
    "Spring": {
        "office": ["#C28E75", "#D6C5A8", "#477876"],
        "party": ["#FF7F50", "#FFD700", "#008080"],
        "casual": ["#E9967A", "#F5F5DC", "#20B2AA"],
        "explanation_undertone": "warm golden/peach",
        "season_descr": "Your skin radiates soft, golden warmth. Pastel oranges, bright cream, and warm teals will look exceptionally luminous on you.",
    },
    "Summer": {
        "office": ["#B08B9E", "#708090", "#6A7B83"],
        "party": ["#DA8A9F", "#9370DB", "#4682B4"],
        "casual": ["#FFB6C1", "#E6E6FA", "#778899"],
        "explanation_undertone": "cool rosy/pink",
        "season_descr": "Your skin features soft, rosy undertones. Dusty rose pinks, soft lavenders, and cool slate grays will enhance your elegant, cool contrast.",
    },
    "Autumn": {
        "office": ["#8A5E38", "#556B2F", "#C2A67D"],
        "party": ["#E05A47", "#B8860B", "#2E8B57"],
        "casual": ["#D2691E", "#8FBC8F", "#F5F5DC"],
        "explanation_undertone": "warm bronze/honey",
        "season_descr": "You have rich golden undertones and deep features. Terracotta, mustard gold, and earthy olive greens complement your natural warmth perfectly.",
    },
    "Winter": {
        "office": ["#1F3A60", "#0E5033", "#4A4A4A"],
        "party": ["#4169E1", "#00A86B", "#C71585"],
        "casual": ["#4682B4", "#2E8B57", "#E0115F"],
        "explanation_undertone": "cool high-contrast",
        "season_descr": "Your skin has a striking cool undertone. Bold, saturated colors like royal blue, emerald green, and vivid ruby red will make you stand out beautifully.",
    },
}


def _get_gendered_stylist_tip(detected_season: str, occasion: str, gender: str) -> str:
    gender = (gender or "neutral").lower()
    if gender == "male":
        if occasion == "office":
            return f"{detected_season} Office Style: Muted, professional tones. Pair a primary-colored suit or blazer with clean tailored trousers, a subtle accent tie, and a brown leather watch strap."
        elif occasion == "party":
            return f"{detected_season} Party Look: Bold, high-contrast styling. Rock a primary-colored sports coat over a dark shirt, accented with a pocketsquare and matching watch straps."
        else:
            return f"{detected_season} Casual: Relaxed, natural shades. Try a casual knit sweater in your primary color combined with dark denim and classic leather boots."
    elif gender == "female":
        if occasion == "office":
            return f"{detected_season} Office Style: Muted, professional tones. Wear a structured primary blazer over a neutral blouse, paired with delicate gold or silver jewelry and a matching handbag."
        elif occasion == "party":
            return f"{detected_season} Party Look: Vibrant, high-contrast styling. Let your primary color shine on a gorgeous dress or bold top, accessorized with statement earrings and bronze makeup accents."
        else:
            return f"{detected_season} Casual: Relaxed, natural shades. Layer a primary-colored oversized cardigan or jacket over light linens, completed with amber or leather accessories."
    else:
        if occasion == "office":
            return f"{detected_season} Office Style: Muted, professional tones that project polished confidence and balanced coordination."
        elif occasion == "party":
            return f"{detected_season} Party Look: Vibrant, high-contrast palette styled to command attention and make a memorable statement."
        else:
            return f"{detected_season} Casual: Relaxed, natural shades curated for everyday comfort and clean color harmony."


def _adjust_for_skin_tone(hex_color: str, l_val: float) -> str:
    """Adjust a palette color based on the skin's CIE L* lightness value.
    Darker skin → more vibrant (higher saturation & brightness).
    Lighter skin → softer (lower saturation, slightly lower brightness).
    """
    r, g, b = hex_to_rgb(hex_color)
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)

    if l_val < 95:
        s = min(1.0, s * 1.3)
        v = min(1.0, v * 1.25)
    elif l_val < 140:
        s = min(1.0, s * 1.1)
        v = min(1.0, v * 1.1)
    elif l_val > 190:
        s = max(0.25, s * 0.7)
        v = max(0.35, v * 0.85)
    else:
        s = max(0.3, s * 0.85)
        v = max(0.4, v * 0.95)

    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return rgb_to_hex((r * 255, g * 255, b * 255))


def process_selfie(
    base64_image: str,
    gender: str = "neutral",
    face_already_cropped: bool = False,
) -> dict:
    try:
        if base64_image.startswith("data:image"):
            base64_image = base64_image.split(",")[1]

        img_bytes = base64.b64decode(base64_image)
        np_arr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Failed to decode image")

        # --- FACE DETECTION (skipped if client already cropped) ---
        if not face_already_cropped:
            face_region = _detect_face(img)
            if face_region is None:
                raise ValueError(
                    "No face detected in the image. "
                    "Please ensure your face is clearly visible and well-lit."
                )
            logger.info("Face detected, region shape: %s", face_region.shape)
            img = face_region

        # --- SKIN SEGMENTATION ---
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        ycrcb = cv2.cvtColor(img, cv2.COLOR_BGR2YCrCb)

        lower_hsv = np.array([0, 20, 20], dtype=np.uint8)
        upper_hsv = np.array([20, 150, 255], dtype=np.uint8)

        lower_ycrcb = np.array([0, 133, 77], dtype=np.uint8)
        upper_ycrcb = np.array([255, 173, 127], dtype=np.uint8)

        mask_hsv = cv2.inRange(hsv, lower_hsv, upper_hsv)
        mask_ycrcb = cv2.inRange(ycrcb, lower_ycrcb, upper_ycrcb)
        skin_mask = cv2.bitwise_and(mask_hsv, mask_ycrcb)

        skin_pixels = img[skin_mask > 0]

        if len(skin_pixels) < 100:
            raise ValueError(
                "Could not isolate enough skin pixels. "
                "Try a different lighting condition or remove heavy makeup."
            )

        # --- K-MEANS CLUSTERING ---
        kmeans = KMeans(n_clusters=3, n_init=10, random_state=42)
        kmeans.fit(skin_pixels)
        dominant_colors = kmeans.cluster_centers_.astype(int)

        skin_rgb = None
        best_score = -1.0

        labels = kmeans.labels_
        unique_labels, counts = np.unique(labels, return_counts=True)
        total_pixels = len(labels)

        for i, color in enumerate(dominant_colors):
            lab_color = cv2.cvtColor(np.uint8([[color]]), cv2.COLOR_BGR2LAB)[0][0]
            l_val = float(lab_color[0])
            a_val = float(lab_color[1])
            b_val = float(lab_color[2])

            cluster_ratio = counts[i] / total_pixels

            l_penalty = 1.0
            if l_val > 235:
                l_penalty = max(0.0, 1.0 - (l_val - 235) / 20.0)
            elif l_val < 50:
                l_penalty = max(0.0, 1.0 - (50 - l_val) / 25.0)

            chroma_prior = 1.0
            if a_val > 130 and b_val > 130:
                chroma_prior = 1.2

            score = cluster_ratio * l_penalty * chroma_prior
            if score > best_score:
                best_score = score
                skin_rgb = color

        if skin_rgb is None:
            skin_rgb = dominant_colors[0]

        skin_bgr_pixel = np.uint8([[skin_rgb]])
        skin_lab_pixel = cv2.cvtColor(skin_bgr_pixel, cv2.COLOR_BGR2LAB)[0][0]
        l_val = float(skin_lab_pixel[0])
        a_val = float(skin_lab_pixel[1])
        b_val = float(skin_lab_pixel[2])

        # --- SEASONAL CLASSIFICATION via CIEDE2000 ---
        skin_lab = (l_val, a_val, b_val)
        distances = {}
        for season, anchors in SEASON_ANCHORS_RGB.items():
            min_dist = float('inf')
            for r, g, bv in anchors:
                anchor_bgr = np.uint8([[[bv, g, r]]])
                anchor_lab_vec = cv2.cvtColor(anchor_bgr, cv2.COLOR_BGR2LAB)[0][0]
                anchor_lab = (
                    float(anchor_lab_vec[0]),
                    float(anchor_lab_vec[1]),
                    float(anchor_lab_vec[2]),
                )
                dist = delta_e_2000(skin_lab, anchor_lab)
                if dist < min_dist:
                    min_dist = dist
            distances[season] = min_dist

        detected_season = min(distances, key=distances.get)

        gamma = 0.04
        similarities = {s: np.exp(-gamma * d) for s, d in distances.items()}
        sum_sim = sum(similarities.values())
        confidences = {s: int(round((sim / sum_sim) * 100)) for s, sim in similarities.items()}
        confidence = confidences[detected_season]

        if l_val > 190:
            lightness_descr = "fair porcelain"
        elif l_val > 140:
            lightness_descr = "light"
        elif l_val > 95:
            lightness_descr = "medium/tan"
        else:
            lightness_descr = "deep/rich"

        palette = SEASON_PALETTES[detected_season]
        undertone = palette["explanation_undertone"]
        season_descr = palette["season_descr"]
        explanation = (
            f"We detected {undertone} undertones and a {lightness_descr} skin level. "
            f"This places you in the {detected_season} seasonal color family. {season_descr}"
        )

        palettes_out = {}
        for occ in ["office", "party", "casual"]:
            selected_palette = palette[occ]
            palettes_out[occ] = {
                "primary_color": _adjust_for_skin_tone(selected_palette[0], l_val),
                "secondary_color": _adjust_for_skin_tone(selected_palette[1], l_val),
                "accent_color": _adjust_for_skin_tone(selected_palette[2], l_val),
                "message": _get_gendered_stylist_tip(detected_season, occ, gender),
            }

        skin_tone_labels = {
            "Spring": "Warm Golden/Peach Skin Tone",
            "Summer": "Cool Rosy/Pink Skin Tone",
            "Autumn": "Warm Bronze/Honey Skin Tone",
            "Winter": "Cool High-Contrast Skin Tone",
        }

        return {
            "detected_category": skin_tone_labels.get(detected_season, f"{detected_season} Season"),
            "confidence": confidence,
            "explanation": explanation,
            "palettes": palettes_out,
        }

    except ValueError as e:
        logger.warning("Analysis aborted: %s", e)
        raise
    except Exception as e:
        logger.error("Critical error in process_selfie: %s", e, exc_info=True)
        raise


# ---------------------------------------------------------------------------
# Color classification helpers (shared with index.py via import)
# ---------------------------------------------------------------------------

COLORS = {
    "Crimson Red": (220, 20, 60),
    "Tomato Red": (255, 99, 71),
    "Soft Pink": (255, 182, 193),
    "Hot Pink": (255, 105, 180),
    "Coral Orange": (255, 127, 80),
    "Golden Yellow": (255, 215, 0),
    "Mustard Yellow": (228, 178, 47),
    "Olive Green": (128, 128, 0),
    "Emerald Green": (80, 200, 120),
    "Mint Green": (152, 255, 152),
    "Forest Green": (34, 139, 34),
    "Teal": (0, 128, 128),
    "Sky Blue": (135, 206, 235),
    "Royal Blue": (65, 105, 225),
    "Navy Blue": (0, 0, 128),
    "Lavender Purple": (230, 230, 250),
    "Deep Purple": (128, 0, 128),
    "Indigo": (75, 0, 130),
    "Chocolate Brown": (139, 69, 19),
    "Tan Brown": (210, 180, 140),
    "Beige": (245, 245, 220),
    "Cream White": (255, 253, 240),
    "Pure White": (255, 255, 255),
    "Light Gray": (211, 211, 211),
    "Charcoal Gray": (64, 64, 64),
    "Jet Black": (15, 15, 15),
}


def get_color_name(r: int, g: int, b: int) -> str:
    """Return the nearest named color for an RGB triplet."""
    closest = "Unknown Color"
    min_dist = float("inf")
    for name, rgb in COLORS.items():
        dist = (r - rgb[0]) ** 2 + (g - rgb[1]) ** 2 + (b - rgb[2]) ** 2
        if dist < min_dist:
            min_dist = dist
            closest = name
    return closest


# ---------------------------------------------------------------------------
# Closet Synergy Engine
# ---------------------------------------------------------------------------

_MAX_DIST = 441.67  # sqrt(255^2 * 3) — max possible RGB Euclidean distance

_CATEGORY_LABELS = {
    "top": "Top / Shirt",
    "bottom": "Bottom / Pants",
    "outer": "Outerwear / Jacket",
    "shoes": "Shoes",
    "accessory": "Accessories",
}


def compute_synergy(new_hex: str, season: str, closet_items: list) -> dict:
    """
    Compute a Closet Synergy Score for a new garment.

    Args:
        new_hex:      HEX color of the new garment (e.g. '#4a90d9').
        season:       Active seasonal category string (e.g. 'Spring Season').
        closet_items: List of dicts with keys: category, hex_color, color_name.

    Returns a dict with:
        synergy_score          — 0-100 integer
        new_item_hex           — echo of new_hex
        matched_palette_colors — palette colors within close range
        new_combos_count       — number of valid outfit pairs found
        new_combos             — list of combo dicts (max 8)
        gap_fillers            — missing category recommendations
    """
    # Resolve season key: "Spring Season" → "Spring"
    season_key = season.replace(" Season", "").strip()
    if season_key not in SEASON_PALETTES:
        season_key = "Spring"

    palette = SEASON_PALETTES[season_key]

    # Collect unique palette hex codes across all occasions
    all_palette_hexes: set[str] = set()
    for occ in ("office", "party", "casual"):
        all_palette_hexes.update(palette.get(occ, []))

    new_r, new_g, new_b = hex_to_rgb(new_hex)

    # ── Synergy score: distance to closest palette color ─────────────────────
    min_palette_dist = float("inf")
    matched_colors: list[str] = []

    for ph in all_palette_hexes:
        pr, pg, pb = hex_to_rgb(ph)
        dist = ((new_r - pr) ** 2 + (new_g - pg) ** 2 + (new_b - pb) ** 2) ** 0.5
        if dist < min_palette_dist:
            min_palette_dist = dist
        if dist < 120:
            matched_colors.append(ph)

    synergy_score = max(0, min(100, int((1 - min_palette_dist / _MAX_DIST) * 100)))

    # ── Outfit combos with existing closet items ─────────────────────────────
    new_combos: list[dict] = []
    for item in closet_items:
        item_hex = item.get("hex_color", "#FFFFFF")
        ir, ig, ib = hex_to_rgb(item_hex)
        dist = ((new_r - ir) ** 2 + (new_g - ig) ** 2 + (new_b - ib) ** 2) ** 0.5

        is_analogous = dist < 100          # harmonious, close hues
        is_complementary = 180 < dist < 330  # high contrast pairing

        if (is_analogous or is_complementary):
            match_score = max(0, min(100, int((1 - dist / _MAX_DIST) * 100)))
            if match_score > 35:
                new_combos.append({
                    "new_item_hex": new_hex,
                    "existing_item_hex": item_hex,
                    "existing_item_name": item.get("color_name", "Unknown"),
                    "existing_category": item.get("category", ""),
                    "match_score": match_score,
                    "combo_type": "Analogous" if is_analogous else "Contrasting",
                })

    new_combos.sort(key=lambda x: x["match_score"], reverse=True)

    # ── Gap-filler recommendations for missing categories ────────────────────
    present = {item.get("category", "") for item in closet_items}
    all_cats = ["top", "bottom", "outer", "shoes", "accessory"]

    casual_pal = palette.get("casual", ["#CCCCCC", "#AAAAAA", "#888888"])
    office_pal = palette.get("office", ["#CCCCCC", "#AAAAAA", "#888888"])

    cat_color_map = {
        "top":       casual_pal[0] if len(casual_pal) > 0 else "#CCCCCC",
        "bottom":    office_pal[1] if len(office_pal) > 1 else "#AAAAAA",
        "outer":     office_pal[0] if len(office_pal) > 0 else "#CCCCCC",
        "shoes":     casual_pal[2] if len(casual_pal) > 2 else "#888888",
        "accessory": casual_pal[2] if len(casual_pal) > 2 else "#888888",
    }

    gap_fillers: list[dict] = []
    for cat in all_cats:
        if cat not in present:
            rec_hex = cat_color_map.get(cat, "#CCCCCC")
            rr, rg, rb = hex_to_rgb(rec_hex)
            rec_name = get_color_name(rr, rg, rb)
            cat_label = _CATEGORY_LABELS.get(cat, cat)
            gap_fillers.append({
                "category": cat,
                "category_label": cat_label,
                "recommended_hex": rec_hex,
                "recommended_color_name": rec_name,
                "reason": (
                    f"Adding a {rec_name} {cat_label.lower()} in your "
                    f"{season_key} palette would unlock more complete outfit combinations."
                ),
            })

    return {
        "synergy_score": synergy_score,
        "new_item_hex": new_hex,
        "matched_palette_colors": matched_colors[:3],
        "new_combos_count": len(new_combos),
        "new_combos": new_combos[:8],
        "gap_fillers": gap_fillers,
    }
