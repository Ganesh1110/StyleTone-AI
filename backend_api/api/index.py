import sys
import os
# Add the parent directory to path so we can import image_processor
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from image_processor import process_selfie
from bs4 import BeautifulSoup
import requests
import re
import colorsys  # <-- ADDED for HSV color math

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
    occasion: str
    gender: Optional[str] = "neutral"

class DressUrlRequest(BaseModel):
    url: str
    occasion: str

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
        # Vibrant boost: increase saturation and brightness
        s = min(1.0, s * 1.3)
        v = min(1.0, v * 1.2)
    else:  # casual
        # Slightly soften
        s = s * 0.95
    
    r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
    return rgb_to_hex((r2*255, g2*255, b2*255))

def fetch_palette_from_api(skin_hex, occasion):
    """Fetches colors from thecolorapi.com using TRIAD mode for variety."""
    try:
        # --- USE TRIAD INSTEAD OF ANALOGIC (more variety) ---
        url = f"https://www.thecolorapi.com/scheme?hex={skin_hex.replace('#','')}&mode=triad&count=6"
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            raw_colors = [c['hex']['value'] for c in data['colors']]
            
            # Pick 3 distinct colors: index 0, 2, 4 (skips the closest ones)
            selected = [raw_colors[0], raw_colors[2], raw_colors[4]]
            
            # Adjust each color for the occasion
            adjusted_colors = [adjust_color_for_occasion(c, occasion) for c in selected]
            
            # --- OCCASION-SPECIFIC MESSAGES ---
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
    
    occasion = request.occasion if request.occasion in ["office", "party", "casual"] else "casual"
    
    try:
        # The image_processor now calls fetch_palette_from_api internally
        # Make sure your image_processor.py uses this new function!
        result = process_selfie(request.image, occasion, request.gender)
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

# --- HEALTH CHECK ---
@app.get("/")
async def root():
    return {"message": "StyleAI API is running on Vercel with TRIAD color scheme!"}

# Vercel auto-detects `app` as the ASGI handler