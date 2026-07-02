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
    """
    Fetches a color palette from thecolorapi.com based on the exact skin tone.
    Then adjusts the colors for the specific occasion.
    """
    try:
        # 1. Get Analogous colors (usually 5 colors) from the API
        url = f"https://www.thecolorapi.com/scheme?hex={skin_hex.replace('#','')}&mode=analogic&count=5"
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            # Extract 5 hex codes from the API response
            raw_colors = [c['hex']['value'] for c in data['colors']]
            
            # 2. Filter/Adjust them for the occasion
            adjusted_colors = [adjust_color_for_occasion(c, occasion) for c in raw_colors]
            
            # 3. Pick the best 3: Primary (closest to skin), Secondary, Accent
            # We'll just take the first 3 for simplicity
            return {
                "primary_color": adjusted_colors[0],
                "secondary_color": adjusted_colors[1],
                "accent_color": adjusted_colors[2],
                "detected_category": f"Dynamic ({occasion.capitalize()})",
                "message": f"✨ Perfect {occasion} look! Your exact skin tone pairs beautifully with these dynamic hues."
            }
        else:
            raise Exception("API returned non-200")
            
    except Exception as e:
        print(f"API Fetch failed: {e}. Falling back to static JSON.")
        return None  # Fallback to JSON

def process_selfie(base64_image: str, occasion: str):
    try:
        # --- 1. EXTRACT SKIN TONE (Same K-Means logic as before) ---
        if base64_image.startswith("data:image"):
            base64_image = base64_image.split(",")[1]
        
        img_bytes = base64.b64decode(base64_image)
        np_arr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Failed to decode image")

        # White balance & K-Means to find skin color
        img_lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(img_lab)
        l_avg = np.mean(l)
        l = np.clip(l + (128 - l_avg), 0, 255).astype(np.uint8)
        img_lab = cv2.merge([l, a, b])
        img = cv2.cvtColor(img_lab, cv2.COLOR_LAB2BGR)

        pixels = img.reshape(-1, 3)
        kmeans = KMeans(n_clusters=2, n_init=10, random_state=42)
        kmeans.fit(pixels)
        dominant_colors = kmeans.cluster_centers_.astype(int)

        # Select the brighter cluster (skin)
        skin_rgb = None
        max_l = -1
        for color in dominant_colors:
            lab_color = cv2.cvtColor(np.uint8([[color]]), cv2.COLOR_BGR2LAB)[0][0]
            if lab_color[0] > max_l:
                max_l = lab_color[0]
                skin_rgb = color
        if skin_rgb is None:
            skin_rgb = dominant_colors[0]
            
        # Convert skin RGB to HEX
        skin_hex = rgb_to_hex((skin_rgb[2], skin_rgb[1], skin_rgb[0])) # BGR to RGB

        # --- 2. FETCH DYNAMIC PALETTE (API FIRST) ---
        result = fetch_palette_from_api(skin_hex, occasion)
        
        if result:
            return result

        # --- 3. FALLBACK TO STATIC JSON (if API fails) ---
        print("Falling back to static color_matrix.json")
        skin_lab = cv2.cvtColor(np.uint8([[skin_rgb]]), cv2.COLOR_BGR2LAB)[0][0]
        l_channel = skin_lab[0]
        a_channel = skin_lab[1]

        depth = "Deep" if l_channel < 60 else "Light"
        if a_channel > 8:
            tone = "Warm"
        elif a_channel < -4:
            tone = "Cool"
        else:
            tone = "Neutral"
        
        category = f"{tone}_{depth}"
        if category not in COLOR_MATRIX["skin_categories"]:
            category = "Neutral_Light"

        palette = COLOR_MATRIX["skin_categories"][category]
        if occasion == "office":
            recommended = palette["office_filter"]
        elif occasion == "party":
            recommended = palette["party_filter"]
        else:
            recommended = palette["harmonious_palette"]
        
        while len(recommended) < 3:
            recommended.append("#CCCCCC")
        
        return {
            "detected_category": f"Static: {category}",
            "primary_color": recommended[0],
            "secondary_color": recommended[1],
            "accent_color": recommended[2],
            "message": f"✨ Static fallback for {occasion}."
        }

    except Exception as e:
        print(f"Critical Error: {e}")
        return {
            "detected_category": "Error",
            "primary_color": "#6C63FF",
            "secondary_color": "#FF6584",
            "accent_color": "#FFC857",
            "message": "Oops! Something went wrong. Using default safe colors."
        }