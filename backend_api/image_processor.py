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


def decode_image_bytes(content: bytes) -> np.ndarray | None:
    """Decode raw image bytes (e.g. downloaded from a scraped URL) into an OpenCV BGR array."""
    np_arr = np.frombuffer(content, np.uint8)
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


# ---------------------------------------------------------------------------
# 12-Season colour system
# Each subseason has anchor RGB samples representing skin-tone clusters.
# ---------------------------------------------------------------------------

SUBBASE_MAP = {
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
}

SEASON_ANCHORS_RGB = {
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
}

# Keep the 4-season anchors for fallback / backward compat
FOUR_SEASON_ANCHORS_RGB = {
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

FOUR_SEASON_PALETTES = {
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

SEASON_PALETTES = {
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
}

SEASON_PALETTES_4 = dict(SEASON_PALETTES)  # alias
# Ensure 4-season keys exist for synergy fallback
for base in ["Spring", "Summer", "Autumn", "Winter"]:
    if base not in SEASON_PALETTES:
        SEASON_PALETTES[base] = FOUR_SEASON_PALETTES[base]

SKIN_TONE_LABELS_12 = {
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


def _lab_from_hex(hex_code: str) -> tuple[float, float, float]:
    """Convert a hex colour string to CIE L*a*b* tuple."""
    r, g, b = hex_to_rgb(hex_code)
    bgr_pixel = np.uint8([[[b, g, r]]])
    lab = cv2.cvtColor(bgr_pixel, cv2.COLOR_BGR2LAB)[0][0]
    return (float(lab[0]), float(lab[1]), float(lab[2]))


def _compute_subseason_distances(
    skin_lab: tuple[float, float, float],
    hair_lab: tuple[float, float, float] | None,
    eye_lab: tuple[float, float, float] | None,
) -> tuple[str, dict[str, float]]:
    """Compute weighted Delta‑E distances to each of the 12 sub‑seasons.
    Weights: skin 0.60, hair 0.25, eye 0.15.
    Returns (best_subseason, {subseason: weighted_distance}).
    """
    weights = {
        "skin": 0.60,
        "hair": 0.25,
        "eye": 0.15,
    }
    has_hair = hair_lab is not None
    has_eye = eye_lab is not None

    if not has_hair and not has_eye:
        w_skin = 1.0
    elif not has_hair:
        w_skin = weights["skin"] / (weights["skin"] + weights["eye"])
    elif not has_eye:
        w_skin = weights["skin"] / (weights["skin"] + weights["hair"])
    else:
        w_skin = weights["skin"]

    weighted = {}
    for subseason, anchors in SEASON_ANCHORS_RGB.items():
        min_skin = float("inf")
        min_hair = float("inf")
        min_eye = float("inf")

        for r, g, b in anchors:
            anchor_bgr = np.uint8([[[b, g, r]]])
            anchor_lab_vec = cv2.cvtColor(anchor_bgr, cv2.COLOR_BGR2LAB)[0][0]
            anchor_lab = (
                float(anchor_lab_vec[0]),
                float(anchor_lab_vec[1]),
                float(anchor_lab_vec[2]),
            )
            d = delta_e_2000(skin_lab, anchor_lab)
            if d < min_skin:
                min_skin = d

        if has_hair:
            for r, g, b in anchors:
                anchor_bgr = np.uint8([[[b, g, r]]])
                anchor_lab_vec = cv2.cvtColor(anchor_bgr, cv2.COLOR_BGR2LAB)[0][0]
                anchor_lab = (
                    float(anchor_lab_vec[0]),
                    float(anchor_lab_vec[1]),
                    float(anchor_lab_vec[2]),
                )
                d = delta_e_2000(hair_lab, anchor_lab)
                if d < min_hair:
                    min_hair = d

        if has_eye:
            for r, g, b in anchors:
                anchor_bgr = np.uint8([[[b, g, r]]])
                anchor_lab_vec = cv2.cvtColor(anchor_bgr, cv2.COLOR_BGR2LAB)[0][0]
                anchor_lab = (
                    float(anchor_lab_vec[0]),
                    float(anchor_lab_vec[1]),
                    float(anchor_lab_vec[2]),
                )
                d = delta_e_2000(eye_lab, anchor_lab)
                if d < min_eye:
                    min_eye = d

        total = w_skin * min_skin
        if has_hair:
            total += weights["hair"] * min_hair
        if has_eye:
            total += weights["eye"] * min_eye
        weighted[subseason] = total

    best = min(weighted, key=weighted.get)
    return best, weighted


def process_selfie(
    base64_image: str,
    gender: str = "neutral",
    face_already_cropped: bool = False,
    hair_color: str | None = None,
    eye_color: str | None = None,
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

        # --- 12-SEASON CLASSIFICATION via CIEDE2000 (weighted) ---
        skin_lab = (l_val, a_val, b_val)

        hair_lab = None
        if hair_color:
            try:
                hair_lab = _lab_from_hex(hair_color)
            except Exception:
                hair_lab = None

        eye_lab = None
        if eye_color:
            try:
                eye_lab = _lab_from_hex(eye_color)
            except Exception:
                eye_lab = None

        best_subseason, weighted_dists = _compute_subseason_distances(skin_lab, hair_lab, eye_lab)
        detected_season = best_subseason
        base_season = SUBBASE_MAP.get(detected_season, detected_season)

        gamma = 0.04
        similarities = {s: np.exp(-gamma * d) for s, d in weighted_dists.items()}
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

        palette = SEASON_PALETTES.get(detected_season, FOUR_SEASON_PALETTES.get(base_season, {}))
        undertone = palette.get("explanation_undertone", "balanced")
        season_descr = palette.get("season_descr", "")
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

        # --- Makeup palette ---
        makeup = palette.get("makeup_palette", {})
        makeup_out = {}
        for mtype in ["lip", "eye", "cheek", "nail"]:
            colors = makeup.get(mtype, [])
            makeup_out[mtype] = [_adjust_for_skin_tone(c, l_val) for c in colors]

        # --- Hair color palette ---
        hair_pal = palette.get("hair_color_palette", [])
        hair_out = [_adjust_for_skin_tone(c, l_val) for c in hair_pal]

        # --- Colors to avoid ---
        avoid = palette.get("colors_to_avoid", [])

        # --- Skin tone labels (12-subseason aware) ---
        detected_label = SKIN_TONE_LABELS_12.get(detected_season, f"{detected_season} Season")

        # --- Style archetype ---
        archetype_data = STYLE_ARCHETYPES.get(detected_season, ("The Stylist", "Your personal colour story is still being written."))

        return {
            "detected_category": detected_label,
            "detected_subseason": detected_season,
            "base_season": base_season,
            "confidence": confidence,
            "explanation": explanation,
            "palettes": palettes_out,
            "makeup_palette": makeup_out,
            "hair_color_palette": hair_out,
            "colors_to_avoid": avoid,
            "style_archetype": archetype_data[0],
            "style_archetype_description": archetype_data[1],
            "skin_lightness": round(l_val, 1),
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
# Style Archetypes — shareable labels per 12 subseason
# ---------------------------------------------------------------------------

STYLE_ARCHETYPES = {
    "Light Spring": ("The Warm Minimalist", "Delicate warmth with an airy, understated elegance. Think soft luminosity, not loud colour."),
    "Warm Spring": ("The Golden Hour", "Sun-kissed and approachable. Your palette glows with honeyed warmth and cheerful energy."),
    "Bright Spring": ("The Vibrant Optimist", "Bold, clear, and saturated. You radiate confidence and a playful zest for life."),
    "Light Summer": ("The Ethereal Cool", "Graceful, muted, and serene. Your look whispers refinement with a cool, misty palette."),
    "Cool Summer": ("The Elegant Rose", "True cool composure. Dusty pinks and steel blues create a quietly powerful, polished presence."),
    "Soft Summer": ("The Smoky Classic", "Muted sophistication with a hint of mystery. Greyed tones give you an understated, timeless edge."),
    "Soft Autumn": ("The Earthy Minimalist", "Subtle warmth grounded in nature. Olive, clay, and taupe speak a quiet, confident language."),
    "Warm Autumn": ("The Amber Glow", "Rich, golden, and deeply warm. Terracotta and mustard tell a story of harvest abundance."),
    "Deep Autumn": ("The Forest Depth", "Dark, opulent, and grounded. Espresso, rust, and pine project strength without shouting."),
    "Deep Winter": ("The Dark Luxe", "High-contrast depth with icy edge. Midnight and charcoal create a commanding, dramatic silhouette."),
    "Cool Winter": ("The Ice Queen", "Crystal-clear cool that stops the room. Royal blue and emerald demand attention with precision."),
    "Bright Winter": ("The Electric Edge", "Brilliant, chromatic, and fearless. Hot pink and electric blue are your superpowers."),
}


# ---------------------------------------------------------------------------
# Closet Synergy Engine
# ---------------------------------------------------------------------------

# CIEDE2000 range for real-world colours is ~0-100; use 100 as the normaliser.
_MAX_DE = 100.0

_CATEGORY_LABELS = {
    "top": "Top / Shirt",
    "bottom": "Bottom / Pants",
    "outer": "Outerwear / Jacket",
    "shoes": "Shoes",
    "accessory": "Accessories",
}


def compute_synergy(new_hex: str, season: str, closet_items: list) -> dict:
    """
    Compute a Closet Synergy Score for a new garment using CIEDE2000
    (the same perceptually-uniform metric the season classifier uses).

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

    new_lab = _lab_from_hex(new_hex)

    # ── Synergy score: CIEDE2000 distance to closest palette color ──────────
    min_palette_dist = float("inf")
    matched_colors: list[str] = []

    for ph in all_palette_hexes:
        pal_lab = _lab_from_hex(ph)
        dist = delta_e_2000(new_lab, pal_lab)
        if dist < min_palette_dist:
            min_palette_dist = dist
        if dist < 15:
            matched_colors.append(ph)

    synergy_score = max(0, min(100, int((1 - min_palette_dist / _MAX_DE) * 100)))

    # ── Outfit combos with existing closet items (CIEDE2000) ─────────────────
    new_combos: list[dict] = []
    for item in closet_items:
        item_hex = item.get("hex_color", "#FFFFFF")
        item_lab = _lab_from_hex(item_hex)
        dist = delta_e_2000(new_lab, item_lab)

        # In perceptually-uniform Lab space:
        #   DE < 20  → analogous (close hues, harmonious)
        #   DE > 45  → complementary (perceptually opposite)
        is_analogous = dist < 20
        is_complementary = dist > 45

        if (is_analogous or is_complementary):
            match_score = max(0, min(100, int((1 - dist / _MAX_DE) * 100)))
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
