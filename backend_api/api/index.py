import sys
import os
# Add the parent directory to path so we can import image_processor
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import base64
import cv2
import numpy as np
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from image_processor import process_selfie
from bs4 import BeautifulSoup
import requests
import re
import colorsys  # <-- ADDED for HSV color math
import json

app = FastAPI(title="StyleAI Personal Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ImageRequest(BaseModel):
    image: str
    occasion: Optional[str] = "casual"
    gender: Optional[str] = "neutral"

class DressUrlRequest(BaseModel):
    url: str
    occasion: str

class ClothingRequest(BaseModel):
    image: str

# --- HELPER FUNCTIONS FOR COLOR MATH ---
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
        # Gentle mute: reduce saturation by 20%, darken slightly by 10%
        s = max(0.3, s * 0.8)
        v = max(0.4, v * 0.9)
    elif occasion == "party":
        # Boost vibrance: increase saturation by 20%, brighten by 10%
        s = min(1.0, s * 1.2)
        v = min(1.0, v * 1.1)
        
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return rgb_to_hex((r*255, g*255, b*255))

# --- API PALETTE AGGREGATOR ---
def fetch_palette_from_api(occasion):
    """Fallback: Fetches a design palette from a public API if database breaks."""
    try:
        url = "http://colormind.io/api/"
        data = json.dumps({"model": "default"})
        res = requests.post(url, data=data, timeout=5)
        if res.status_code == 200:
            palette = res.json().get("result", [])
            hex_palette = [rgb_to_hex(color) for color in palette[:3]]
            adjusted_colors = [adjust_color_for_occasion(color, occasion) for color in hex_palette]
            
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
            raise Exception("API returned non-200 status")
            
    except Exception as e:
        print(f"API Fetch failed: {e}")
        return None  # Fallback to JSON

# --- ENDPOINT 1: Skin Analysis (UPDATED to use new color logic) ---
@app.post("/recommend")
async def get_color_recommendation(request: ImageRequest):
    if not request.image:
        raise HTTPException(status_code=400, detail="No image provided")
    
    try:
        # The image_processor now processes and returns all occasion recommendations in parallel
        result = process_selfie(request.image, request.gender)
        return result
    except Exception as e:
        print(f"Server error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- ENDPOINT 2: Dress Scraper (Unchanged) ---
@app.post("/scrape-dress")
async def analyze_dress(request: DressUrlRequest):
    try:
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
        response = requests.get(request.url, headers=headers, timeout=10)
        if response.status_code != 200:
            return {"error": "Could not fetch the webpage."}
        
        soup = BeautifulSoup(response.text, 'html.parser')
        img_tag = soup.find('img', {'class': re.compile(r'product|main|hero', re.I)}) or soup.find('img')
        
        if img_tag and img_tag.get('src'):
            img_url = img_tag['src']
            if not img_url.startswith('http'):
                img_url = requests.compat.urljoin(request.url, img_url)
            return {
                "dress_image_url": img_url,
                "message": "Dress found! This color palette would look great on you."
            }
        else:
            return {"error": "Could not find a product image on this page."}
    except Exception as e:
        return {"error": f"Scraping failed: {str(e)}"}


# Color classification database
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

def get_color_name(r, g, b):
    closest_name = "Unknown Color"
    min_dist = float('inf')
    for name, rgb in COLORS.items():
        dist = (r - rgb[0])**2 + (g - rgb[1])**2 + (b - rgb[2])**2
        if dist < min_dist:
            min_dist = dist
            closest_name = name
    return closest_name

@app.post("/analyze-clothing")
async def analyze_clothing(request: ClothingRequest):
    if not request.image:
        raise HTTPException(status_code=400, detail="No image provided")
    
    try:
        # Strip base64 prefixes if present
        img_data = request.image
        if "," in img_data:
            img_data = img_data.split(",")[1]
            
        img_bytes = base64.b64decode(img_data)
        np_arr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image encoding")
        
        # Center crop the middle 60% of the image to focus on fabric color
        h, w, _ = img.shape
        cy, cx = h // 2, w // 2
        dy, dx = int(h * 0.3), int(w * 0.3)
        crop = img[cy - dy:cy + dy, cx - dx:cx + dx]
        
        # Reshape pixels and cast to float
        pixels = crop.reshape(-1, 3)
        pixels = np.float32(pixels)
        
        # Run K-Means clustering (K=1) to extract the single dominant color
        criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0)
        _, _, centers = cv2.kmeans(pixels, 1, None, criteria, 10, cv2.KMEANS_RANDOM_CENTERS)
        
        # Extracted color channels (OpenCV defaults to BGR)
        bgr = centers[0]
        r, g, b = int(bgr[2]), int(bgr[1]), int(bgr[0])
        
        # Get matching hex string and color name
        hex_color = '#{:02x}{:02x}{:02x}'.format(r, g, b)
        color_name = get_color_name(r, g, b)
        
        return {
            "hex_color": hex_color,
            "rgb": [r, g, b],
            "color_name": color_name
        }
        
    except Exception as e:
        print(f"Clothing color analysis failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- HEALTH CHECK ---
@app.get("/")
async def root():
    return {"message": "StyleAI API is running on Vercel with TRIAD color scheme!"}

# Vercel auto-detects `app` as the ASGI handler