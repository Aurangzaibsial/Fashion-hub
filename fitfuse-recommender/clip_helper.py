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
