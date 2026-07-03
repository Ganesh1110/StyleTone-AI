import cv2
import numpy as np
import base64
import json
import os
import requests
import colorsys
from sklearn.cluster import KMeans

# Load the JSON only for fallback (if API fails)
_base_dir = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(_base_dir, "color_matrix.json"), "r") as f:
    COLOR_MATRIX = json.load(f)

def hex_to_rgb(hex_code):
    hex_code = hex_code.lstrip('#')
    return tuple(int(hex_code[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return '#{:02x}{:02x}{:02x}'.format(int(rgb[0]), int(rgb[1]), int(rgb[2]))

def adjust_color_for_occasion(hex_color, occasion):
    """Dynamically adjusts color brightness/saturation for Office or Party."""
    r, g, b = hex_to_rgb(hex_color)
    h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
    
    if occasion == "office":
        # Make it more muted (lower saturation) and slightly darker (lower value)
        s = s * 0.6
        v = v * 0.75
    elif occasion == "party":
        # Make it more vibrant (higher saturation) and brighter (higher value)
        s = min(1.0, s * 1.4)
        v = min(1.0, v * 1.3)
    else:  # casual
        # Keep original, maybe just slightly soften
        s = s * 0.9
    
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return rgb_to_hex((r*255, g*255, b*255))

def fetch_palette_from_api(skin_hex, occasion):
    try:
        # --- CHANGE 1: Use 'triad' instead of 'analogic' for more variety ---
        url = f"https://www.thecolorapi.com/scheme?hex={skin_hex.replace('#','')}&mode=triad&count=6"
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            raw_colors = [c['hex']['value'] for c in data['colors']]
            
            # Pick 3 distinct colors: index 0, 2, 4 (skips the closest ones)
            selected = [raw_colors[0], raw_colors[2], raw_colors[4]]
            
            # --- CHANGE 2: Gentler occasion adjustment ---
            adjusted_colors = []
            for c in selected:
                r, g, b = hex_to_rgb(c)
                h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
                
                if occasion == "office":
                    # Only reduce saturation by 20% (was 40%), and darken only 10% (was 25%)
                    s = max(0.3, s * 0.8)  
                    v = max(0.4, v * 0.9)
                elif occasion == "party":
                    s = min(1.0, s * 1.3)
                    v = min(1.0, v * 1.2)
                else:  # casual
                    s = s * 0.95
                
                r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
                adjusted_colors.append(rgb_to_hex((r2*255, g2*255, b2*255)))
            
            # --- CHANGE 3: Better, more specific messages ---
            if occasion == "office":
                msg = f"👔 Office power colors! Muted and professional tones that command respect."
            elif occasion == "party":
                msg = f"🎉 Party vibes! Vibrant, high-energy colors that make you stand out."
            else:
                msg = f"☀️ Casual and effortless. Soft, everyday colors that feel natural."
            
            return {
                "primary_color": adjusted_colors[0],
                "secondary_color": adjusted_colors[1],
                "accent_color": adjusted_colors[2],
                "detected_category": f"Dynamic ({occasion.capitalize()})",
                "message": msg
            }
        else:
            raise Exception("API returned non-200")
    except Exception as e:
        print(f"API Fetch failed: {e}")
        return None
    
def _get_gendered_stylist_tip(detected_season: str, occasion: str, gender: str) -> str:
    gender = (gender or "neutral").lower()

    if gender == "male":
        if occasion == "office":
            return f"👔 {detected_season} Office Style: Muted, professional tones. Pair a primary-colored suit or blazer with clean tailored trousers, a subtle accent tie, and a brown leather watch strap."
        elif occasion == "party":
            return f"🎉 {detected_season} Party Look: Bold, high-contrast styling. Rock a primary-colored sports coat over a dark shirt, accented with a pocketsquare and matching watch straps."
        else:
            return f"☀️ {detected_season} Casual: Relaxed, natural shades. Try a casual knit sweater in your primary color combined with dark denim and classic leather boots."
    elif gender == "female":
        if occasion == "office":
            return f"👔 {detected_season} Office Style: Muted, professional tones. Wear a structured primary blazer over a neutral blouse, paired with delicate gold or silver jewelry and a matching handbag."
        elif occasion == "party":
            return f"🎉 {detected_season} Party Look: Vibrant, high-contrast styling. Let your primary color shine on a gorgeous dress or bold top, accessorized with statement earrings and bronze makeup accents."
        else:
            return f"☀️ {detected_season} Casual: Relaxed, natural shades. Layer a primary-colored oversized cardigan or jacket over light linens, completed with amber or leather accessories."
    else:  # neutral or other
        if occasion == "office":
            return f"👔 {detected_season} Office Style: Muted, professional tones that project polished confidence and balanced coordination."
        elif occasion == "party":
            return f"🎉 {detected_season} Party Look: Vibrant, high-contrast palette styled to command attention and make a memorable statement."
        else:
            return f"☀️ {detected_season} Casual: Relaxed, natural shades curated for everyday comfort and clean color harmony."

def process_selfie(base64_image: str, gender: str = "neutral"):
    try:
        # --- 1. EXTRACT SKIN TONE ---
        if base64_image.startswith("data:image"):
            base64_image = base64_image.split(",")[1]
        
        img_bytes = base64.b64decode(base64_image)
        np_arr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Failed to decode image")

        # White balance correction
        img_lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(img_lab)
        l_avg = np.mean(l)
        l = np.clip(l + (128 - l_avg), 0, 255).astype(np.uint8)
        img_lab = cv2.merge([l, a, b])
        img = cv2.cvtColor(img_lab, cv2.COLOR_LAB2BGR)

        # Convert to HSV and YCrCb for high-accuracy skin segmentation
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        ycrcb = cv2.cvtColor(img, cv2.COLOR_BGR2YCrCb)

        # Define HSV bounds for skin tones
        lower_hsv = np.array([0, 20, 50], dtype=np.uint8)
        upper_hsv = np.array([20, 150, 255], dtype=np.uint8)

        # Define YCrCb bounds for skin tones
        lower_ycrcb = np.array([0, 133, 77], dtype=np.uint8)
        upper_ycrcb = np.array([255, 173, 127], dtype=np.uint8)

        # Create threshold masks
        mask_hsv = cv2.inRange(hsv, lower_hsv, upper_hsv)
        mask_ycrcb = cv2.inRange(ycrcb, lower_ycrcb, upper_ycrcb)

        # Combine both HSV & YCrCb boundaries to reject hair/lips/background
        skin_mask = cv2.bitwise_and(mask_hsv, mask_ycrcb)

        # Extract skin pixels only
        skin_pixels = img[skin_mask > 0]

        # Fallback to entire image if segmentation returns too few pixels
        if len(skin_pixels) < 100:
            skin_pixels = img.reshape(-1, 3)

        # Run K-Means only on isolated skin pixels (K=3 to separate highlights, shadows, and true skin)
        kmeans = KMeans(n_clusters=3, n_init=10, random_state=42)
        kmeans.fit(skin_pixels)
        dominant_colors = kmeans.cluster_centers_.astype(int)

        # Select the cluster that represents true skin, avoiding highlights (glare) and deep shadows
        skin_rgb = None
        best_score = -1.0
        
        # Calculate labels to know the count in each cluster
        labels = kmeans.labels_
        unique_labels, counts = np.unique(labels, return_counts=True)
        total_pixels = len(labels)
        
        for i, color in enumerate(dominant_colors):
            lab_color = cv2.cvtColor(np.uint8([[color]]), cv2.COLOR_BGR2LAB)[0][0]
            l_val = float(lab_color[0])
            a_val = float(lab_color[1])
            b_val = float(lab_color[2])
            
            # Weight based on cluster size representation
            cluster_ratio = counts[i] / total_pixels
            
            # Penalize extreme highlights (sweat/glare, L > 235) and deep shadows (L < 50)
            l_penalty = 1.0
            if l_val > 235:
                l_penalty = max(0.0, 1.0 - (l_val - 235) / 20.0)
            elif l_val < 50:
                l_penalty = max(0.0, 1.0 - (50 - l_val) / 25.0)
                
            # Skin tone prior score: skin tones are warm/rosy, so they have positive chromaticity (a > 130, b > 130 in OpenCV space)
            # We give a small boost to colors in the realistic skin color quadrant
            chroma_prior = 1.0
            if a_val > 130 and b_val > 130:
                chroma_prior = 1.2
                
            score = cluster_ratio * l_penalty * chroma_prior
            if score > best_score:
                best_score = score
                skin_rgb = color

        if skin_rgb is None:
            skin_rgb = dominant_colors[0]

        # Convert dominant BGR skin color to LAB for perceptual distance
        skin_bgr_pixel = np.uint8([[skin_rgb]])
        skin_lab_pixel = cv2.cvtColor(skin_bgr_pixel, cv2.COLOR_BGR2LAB)[0][0]
        l_val = float(skin_lab_pixel[0])
        a_val = float(skin_lab_pixel[1])
        b_val = float(skin_lab_pixel[2])

        # --- 2. CIELAB DELTA E SEASONAL CLASSIFICATION ---
        # Anchor skin colors (RGB) representing diverse tones across the 4 seasons
        season_anchors_rgb = {
            "Spring": [
                [248, 213, 177],  # Light Peach
                [243, 225, 196],  # Golden Ivory
                [228, 184, 137]   # Warm Honey
            ],
            "Summer": [
                [236, 213, 197],  # Rosy Beige
                [255, 240, 245],  # Cool Alabaster
                [188, 163, 146]   # Soft Cocoa
            ],
            "Autumn": [
                [208, 158, 114],  # Warm Amber
                [172, 122, 75],   # Golden Bronze
                [133, 84, 46]     # Deep Terracotta
            ],
            "Winter": [
                [250, 244, 240],  # Stark Porcelain
                [174, 144, 118],  # Cool Olive
                [120, 81, 57],    # Cool Cocoa
                [80, 55, 40]      # Deep Espresso
            ]
        }

        # Calculate minimum Euclidean distance (Delta E proxy) in CIELAB space
        distances = {}
        for season, anchors in season_anchors_rgb.items():
            min_dist = float('inf')
            for r, g, b_val_item in anchors:
                anchor_bgr = np.uint8([[[b_val_item, g, r]]])
                anchor_lab = cv2.cvtColor(anchor_bgr, cv2.COLOR_BGR2LAB)[0][0]
                dist = np.sqrt(
                    (l_val - float(anchor_lab[0]))**2 +
                    (a_val - float(anchor_lab[1]))**2 +
                    (b_val - float(anchor_lab[2]))**2
                )
                if dist < min_dist:
                    min_dist = dist
            distances[season] = min_dist

        # Determine classified season
        detected_season = min(distances, key=distances.get)

        # Calculate confidence using exponential similarity (Softmax style)
        gamma = 0.04  # sensitivity factor
        similarities = {s: np.exp(-gamma * d) for s, d in distances.items()}
        sum_sim = sum(similarities.values())
        confidences = {s: int(round((sim / sum_sim) * 100)) for s, sim in similarities.items()}
        confidence = confidences[detected_season]

        # Define curated seasonal palettes and descriptors
        palettes = {
            "Spring": {
                "office": ["#C28E75", "#D6C5A8", "#477876"],
                "party": ["#FF7F50", "#FFD700", "#008080"],
                "casual": ["#E9967A", "#F5F5DC", "#20B2AA"],
                "explanation_undertone": "warm golden/peach",
                "season_descr": "Your skin radiates soft, golden warmth. Pastel oranges, bright cream, and warm teals will look exceptionally luminous on you."
            },
            "Summer": {
                "office": ["#B08B9E", "#708090", "#6A7B83"],
                "party": ["#DA8A9F", "#9370DB", "#4682B4"],
                "casual": ["#FFB6C1", "#E6E6FA", "#778899"],
                "explanation_undertone": "cool rosy/pink",
                "season_descr": "Your skin features soft, rosy undertones. Dusty rose pinks, soft lavenders, and cool slate grays will enhance your elegant, cool contrast."
            },
            "Autumn": {
                "office": ["#8A5E38", "#556B2F", "#C2A67D"],
                "party": ["#E05A47", "#B8860B", "#2E8B57"],
                "casual": ["#D2691E", "#8FBC8F", "#F5F5DC"],
                "explanation_undertone": "warm bronze/honey",
                "season_descr": "You have rich golden undertones and deep features. Terracotta, mustard gold, and earthy olive greens complement your natural warmth perfectly."
            },
            "Winter": {
                "office": ["#1F3A60", "#0E5033", "#4A4A4A"],
                "party": ["#4169E1", "#00A86B", "#C71585"],
                "casual": ["#4682B4", "#2E8B57", "#E0115F"],
                "explanation_undertone": "cool high-contrast",
                "season_descr": "Your skin has a striking cool undertone. Bold, saturated colors like royal blue, emerald green, and vivid ruby red will make you stand out beautifully."
            }
        }

        # Lightness description (OpenCV maps L* from 0-100 to 0-255)
        if l_val > 190:
            lightness_descr = "fair porcelain"
        elif l_val > 140:
            lightness_descr = "light"
        elif l_val > 95:
            lightness_descr = "medium/tan"
        else:
            lightness_descr = "deep/rich"

        # Generate explainable AI description
        undertone = palettes[detected_season]["explanation_undertone"]
        season_descr = palettes[detected_season]["season_descr"]
        explanation = f"We detected {undertone} undertones and a {lightness_descr} skin level. This places you in the {detected_season} seasonal color family. {season_descr}"

        # Generate occasion specific palettes and messages
        palettes_out = {}
        for occ in ["office", "party", "casual"]:
            selected_palette = palettes[detected_season][occ]
            palettes_out[occ] = {
                "primary_color": selected_palette[0],
                "secondary_color": selected_palette[1],
                "accent_color": selected_palette[2],
                "message": _get_gendered_stylist_tip(detected_season, occ, gender)
            }

        return {
            "detected_category": f"{detected_season} Season",
            "confidence": confidence,
            "explanation": explanation,
            "palettes": palettes_out
        }

    except Exception as e:
        print(f"Critical Error: {e}")
        default_palettes = {}
        for occ in ["office", "party", "casual"]:
            default_palettes[occ] = {
                "primary_color": "#6C63FF",
                "secondary_color": "#FF6584",
                "accent_color": "#FFC857",
                "message": f"Styling engine running in safe mode. Error: {e}"
            }
        return {
            "detected_category": "Unknown Season",
            "confidence": 50,
            "explanation": f"Oops! We encountered an error during color analysis: {e}. Using a default balanced palette.",
            "palettes": default_palettes
        }