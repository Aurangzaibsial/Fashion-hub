"""
CLIP zero-shot helper.

Used for two things the ImageNet classifier is weak at:
  1. "Is this a clothing / footwear / accessory photo?"  (dress shoes, hoodies...)
  2. "Which wardrobe category does this photo belong to?" (Tops, Bottoms, ...)

If CLIP cannot be loaded (e.g. no internet on first start) every function
returns None and callers fall back to the ImageNet-only behaviour.
"""
import torch
from PIL import Image

CATEGORY_PROMPTS = {
    "Tops": "a photo of a shirt, t-shirt, hoodie, sweater or jacket",
    "Bottoms": "a photo of trousers, jeans, pants, shorts or a skirt",
    "Dresses": "a photo of a dress or a gown",
    "Shoes": "a photo of a pair of shoes, sneakers, boots or sandals",
    "Accessories": "a photo of a bag, hat, watch, belt, jewelry or sunglasses",
}
NON_CLOTHING_PROMPTS = [
    "a photo of an animal", "a photo of food", "a photo of a flower or plant",
    "a photo of a landscape or building", "a photo of a vehicle",
    "a photo of a computer or electronics", "a blank or plain colored image",
    "a photo of a person's face", "a screenshot or a document",
]
_CATEGORIES = list(CATEGORY_PROMPTS)
_TEXTS = list(CATEGORY_PROMPTS.values()) + NON_CLOTHING_PROMPTS
_FACE_INDEX = _TEXTS.index("a photo of a person's face")

_device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
_model = _processor = None
try:
    from transformers import CLIPModel, CLIPProcessor
    print("[*] Loading CLIP (clothing / category checks)...")
    _model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32").to(_device).eval()
    _processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
    print("[SUCCESS] CLIP ready")
except Exception as e:
    print(f"[WARN] CLIP unavailable, using ImageNet-only checks: {e}")


# Weapon check. ImageNet only knows a handful of weapon classes (cleaver, rifle, revolver...), so
# cartoon daggers, fantasy axes and loose ammunition slip past it. CLIP knows them all, but it
# needs benign prompts to compete against, otherwise any photo looks a bit like a weapon.
WEAPON_PROMPTS = [
    "a photo of a gun, pistol, revolver or rifle",
    "a photo of a knife, dagger, sword or machete blade",
    "a photo of an axe or hatchet",
    "a photo of bullets, cartridges or ammunition",
    "a photo of a grenade, bomb or explosive",
    "a photo of sharp kitchen knives or chef knives",
]
_BENIGN_PROMPTS = list(CATEGORY_PROMPTS.values()) + [
    "a photo of a person or a face", "a photo of an animal", "a photo of food or drink",
    "a photo of a landscape or a building", "a photo of a vehicle",
    "a photo of a computer, phone or electronics", "a photo of furniture or a household object",
    "a photo of a tool or a toy", "a cartoon, drawing or illustration", "a screenshot or a document",
]
_WEAPON_TEXTS = WEAPON_PROMPTS + _BENIGN_PROMPTS


def weapon_score(img: Image.Image):
    """
    Probability (0-1) that the photo shows a weapon, or None if CLIP is unavailable.
    Weapons scored >= 0.94 and 74 real wardrobe items / everyday photos scored <= 0.77 in testing.
    """
    if _model is None:
        return None
    try:
        inputs = _processor(text=_WEAPON_TEXTS, images=img.convert("RGB"), return_tensors="pt", padding=True)
        inputs = {k: v.to(_device) for k, v in inputs.items()}
        with torch.no_grad():
            probs = _model(**inputs).logits_per_image.softmax(dim=1)[0].cpu()
        return float(probs[: len(WEAPON_PROMPTS)].sum())
    except Exception as e:
        print(f"CLIP weapon check error: {e}")
        return None


# "Is this a wardrobe item at all?" ImageNet reads some non-clothing objects as clothing (party
# props as "hair slide" / "sandal"), so CLIP gets a veto: clothing descriptions compete against a
# broad set of everything else (decorations, stationery, food, electronics, ...).
WARDROBE_PROMPTS = [
    "a photo of a shirt, t-shirt, hoodie, sweater or jacket",
    "a photo of trousers, jeans, pants, shorts or a skirt",
    "a photo of a dress or a gown",
    "a photo of a pair of shoes, sneakers, boots or sandals",
    "a photo of a bag, hat, belt, scarf or sunglasses",
    "a photo of a watch, jewelry, cufflinks, necklace or earrings",
    "a photo of a suit, coat or uniform",
    "a photo of a person wearing an outfit",
    "a photo of traditional clothing such as a kurta, shalwar kameez, saree, dupatta or abaya",
]
_NOT_WARDROBE_PROMPTS = [
    "a photo of party decorations, stickers, cake toppers, balloons or craft items",
    "a printed card, poster, flyer or artwork with text", "a photo of a toy, gift or stationery",
    "a photo of an animal", "a photo of food or drink", "a photo of a landscape or a building",
    "a photo of a vehicle", "a photo of a computer, phone or electronics",
    "a photo of furniture or a household object", "a photo of a person's face",
    "a screenshot or a document", "a photo of a tool, weapon or sports equipment",
]
_WARDROBE_TEXTS = WARDROBE_PROMPTS + _NOT_WARDROBE_PROMPTS


