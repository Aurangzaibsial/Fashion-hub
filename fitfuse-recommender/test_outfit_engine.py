"""Unit tests for outfit_engine (run: python -m pytest test_outfit_engine.py -q)."""
import io

from PIL import Image

import outfit_engine as oe


def _img(color, backdrop=(255, 255, 255), size=120):
    """A plain 'garment' rectangle on a backdrop, as JPEG bytes."""
    im = Image.new("RGB", (size, size), backdrop)
    im.paste(Image.new("RGB", (size // 2, size // 2), color), (size // 4, size // 4))
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


def test_slots_never_include_the_uploaded_category():
    for cat, slots in oe.SLOTS.items():
        assert cat not in slots
    assert oe.slots_for("Tops") == ("Bottoms", "Shoes")
    assert oe.slots_for("Bottoms") == ("Tops", "Shoes")
    assert oe.slots_for("Shoes") == ("Tops", "Bottoms")
    assert oe.slots_for("Dresses") == ("Shoes",)
    assert oe.slots_for(None) == oe.DEFAULT_SLOTS


def test_dominant_color_ignores_backdrop():
    h, s, v = oe.dominant_hsv(_img((200, 30, 30)))
    assert s > 0.7 and (h < 15 or h > 345)          # red, not the white backdrop
    h, s, v = oe.dominant_hsv(_img((20, 20, 20), backdrop=(240, 240, 240)))
    assert oe.color_family((h, s, v)) == "black"


def test_color_families():
    assert oe.color_family((0, 0.0, 0.05)) == "black"
    assert oe.color_family((0, 0.02, 0.95)) == "white"
    assert oe.color_family((0, 0.03, 0.5)) == "gray"
    assert oe.color_family((35, 0.25, 0.8)) == "earth"
    assert oe.color_family((215, 0.5, 0.45)) == "denim"
    assert oe.color_family((0, 0.9, 0.9)) == "color"


def test_harmony_neutrals_beat_clashing_brights():
    white, black, red = (0, 0, 0.95), (0, 0, 0.1), (0, 0.9, 0.9)
    green, blue = (120, 0.9, 0.8), (240, 0.95, 0.9)
    assert oe.color_harmony(white, red) > oe.color_harmony(red, green)
    assert oe.color_harmony(black, red) > oe.color_harmony(green, blue)
    assert oe.color_harmony(white, black) >= 0.85
    assert oe.color_harmony(None, red) == 0.6               # unknown color is neutral, never a crash


def test_harmony_is_symmetric():
    a, b = (10, 0.8, 0.8), (200, 0.4, 0.6)
    assert oe.color_harmony(a, b) == oe.color_harmony(b, a)


def test_weather():
    assert oe.weather_kind("Winter") == "cold" and oe.weather_kind("Sunny") == "warm"
    assert oe.weather_kind("Rainy") == "wet" and oe.weather_kind("Casual") is None
    assert oe.weather_fit("cold", "Wool Sweater") > 0 > oe.weather_fit("cold", "Beach Shorts")
    assert oe.weather_fit("warm", "Linen Tee") > 0 > oe.weather_fit("warm", "Puffer Coat")
    assert oe.weather_fit(None, "Wool Sweater") == 0


def test_occasion():
    assert oe.occasion_from_label("casual") == "Casual" and oe.occasion_from_label("Sunny") is None
    assert oe.occasion_fit("Work", "Work") > oe.occasion_fit("Work", "All") > oe.occasion_fit("Work", "Parties")


def test_ranking_prefers_matching_neutral_in_cold_weather():
    red_top = (0, 0.9, 0.9)
    good = oe.score_item(red_top, (0, 0, 0.1), "Winter", None, "Black Wool Trousers", "All")
    bad = oe.score_item(red_top, (120, 0.9, 0.8), "Winter", None, "Green Shorts", "All")
    assert good > bad


def test_similar_mode_scoring():
    red, pink, green, white = (0, 0.9, 0.9), (350, 0.8, 0.9), (120, 0.9, 0.8), (0, 0, 0.95)
    assert oe.color_similarity(red, pink) > oe.color_similarity(red, green)
    assert oe.color_similarity(red, red) > 0.45 and oe.color_similarity(None, red) == 0.5
    assert oe.minmax([0.6, 0.9, 0.75]) == [0.0, 1.0, 0.5] and oe.minmax([0.7, 0.7]) == [1.0, 1.0]
    close = oe.score_similar(1.0, red, pink, None, None, "Red Hoodie", "All")
    far = oe.score_similar(0.0, red, green, None, None, "Green Hoodie", "All")
    assert close > far
