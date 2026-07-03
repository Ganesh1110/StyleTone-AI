import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import base64
import logging
import re
import ipaddress
from typing import Optional
from urllib.parse import urlparse

import cv2
import numpy as np
import requests
from bs4 import BeautifulSoup
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from image_processor import process_selfie, hex_to_rgb, rgb_to_hex

logger = logging.getLogger(__name__)

app = FastAPI(title="StyleAI Personal Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MAX_IMAGE_BYTES = 10 * 1024 * 1024
VALID_GENDERS = {"male", "female", "neutral"}
VALID_OCCASIONS = {"office", "party", "casual"}


class ImageRequest(BaseModel):
    image: str
    occasion: Optional[str] = "casual"
    gender: Optional[str] = "neutral"


class DressUrlRequest(BaseModel):
    url: str
    occasion: str


class ClothingRequest(BaseModel):
    image: str


# --- SSRF SAFETY ---
def _is_safe_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
        if parsed.scheme != "https":
            logger.warning("Blocked non-https URL: %s", url)
            return False
        host = parsed.hostname
        if not host:
            return False
        try:
            addr = ipaddress.ip_address(host)
            if addr.is_private or addr.is_loopback or addr.is_link_local:
                logger.warning("Blocked private IP URL: %s", url)
                return False
        except ValueError:
            pass
        return True
    except Exception as e:
        logger.warning("URL validation error for %s: %s", url, e)
        return False


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
        dist = (r - rgb[0]) ** 2 + (g - rgb[1]) ** 2 + (b - rgb[2]) ** 2
        if dist < min_dist:
            min_dist = dist
            closest_name = name
    return closest_name


@app.post("/recommend")
async def get_color_recommendation(request: ImageRequest):
    if not request.image:
        raise HTTPException(status_code=400, detail="No image provided")

    if len(request.image) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=400, detail="Image too large (max 10MB)")

    if request.gender and request.gender.lower() not in VALID_GENDERS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid gender. Must be one of: {', '.join(VALID_GENDERS)}",
        )

    if request.occasion and request.occasion.lower() not in VALID_OCCASIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid occasion. Must be one of: {', '.join(VALID_OCCASIONS)}",
        )

    try:
        result = process_selfie(request.image, request.gender)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("Server error in /recommend: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail="Analysis failed. Please try again.")


@app.post("/scrape-dress")
async def analyze_dress(request: DressUrlRequest):
    if not _is_safe_url(request.url):
        raise HTTPException(
            status_code=400,
            detail="Invalid or unsafe URL. Only public HTTPS URLs are allowed.",
        )

    try:
        headers = {
            'User-Agent': (
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            )
        }
        response = requests.get(request.url, headers=headers, timeout=10)
        if response.status_code != 200:
            return {"error": "Could not fetch the webpage."}

        soup = BeautifulSoup(response.text, 'html.parser')
        img_tag = (
            soup.find('img', {'class': re.compile(r'product|main|hero', re.I)})
            or soup.find('img')
        )

        if img_tag and img_tag.get('src'):
            img_url = img_tag['src']
            if not img_url.startswith('http'):
                img_url = requests.compat.urljoin(request.url, img_url)
            return {
                "dress_image_url": img_url,
                "message": "Dress found! This color palette would look great on you.",
            }
        else:
            return {"error": "Could not find a product image on this page."}
    except requests.Timeout:
        return {"error": "Request timed out. Please try a different URL."}
    except Exception as e:
        logger.warning("Dress scraping failed for %s: %s", request.url, e)
        return {"error": f"Scraping failed: {str(e)}"}


@app.post("/analyze-clothing")
async def analyze_clothing(request: ClothingRequest):
    if not request.image:
        raise HTTPException(status_code=400, detail="No image provided")

    if len(request.image) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=400, detail="Image too large (max 10MB)")

    try:
        img_data = request.image
        if "," in img_data:
            img_data = img_data.split(",")[1]

        img_bytes = base64.b64decode(img_data)
        np_arr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image encoding")

        h, w, _ = img.shape
        cy, cx = h // 2, w // 2
        dy, dx = int(h * 0.3), int(w * 0.3)
        crop = img[cy - dy:cy + dy, cx - dx:cx + dx]

        pixels = crop.reshape(-1, 3)
        pixels = np.float32(pixels)

        criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0)
        compactness, labels, centers = cv2.kmeans(
            pixels, 3, None, criteria, 10, cv2.KMEANS_RANDOM_CENTERS
        )

        unique_labels, counts = np.unique(labels, return_counts=True)
        sorted_indices = np.argsort(-counts)

        selected_bgr = None
        for idx in sorted_indices:
            bgr_center = centers[idx]
            b, g, r = int(bgr_center[0]), int(bgr_center[1]), int(bgr_center[2])

            is_white_bg = (
                r > 220 and g > 220 and b > 220
                and max(r, g, b) - min(r, g, b) < 20
            )
            is_black_bg = (r < 45 and g < 45 and b < 45)

            if not is_white_bg and not is_black_bg:
                selected_bgr = bgr_center
                break

        if selected_bgr is None:
            selected_bgr = centers[sorted_indices[0]]

        r, g, b = int(selected_bgr[2]), int(selected_bgr[1]), int(selected_bgr[0])

        hex_color = '#{:02x}{:02x}{:02x}'.format(r, g, b)
        color_name = get_color_name(r, g, b)

        return {
            "hex_color": hex_color,
            "rgb": [r, g, b],
            "color_name": color_name,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Clothing color analysis failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail="Clothing analysis failed. Please try again.")


@app.get("/")
async def root():
    return {"message": "StyleAI API is running."}
