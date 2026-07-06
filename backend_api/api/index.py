import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import base64
import logging
import re
import ipaddress
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

import cv2
import numpy as np
import requests
from bs4 import BeautifulSoup
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from image_processor import (
    compute_synergy,
    get_color_name,
    hex_to_rgb,
    process_selfie,
    rgb_to_hex,
)

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


class SynergyRequest(BaseModel):
    image: str
    season: str = "Spring Season"
    closet_items: List[Dict[str, Any]] = []


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


# get_color_name and COLORS are now defined in image_processor.py and imported above.


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
        raise HTTPException(status_code=500, detail=str(e))


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
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/analyze-synergy")
async def analyze_synergy(request: SynergyRequest):
    """Extract the dominant colour of a new garment then compute its closet
    synergy score against the user's active seasonal palette and wardrobe."""
    if not request.image:
        raise HTTPException(status_code=400, detail="No image provided")
    if len(request.image) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=400, detail="Image too large (max 10 MB)")

    try:
        img_data = request.image
        if "," in img_data:
            img_data = img_data.split(",")[1]

        img_bytes = base64.b64decode(img_data)
        np_arr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image encoding")

        # --- K-Means dominant colour extraction (same as /analyze-clothing) ---
        h, w, _ = img.shape
        cy, cx = h // 2, w // 2
        dy, dx = int(h * 0.3), int(w * 0.3)
        crop = img[cy - dy:cy + dy, cx - dx:cx + dx]

        pixels = crop.reshape(-1, 3).astype(np.float32)
        criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0)
        _, labels, centers = cv2.kmeans(
            pixels, 3, None, criteria, 10, cv2.KMEANS_RANDOM_CENTERS
        )
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
        new_hex = '#{:02x}{:02x}{:02x}'.format(r, g, b)
        color_name = get_color_name(r, g, b)

        # --- Compute synergy against palette + wardrobe ----------------------
        synergy = compute_synergy(new_hex, request.season, request.closet_items)
        synergy["new_item_color_name"] = color_name

        return synergy

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Synergy analysis failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    return {"message": "StyleAI API is running."}
