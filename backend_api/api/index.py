import sys
import os
# Add the parent directory to path so we can import image_processor
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from image_processor import process_selfie
from bs4 import BeautifulSoup
import requests
import re
from asgiref.wsgi import AsgiToWsgi

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

class DressUrlRequest(BaseModel):
    url: str
    occasion: str

# --- ENDPOINT 1: Skin Analysis ---
@app.post("/recommend")
async def get_color_recommendation(request: ImageRequest):
    if not request.image:
        raise HTTPException(status_code=400, detail="No image provided")
    occasion = request.occasion if request.occasion in ["office", "party", "casual"] else "casual"
    try:
        result = process_selfie(request.image, occasion)
        return result
    except Exception as e:
        print(f"Server error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- ENDPOINT 2: Dress Scraper ---
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
    return {"message": "StyleAI API is running on Vercel!"}

# --- VERCEL ENTRY POINT (WSGI adapter) ---
application = AsgiToWsgi(app)