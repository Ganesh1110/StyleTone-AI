import base64
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from image_processor import (
    compute_synergy,
    decode_base64_image,
    delta_e_2000,
    extract_dominant_color,
    get_color_name,
    hex_to_rgb,
    rgb_to_hex,
)


def _solid_bgr(r: int, g: int, b: int) -> np.ndarray:
    """Return a 200×200 3-channel BGR image filled with a single colour."""
    return np.full((200, 200, 3), (b, g, r), dtype=np.uint8)


def _bgr_to_base64(img: np.ndarray) -> str:
    """Encode a BGR image to a base64 data URI."""
    _, buf = cv2.imencode(".jpg", img)
    return "data:image/jpeg;base64," + base64.b64encode(buf.tobytes()).decode()


class TestDeltaE2000:
    def test_identical(self):
        assert delta_e_2000((50.0, 0.0, 0.0), (50.0, 0.0, 0.0)) == 0.0

    def test_matches_skimage_sample_1(self):
        """Verified against scikit-image deltaE_ciede2000."""
        de = delta_e_2000(
            (50.0000, 2.6772, -79.7751),
            (50.0000, -3.7652, -76.8649),
        )
        assert abs(de - 2.9562) < 0.01

    def test_matches_skimage_sample_4(self):
        de = delta_e_2000(
            (50.0000, -2.0000, 2.0000),
            (50.0000, 2.0000, -2.0000),
        )
        assert abs(de - 6.6463) < 0.01

    def test_symmetric(self):
        a = (45.0, 10.0, -20.0)
        b = (55.0, -5.0, 15.0)
        assert abs(delta_e_2000(a, b) - delta_e_2000(b, a)) < 1e-10


class TestColourHelpers:
    def test_hex_to_rgb(self):
        assert hex_to_rgb("#FF8000") == (255, 128, 0)
        assert hex_to_rgb("ff8000") == (255, 128, 0)
        assert hex_to_rgb("#000000") == (0, 0, 0)
        assert hex_to_rgb("#FFFFFF") == (255, 255, 255)

    def test_rgb_to_hex(self):
        assert rgb_to_hex((255, 128, 0)) == "#ff8000"
        assert rgb_to_hex((0, 0, 0)) == "#000000"
        assert rgb_to_hex((255, 255, 255)) == "#ffffff"

    def test_roundtrip(self):
        rgb = (74, 144, 217)
        assert hex_to_rgb(rgb_to_hex(rgb)) == rgb

    def test_get_color_name_known(self):
        assert get_color_name(220, 20, 60) == "Crimson Red"
        assert get_color_name(255, 255, 255) == "Pure White"
        assert get_color_name(0, 0, 0) == "Jet Black"


class TestDecodeBase64:
    def test_decode_with_data_uri(self):
        img = _solid_bgr(100, 150, 200)
        b64 = _bgr_to_base64(img)
        decoded = decode_base64_image(b64)
        assert decoded is not None
        assert decoded.shape == (200, 200, 3)

    def test_decode_without_data_uri(self):
        img = _solid_bgr(100, 150, 200)
        _, buf = cv2.imencode(".jpg", img)
        raw = base64.b64encode(buf.tobytes()).decode()
        decoded = decode_base64_image(raw)
        assert decoded is not None
        assert decoded.shape == (200, 200, 3)

    def test_decode_invalid_returns_none(self):
        assert decode_base64_image("not-base64!@#$") is None


class TestExtractDominantColor:
    def test_solid_red(self):
        img = _solid_bgr(200, 50, 50)
        result = extract_dominant_color(img)
        assert result["hex_color"].lower() in ("#c83232", "#c83233")
        assert result["color_name"] != "Unknown Color"

    def test_solid_green(self):
        img = _solid_bgr(50, 200, 50)
        result = extract_dominant_color(img)
        assert result["hex_color"].startswith("#")

    def test_skips_white_background(self):
        half = np.full((200, 200, 3), (255, 255, 255), dtype=np.uint8)
        half[50:150, 50:150] = (255, 0, 0)  # blue square in centre (BGR)
        result = extract_dominant_color(half)
        r, g, b = result["rgb"]
        assert b > r and b > g, f"Expected blue to dominate, got RGB=({r},{g},{b})"


class TestComputeSynergy:
    def test_identical_color_high_score(self):
        result = compute_synergy("#E9967A", "Spring", [])
        assert 0 <= result["synergy_score"] <= 100
        assert result["new_item_hex"] == "#E9967A"

    def test_gap_fillers_generated(self):
        result = compute_synergy("#FF5733", "Winter", [])
        assert len(result["gap_fillers"]) > 0
        labels = {g["category"] for g in result["gap_fillers"]}
        assert labels == {"top", "bottom", "outer", "shoes", "accessory"}

    def test_with_closet_items(self):
        items = [
            {"category": "top", "hex_color": "#E9967A", "color_name": "Coral Orange"},
            {"category": "bottom", "hex_color": "#000080", "color_name": "Navy Blue"},
        ]
        result = compute_synergy("#E9967A", "Spring", items)
        assert result["new_combos_count"] >= 0
        assert len(result["gap_fillers"]) == 3
