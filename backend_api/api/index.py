import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import logging
import re
import ipaddress
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from image_processor import (
    compute_synergy,
    decode_base64_image,
    decode_image_bytes,
    extract_dominant_color,
    process_selfie,
)

logger = logging.getLogger(__name__)

app = FastAPI(title="StyleAI Personal Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_SCRAPE_IMAGE_BYTES = 8 * 1024 * 1024
VALID_GENDERS = {"male", "female", "neutral"}
VALID_OCCASIONS = {"office", "party", "casual"}


class ImageRequest(BaseModel):
    image: str
    occasion: Optional[str] = "casual"
    gender: Optional[str] = "neutral"
    face_already_cropped: bool = False
    hair_color: Optional[str] = None
    eye_color: Optional[str] = None


class DressUrlRequest(BaseModel):
    url: str
    season: str = "Spring Season"
    closet_items: List[Dict[str, Any]] = []


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
        result = process_selfie(
            request.image,
            gender=request.gender,
            face_already_cropped=request.face_already_cropped,
            hair_color=request.hair_color,
            eye_color=request.eye_color,
        )
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

    headers = {
        'User-Agent': (
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        )
    }

    try:
        response = requests.get(request.url, headers=headers, timeout=10)
        if response.status_code != 200:
            return {"error": "Could not fetch the webpage."}

        soup = BeautifulSoup(response.text, 'html.parser')
        img_tag = (
            soup.find('img', {'class': re.compile(r'product|main|hero', re.I)})
            or soup.find('img')
        )
        if not (img_tag and img_tag.get('src')):
            return {"error": "Could not find a product image on this page."}

        img_url = img_tag['src']
        if not img_url.startswith('http'):
            img_url = requests.compat.urljoin(request.url, img_url)

        if not _is_safe_url(img_url):
            return {"error": "Product image URL failed the safety check."}

        img_response = requests.get(img_url, headers=headers, timeout=10)
        if img_response.status_code != 200:
            return {"dress_image_url": img_url, "error": "Could not download the product image."}
        if len(img_response.content) > MAX_SCRAPE_IMAGE_BYTES:
            return {"dress_image_url": img_url, "error": "Product image is too large to analyze."}

        cv_img = decode_image_bytes(img_response.content)
        if cv_img is None:
            return {"dress_image_url": img_url, "error": "Could not decode the product image."}

        dominant = extract_dominant_color(cv_img)
        synergy = compute_synergy(dominant["hex_color"], request.season, request.closet_items)
        synergy["new_item_color_name"] = dominant["color_name"]

        return {
            "dress_image_url": img_url,
            "color_hex": dominant["hex_color"],
            "color_name": dominant["color_name"],
            **synergy,
        }

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
        img = decode_base64_image(request.image)
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image encoding")
        return extract_dominant_color(img)

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
        img = decode_base64_image(request.image)
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image encoding")

        dominant = extract_dominant_color(img)

        # --- Compute synergy against palette + wardrobe ----------------------
        synergy = compute_synergy(dominant["hex_color"], request.season, request.closet_items)
        synergy["new_item_color_name"] = dominant["color_name"]

        return synergy

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Synergy analysis failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    return {"message": "StyleAI API is running."}
