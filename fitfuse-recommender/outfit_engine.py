"""
Outfit matching rules for the Smart Outfit feature.

Pure functions only (no Firestore, no models) so they are cheap to unit test.
An outfit suggestion answers "what from my wardrobe goes WITH this photo?":

  1. Slots:   which categories to fill, given what the uploaded photo is.
  2. Color:   how well a candidate's dominant color pairs with the photo's.
  3. Weather: a small nudge from the item's name (coat in the cold, tee in the heat).
  4. Occasion: candidates whose occasion matches the requested one rank higher.
"""
import colorsys
import io

from PIL import Image

# Categories the user can put items in (same list as the wardrobe screen).
CATEGORIES = ("Tops", "Bottoms", "Dresses", "Shoes", "Accessories")

# Uploaded category -> categories to suggest, in display order. A dress already covers top and
# bottom, so only shoes are suggested for it.
SLOTS = {
    "Tops": ("Bottoms", "Shoes"),
    "Bottoms": ("Tops", "Shoes"),
    "Dresses": ("Shoes",),
    "Shoes": ("Tops", "Bottoms"),
    "Accessories": ("Tops", "Bottoms", "Shoes"),
}
DEFAULT_SLOTS = ("Tops", "Bottoms", "Shoes")  # used when the photo's category is unknown

OCCASIONS = ("All", "Weddings", "Casual", "Work", "Daily Wear", "Parties")

_WARM_WORDS = {"sunny", "summer", "clear", "hot", "heat", "warm"}
_COLD_WORDS = {"cold", "winter", "snow", "snowy", "freezing", "chilly"}
_WET_WORDS = {"rain", "rainy", "drizzle", "thunderstorm", "storm", "shower"}

_COLD_ITEMS = ("coat", "jacket", "hoodie", "sweater", "sweatshirt", "jumper", "cardigan",
               "boot", "puffer", "wool", "fleece", "parka")
_WARM_ITEMS = ("shorts", "sandal", "tank", "linen", "tee", "t-shirt", "tshirt", "polo", "slipper")
_WET_ITEMS = ("coat", "jacket", "boot", "raincoat", "parka", "waterproof")


def slots_for(category):
    """Categories to fill for an uploaded photo of `category` (None = unknown)."""
    return SLOTS.get(category, DEFAULT_SLOTS)


# ---------------------------------------------------------------- color

