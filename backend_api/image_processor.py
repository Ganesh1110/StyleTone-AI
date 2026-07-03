import os
import cv2
import numpy as np
import base64
import colorsys
import logging
from sklearn.cluster import KMeans

logger = logging.getLogger(__name__)


def hex_to_rgb(hex_code):
    hex_code = hex_code.lstrip('#')
    return tuple(int(hex_code[i:i+2], 16) for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return '#{:02x}{:02x}{:02x}'.format(int(rgb[0]), int(rgb[1]), int(rgb[2]))


def adjust_color_for_occasion(hex_color, occasion):
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


def _get_cascade_path():
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


def _detect_face(img):
    """Detect the largest face and return a cropped region expanded by 30%."""
    cascade_path = _get_cascade_path()
    if not os.path.exists(cascade_path):
        logger.error("Haar cascade file not found at: %s", cascade_path)
        raise RuntimeError("Face detection model not found on server.")
    face_cascade = cv2.CascadeClassifier(cascade_path)
    if face_cascade.empty():
        logger.error("Failed to load Haar cascade from: %s", cascade_path)
        raise RuntimeError("Failed to load face detection model.")
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.1, 5, minSize=(80, 80))
    if len(faces) == 0:
        return None
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


def process_selfie(base64_image: str, gender: str = "neutral"):
    try:
        if base64_image.startswith("data:image"):
            base64_image = base64_image.split(",")[1]

        img_bytes = base64.b64decode(base64_image)
        np_arr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Failed to decode image")

        # --- FACE DETECTION ---
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

        # --- SEASONAL CLASSIFICATION via CIE76 Delta E ---
        distances = {}
        for season, anchors in SEASON_ANCHORS_RGB.items():
            min_dist = float('inf')
            for r, g, bv in anchors:
                anchor_bgr = np.uint8([[[bv, g, r]]])
                anchor_lab = cv2.cvtColor(anchor_bgr, cv2.COLOR_BGR2LAB)[0][0]
                dist = np.sqrt(
                    (l_val - float(anchor_lab[0])) ** 2 +
                    (a_val - float(anchor_lab[1])) ** 2 +
                    (b_val - float(anchor_lab[2])) ** 2
                )
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
                "primary_color": selected_palette[0],
                "secondary_color": selected_palette[1],
                "accent_color": selected_palette[2],
                "message": _get_gendered_stylist_tip(detected_season, occ, gender),
            }

        return {
            "detected_category": f"{detected_season} Season",
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