def wardrobe_score(img: Image.Image):
    """
    Probability (0-1) that the photo shows clothing, footwear, an accessory or jewelry, or None if
    CLIP is unavailable. In testing: 75 real wardrobe items scored >= 0.59, party props scored 0.00.
    """
    if _model is None:
        return None
    try:
        inputs = _processor(text=_WARDROBE_TEXTS, images=img.convert("RGB"), return_tensors="pt", padding=True)
        inputs = {k: v.to(_device) for k, v in inputs.items()}
        with torch.no_grad():
            probs = _model(**inputs).logits_per_image.softmax(dim=1)[0].cpu()
        return float(probs[: len(WARDROBE_PROMPTS)].sum())
    except Exception as e:
        print(f"CLIP wardrobe check error: {e}")
        return None


# Document check for profile pictures: screenshots, charts/diagrams and text banners are not photos.
DOCUMENT_PROMPTS = [
    "a screenshot of an app or a website",
    "a document, chart, diagram or table with text",
    "a banner, poster, flyer or advertisement with text",
]
_PHOTO_PROMPTS = [
    "a photo of a person or a face", "a selfie or portrait photo", "a photo of an animal or pet",
    "a photo of food or drink", "a photo of a landscape, nature or a building", "a photo of a vehicle",
    "a photo of an object or product", "a photo of clothing, shoes or accessories",
    "a painting, drawing or artwork", "a cartoon avatar or logo with no text",
    "a photo of flowers or plants", "a photo of a group of people",
]
_DOCUMENT_TEXTS = DOCUMENT_PROMPTS + _PHOTO_PROMPTS


def document_score(img: Image.Image):
    """
    Probability (0-1) that the image is a screenshot / document / chart / text banner rather than a
    photo, or None if CLIP is unavailable. In testing: such images scored >= 0.67, photos <= 0.53.
    """
    if _model is None:
        return None
    try:
        inputs = _processor(text=_DOCUMENT_TEXTS, images=img.convert("RGB"), return_tensors="pt", padding=True)
        inputs = {k: v.to(_device) for k, v in inputs.items()}
        with torch.no_grad():
            probs = _model(**inputs).logits_per_image.softmax(dim=1)[0].cpu()
        return float(probs[: len(DOCUMENT_PROMPTS)].sum())
    except Exception as e:
        print(f"CLIP document check error: {e}")
        return None


def analyze(img: Image.Image):
    """
    Returns {"clothing": float, "categories": {name: prob}} or None if CLIP is unavailable.
    "clothing" is the probability that the photo shows clothing / footwear / an accessory.
    "categories" is normalised over the 5 wardrobe categories only.
    """
    if _model is None:
        return None
    try:
        inputs = _processor(text=_TEXTS, images=img.convert("RGB"), return_tensors="pt", padding=True)
        inputs = {k: v.to(_device) for k, v in inputs.items()}
        with torch.no_grad():
            probs = _model(**inputs).logits_per_image.softmax(dim=1)[0].cpu()
        cat_probs = probs[: len(_CATEGORIES)]
        total = float(cat_probs.sum())
        return {
            "clothing": total,
            "face": float(probs[_FACE_INDEX]),
            "categories": {c: float(cat_probs[i]) / max(total, 1e-9) for i, c in enumerate(_CATEGORIES)},
        }
    except Exception as e:
        print(f"CLIP analysis error: {e}")
        return None


def check_category(img: Image.Image, chosen: str) -> dict:
    """
    Compares the photo with the category the user picked.
    status: "match" | "mismatch" | "unsure" ("unsure" never warns the user).
    """
    res = analyze(img)
    if res is None:
        return {"status": "unsure", "predicted": None, "confidence": 0.0, "chosen": chosen}
    cats = res["categories"]
    predicted = max(cats, key=cats.get)
    conf = cats[predicted]
    chosen_p = cats.get(chosen, 0.0)
    if predicted == chosen or chosen_p >= 0.30:
        status = "match"
    elif conf >= 0.60 and chosen_p < 0.25:
        status = "mismatch"
    else:
        status = "unsure"
    return {
        "status": status,
        "predicted": predicted,
        "confidence": round(conf, 2),
        "chosen": chosen,
        "scores": {k: round(v, 2) for k, v in cats.items()},
    }