def dominant_hsv(image_bytes):
    """
    Dominant color of the garment as (hue 0-360, saturation 0-1, value 0-1), or None.
    Product photos usually sit on a plain backdrop, so pixels close to the backdrop color
    (taken from the image corners) are ignored.
    """
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except Exception:
        return None
    img.thumbnail((96, 96))
    w, h = img.size
    px = img.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = tuple(sorted(c[i] for c in corners)[1] for i in range(3))  # per-channel median

    def far_from_bg(p):
        return sum((p[i] - bg[i]) ** 2 for i in range(3)) > 40 ** 2

    # Ignore the outer 10% so frames/shadows at the edge do not dominate.
    mx, my = max(1, w // 10), max(1, h // 10)
    pixels = [px[x, y] for y in range(my, h - my) for x in range(mx, w - mx)]
    garment = [p for p in pixels if far_from_bg(p)]
    if len(garment) < max(20, len(pixels) // 20):  # backdrop covers (almost) everything
        garment = pixels
    if not garment:
        return None

    # Most common color among quantised buckets (16 levels per channel).
    buckets = {}
    for r, g, b in garment:
        key = (r >> 4, g >> 4, b >> 4)
        n, sr, sg, sb = buckets.get(key, (0, 0, 0, 0))
        buckets[key] = (n + 1, sr + r, sg + g, sb + b)
    n, sr, sg, sb = max(buckets.values(), key=lambda v: v[0])
    r, g, b = sr / n / 255, sg / n / 255, sb / n / 255
    hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)
    return (hh * 360.0, ss, vv)


def color_family(hsv):
    """Coarse family: black, white, gray, earth, denim/navy, or 'color' (a chromatic color)."""
    h, s, v = hsv
    if v < 0.22:
        return "black"
    if s < 0.12:
        return "white" if v > 0.82 else "gray"
    if s < 0.40 and 15 <= h <= 55:
        return "earth"  # beige, cream, tan, khaki
    if 195 <= h <= 250 and s < 0.75 and v < 0.72:
        return "denim"  # navy and denim blues go with most things
    return "color"


def _hue_gap(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def color_harmony(a, b):
    """0-1: how well two dominant colors (h, s, v) look together. Unknown colors score neutral."""
    if a is None or b is None:
        return 0.6
    fa, fb = color_family(a), color_family(b)
    neutrals = {"black", "white", "gray", "earth", "denim"}
    if fa in neutrals and fb in neutrals:
        if {fa, fb} == {"black", "denim"}:
            return 0.7  # navy/denim with black is the one neutral pairing that reads as a mismatch
        return 0.9
    if fa in neutrals or fb in neutrals:
        return 0.88  # one neutral + one color always works
    gap = _hue_gap(a[0], b[0])
    loud = a[1] > 0.6 and b[1] > 0.6
    if gap <= 25:
        return 0.78  # monochrome / tone on tone
    if gap <= 60:
        return 0.72  # analogous
    if 150 <= gap <= 210:
        return 0.55 if loud else 0.8  # complementary: fine when one side is muted
    return 0.25 if loud else 0.45  # two different bright colors clash


# ---------------------------------------------------------------- weather / occasion

def weather_kind(weather):
    """'warm', 'cold', 'wet' or None for a weather label such as 'Sunny', 'Winter', 'Rain'."""
    if not weather:
        return None
    words = set(weather.lower().replace("/", " ").split())
    if words & _WET_WORDS:
        return "wet"
    if words & _COLD_WORDS:
        return "cold"
    if words & _WARM_WORDS:
        return "warm"
    return None


def weather_fit(kind, name):
    """-1..1: how well an item's name suits the weather (0 = no signal)."""
    if kind is None or not name:
        return 0.0
    n = name.lower()
    cold = any(w in n for w in _COLD_ITEMS)
    warm = any(w in n for w in _WARM_ITEMS)
    if kind == "wet":
        return 1.0 if any(w in n for w in _WET_ITEMS) else (-0.5 if warm else 0.0)
    if kind == "cold":
        return 1.0 if cold else (-1.0 if warm else 0.0)
    return 1.0 if warm else (-1.0 if cold else 0.0)  # warm


def occasion_from_label(label):
    """The requested occasion if the dropdown label is one (e.g. 'Casual'), else None."""
    if not label:
        return None
    for o in OCCASIONS:
        if o != "All" and o.lower() == label.strip().lower():
            return o
    return None


def occasion_fit(requested, item_occasion):
    """1.0 match, 0.6 item is for 'All' occasions, 0.2 different occasion, 0.6 nothing requested."""
    if requested is None:
        return 0.6
    item_occasion = item_occasion or "All"
    if item_occasion == requested:
        return 1.0
    if item_occasion == "All":
        return 0.6
    return 0.2


# ---------------------------------------------------------------- ranking

def score_item(upload_hsv, item_hsv, weather, requested_occasion, name, item_occasion):
    """Overall 0-1 compatibility of a wardrobe item with the uploaded photo."""
    color = color_harmony(upload_hsv, item_hsv)
    occ = occasion_fit(requested_occasion, item_occasion)
    wx = (weather_fit(weather_kind(weather), name) + 1) / 2  # 0..1, 0.5 = no signal
    return 0.60 * color + 0.25 * occ + 0.15 * wx


def reason_for(upload_hsv, item_hsv, weather, requested_occasion, name, item_occasion):
    """Short human-readable reason shown under a suggestion."""
    parts = []
    h = color_harmony(upload_hsv, item_hsv)
    if upload_hsv is not None and item_hsv is not None:
        if h >= 0.85:
            parts.append("colors go well together")
        elif h >= 0.7:
            parts.append("colors complement each other")
    if requested_occasion and item_occasion == requested_occasion:
        parts.append(f"made for {requested_occasion.lower()} wear")
    fit = weather_fit(weather_kind(weather), name)
    if fit > 0:
        parts.append(f"suits {weather.lower()} weather")
    return ", ".join(parts).capitalize() if parts else "Closest match in your wardrobe"


# ---------------------------------------------------------------- "similar outfit" mode

def color_similarity(a, b):
    """0-1: how alike two dominant colors look (1 = same color). Unknown colors score neutral."""
    if a is None or b is None:
        return 0.5
    fa, fb = color_family(a), color_family(b)
    if fa == "color" and fb == "color":
        return max(0.0, 1 - _hue_gap(a[0], b[0]) / 90.0) * (1 - 0.5 * abs(a[2] - b[2]))
    if fa != "color" and fb != "color":
        return max(0.0, 1 - abs(a[2] - b[2]) * 1.5)  # two neutrals: compare lightness
    return 0.2  # a color against a neutral


def minmax(values):
    """Scale to 0-1 (all equal -> all 1.0) so the best look-alike in a slot always scores 1."""
    lo, hi = min(values), max(values)
    return [1.0] * len(values) if hi - lo < 1e-9 else [(v - lo) / (hi - lo) for v in values]


def score_similar(sim_norm, upload_hsv, item_hsv, weather, requested_occasion, name, item_occasion):
    """Overall 0-1 score of how well an item resembles the uploaded outfit photo."""
    wx = (weather_fit(weather_kind(weather), name) + 1) / 2
    return (0.60 * sim_norm + 0.20 * color_similarity(upload_hsv, item_hsv)
            + 0.10 * occasion_fit(requested_occasion, item_occasion) + 0.10 * wx)


def reason_similar(sim_norm, upload_hsv, item_hsv):
    parts = []
    if sim_norm >= 0.8:
        parts.append("very similar style")
    elif sim_norm >= 0.5:
        parts.append("similar style")
    if color_similarity(upload_hsv, item_hsv) >= 0.7:
        parts.append("matching colors")
    return ", ".join(parts).capitalize() if parts else "Closest match in your wardrobe"
