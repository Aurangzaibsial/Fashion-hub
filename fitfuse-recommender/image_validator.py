"""
NextGen Cloth Engine AI - Image Safety & Wardrobe Relevance Validator
Filters out:
- Weapons, knives, blades, guns, military armaments
- Blood, gore, and violent imagery
- Documents, PDFs, screenshots, and non-photo images
Logs violations to Firestore 'security_alerts' collection for Admin review.
"""

import io
import torch
import numpy as np
from PIL import Image
from torchvision import models, transforms
import clip_helper

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# --- 1. Load Pretrained Classifier for Safety & Domain Filtering ---
print("[*] Loading ImageNet Safety & Domain Classifier (ResNet-18)...")
_weights = models.ResNet18_Weights.DEFAULT
_classifier_model = models.resnet18(weights=_weights).to(device)
_classifier_model.eval()
_categories = _weights.meta["categories"]
print("[SUCCESS] ImageNet Safety Classifier initialized.")

# Standard ImageNet transform (224x224, Normalized)
_val_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

# --- 2. Category Definitions ---

# Weapons, blades, firearms, dangerous objects in ImageNet
WEAPON_CLASSES = {
    "cleaver", "pocketknife", "revolver", "rifle",
    "assault rifle", "projectile", "missile", "holster",
    "hatchet", "scabbard", "cannon"
}

# Explicit keywords for weapon detection (strict — common clothing words excluded)
WEAPON_KEYWORDS = [
    "knife", "blade", "sword", "dagger", "cleaver", "revolver", "pistol",
    "rifle", "gun", "firearm", "weapon", "bullet", "ammunition", "hatchet",
    "axe", "missile", "cannon", "scabbard", "harpoon", "bayonet"
]

# Wardrobe, clothing, footwear, and wearable fashion accessories
WARDROBE_KEYWORDS = [
    "shirt", "jersey", "jean", "jeans", "denim", "suit", "coat", "jacket",
    "dress", "vest", "shoe", "boot", "sandal", "sock", "hat", "cap", "bonnet",
    "glove", "mitten", "tie", "scarf", "apron", "bikini", "brassiere", "bra",
    "cardigan", "cloak", "gown", "kimono", "pajama", "poncho", "robe", "sarong",
    "trench", "uniform", "wool", "sunglass", "backpack", "purse", "wallet",
    "clog", "loafer", "stole", "skirt", "sweatshirt", "hoodie", "trunks",
    "wardrobe", "spectacles", "pant", "trousers", "blazer", "necklace",
    "bracelet", "earring", "headband", "shawl", "turban", "beret", "sombrero",
    "cowboy hat", "cowboy boot", "running shoe", "academic gown", "lab coat",
    "swimming trunks", "maillot tank suit", "bulletproof vest"
]

# Exact ImageNet class names (case-sensitive: "Cardigan" is a dog, "cardigan" is a sweater)
WARDROBE_CLASSES = {
    "abaya", "academic gown", "apron", "backpack", "bathing cap", "bearskin",
    "bikini", "bolo tie", "bonnet", "bow tie", "brassiere", "bulletproof vest",
    "cardigan", "cloak", "clog", "cowboy boot", "cowboy hat", "diaper",
    "feather boa", "fur coat", "gown", "hoopskirt", "jean", "jersey", "kimono",
    "lab coat", "Loafer", "maillot", "maillot tank suit", "military uniform",
    "miniskirt", "mitten", "necklace", "overskirt", "pajama", "poncho", "purse",
    "running shoe", "sandal", "sarong", "shower cap", "sock", "sombrero",
    "stole", "suit", "sunglass", "sunglasses", "sweatshirt", "swimming trunks",
    "trench coat", "vestment", "wallet", "Windsor tie", "wool", "mortarboard",
    "pickelhaube", "Christmas stocking", "handkerchief", "hair slide",
}

def is_wardrobe_category(cls_name: str) -> bool:
    return cls_name in WARDROBE_CLASSES

# Clearly non-wardrobe objects — block these when detected with high confidence
BLOCKED_OBJECTS = {
    # Documents / Paper / Screens
    "book", "comic book", "notebook", "crossword puzzle", "menu", "envelope",
    "paper towel", "tissue paper", "toilet paper", "newspaper", "magazine",
    "desktop computer", "laptop", "notebook computer", "laptop computer",
    "monitor", "screen", "television", "remote control", "keyboard", "mouse",
    "cell phone", "mobile phone", "smartphone", "ipod",
    "digital clock", "wall clock", "analog clock", "stopwatch", "hourglass",
    # Food & Kitchen
    "pizza", "hamburger", "hot dog", "banana", "apple", "orange", "broccoli",
    "carrot", "corn", "sandwich", "taco", "burrito", "ice cream", "cake",
    "cup", "wine glass", "beer glass", "coffee mug", "plate", "bowl", "pot",
    "frying pan", "spatula", "ladle", "fork", "spoon",
    "refrigerator", "oven", "microwave", "toaster", "blender",
    # Animals
    "dog", "cat", "bird", "fish", "horse", "cow", "sheep", "pig", "chicken",
    "snake", "lion", "tiger", "elephant", "bear", "rabbit", "hamster",
    # Vehicles
    "car", "truck", "bus", "motorcycle", "bicycle", "airplane", "boat", "train",
    "ambulance", "fire engine", "taxi",
    # Nature / Landscape
    "mountain", "beach", "forest", "river", "lake",
    "flower", "tree", "grass", "rock",
    # Buildings / Furniture
    "house", "building", "skyscraper", "bridge",
    "chair", "table", "desk", "sofa", "couch", "bed", "bathtub", "toilet",
    # Sports equipment (non-wearable)
    "basketball", "football", "soccer ball", "tennis racket", "baseball bat",
    "golf club", "skateboard", "surfboard",
    # Other obvious non-clothing
    "cash machine", "vending machine", "traffic light", "fire hydrant",
    "stop sign", "bench", "lamp", "flashlight",
    "guitar", "piano", "drum", "microphone", "camera", "binoculars",
}

BLOCKED_KEYWORDS = [
    "book", "document", "newspaper", "screen", "monitor", "laptop", "phone",
    "animal", "plant", "flower", "vehicle", "furniture",
    "computer", "television", "dog", "cat", "car", "bird", "fish", "food",
]


def check_blood_or_gore(img: Image.Image, threshold: float = 0.04) -> tuple[bool, str]:
    """
    Analyzes color saturation to detect high-concentration blood/gore patterns.
    """
    try:
        arr = np.array(img.convert("RGB"), dtype=np.float32)
        r = arr[:, :, 0]
        g = arr[:, :, 1]
        b = arr[:, :, 2]

        # Crimson / Deep Blood Red mask: strong R, significantly low G and low B
        blood_mask = (r > 130) & (g < 60) & (b < 60) & ((r - np.maximum(g, b)) > 60)
        blood_ratio = float(np.mean(blood_mask))

        # If more than `threshold` of the image is deep blood crimson red with high saturation
        if blood_ratio > threshold:
            return True, f"Blood/violence crimson tone detected ({round(blood_ratio * 100, 1)}% of frame)"
    except Exception as e:
        print(f"Blood heuristic check error: {e}")
    return False, ""


def check_document_or_screenshot(img: Image.Image) -> tuple[bool, str]:
    """
    Detects PDF pages, screenshots, and document images.
    These have very high brightness, low color variance, and high white pixel ratio.
    Real clothing photos always have natural lighting variation and color complexity.
    """
    try:
        arr = np.array(img.convert("RGB"), dtype=np.float32)

        avg_brightness = float(np.mean(arr))
        color_std = float(np.std(arr))

        # Fraction of pixels that are near-white (>230 in all 3 channels)
        near_white_mask = np.all(arr > 230, axis=2)
        white_ratio = float(np.mean(near_white_mask))

        # Document/PDF/Screenshot: very bright, low variance, >55% white area
        if avg_brightness > 215 and color_std < 60 and white_ratio > 0.55:
            return True, (
                f"Document/PDF/screenshot detected — image appears to be a flat "
                f"document (brightness={round(avg_brightness,0)}, "
                f"white_area={round(white_ratio * 100, 1)}%). "
                f"Please upload a real photo of a clothing item."
            )

        # Dark mode screenshots / dark uniform backgrounds
        near_black_mask = np.all(arr < 30, axis=2)
        black_ratio = float(np.mean(near_black_mask))
        if avg_brightness < 25 and color_std < 20 and black_ratio > 0.65:
            return True, "Dark uniform screenshot/document detected. Please upload a real clothing photo."

    except Exception as e:
        print(f"Document check error: {e}")
    return False, ""


def validate_wardrobe_image(image_bytes: bytes, mode: str = "wardrobe") -> dict:
    """
    Validates whether the uploaded image is safe and wardrobe-related.
    mode="wardrobe": must be a clothing/footwear/accessory photo (strict).
    mode="safety":   only rejects documents, weapons and gore (profile/community photos).
    Returns:
        {
            "is_valid": bool,
            "violation_type": str | None,
            "message": str,
            "detected_items": list[str],
            "confidence": float
        }
    """
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except Exception:
        return {
            "is_valid": False,
            "violation_type": "INVALID_IMAGE_FILE",
            "message": "Uploaded file is corrupted or not a valid image.",
            "detected_items": [],
            "confidence": 0.0
        }

    # 1. ImageNet classification (done first: clothing evidence overrides the pixel heuristics)
    tensor = _val_transform(img).unsqueeze(0).to(device)
    with torch.no_grad():
        logits = _classifier_model(tensor)
        probs = torch.softmax(logits, dim=1).squeeze(0).cpu().numpy()

    top5_indices = np.argsort(probs)[-5:][::-1]
    top5_classes = [(_categories[idx], float(probs[idx])) for idx in top5_indices]
    top_class_name, top_class_prob = top5_classes[0]

    wardrobe_matches = [(cls, prob) for cls, prob in top5_classes if is_wardrobe_category(cls)]
    wardrobe_prob_sum = sum(prob for _, prob in wardrobe_matches)
    top_is_wardrobe = is_wardrobe_category(top_class_name)
    looks_like_clothing = top_is_wardrobe or wardrobe_prob_sum >= 0.15

    # ImageNet has no class for many garments (dress shoes, hoodies...). When it sees no
    # clothing, ask CLIP: a high "clothing / footwear / accessory" score also counts.
    if not looks_like_clothing:
        clip_res = clip_helper.analyze(img)
        if clip_res is not None and clip_res["clothing"] >= 0.6:
            looks_like_clothing = True

    # 2. Weapons / blades / dangerous objects (always enforced)
    detected_weapons = []
    for cls_name, prob in top5_classes:
        lower_name = cls_name.lower()
        is_weapon = (
            lower_name in WEAPON_CLASSES or
            any(k in lower_name for k in WEAPON_KEYWORDS)
        )
        if is_weapon and prob >= 0.05:
            detected_weapons.append(f"{cls_name} ({round(prob * 100, 1)}%)")

    for w_cls in WEAPON_CLASSES:
        if w_cls in _categories:
            idx = _categories.index(w_cls)
            if probs[idx] >= 0.06:
                detected_weapons.append(f"{w_cls} ({round(float(probs[idx]) * 100, 1)}%)")

    if detected_weapons:
        detected_weapons = list(dict.fromkeys(detected_weapons))
        return {
            "is_valid": False,
            "violation_type": "WEAPON_DETECTED",
            "message": f"Unauthorized image: Prohibited weapon/blade detected [{', '.join(detected_weapons[:2])}]. Weapons, knives, and dangerous items are strictly forbidden.",
            "detected_items": detected_weapons,
            "confidence": round(float(top_class_prob), 2)
        }

    # 3. Document / Screenshot / PDF check (skipped when the classifier sees clothing,
    #    e.g. a shoe on a white studio background, and in safety mode where plain
    #    backgrounds are normal)
    if mode != "safety" and not looks_like_clothing:
        is_doc, doc_msg = check_document_or_screenshot(img)
        if is_doc:
            return {
                "is_valid": False,
                "violation_type": "NON_WARDROBE_ITEM",
                "message": f"Unauthorized image: {doc_msg}",
                "detected_items": ["document / screenshot / pdf"],
                "confidence": 0.95
            }

    # 4. Blood / Violence heuristic (skipped for red clothing, which has the same colours)
    if not looks_like_clothing:
        is_blood, blood_msg = check_blood_or_gore(img, 0.20 if mode == "safety" else 0.04)
        if is_blood:
            return {
                "is_valid": False,
                "violation_type": "BLOOD_VIOLENCE_DETECTED",
                "message": "Unauthorized image: Blood, violence, or gore detected. Only valid wardrobe items are allowed.",
                "detected_items": ["blood / violent imagery"],
                "confidence": 0.95
            }

    # Safety mode (profile / community photos) stops here
    if mode == "safety":
        return {
            "is_valid": True,
            "violation_type": None,
            "message": "Image passed safety checks.",
            "detected_items": [top_class_name],
            "confidence": round(top_class_prob, 2)
        }

    # 5. Wardrobe mode: the image must look like clothing, footwear or an accessory.
    #    Anything else (animals, food, vehicles, screens, scenery...) is rejected.
    if not looks_like_clothing:
        return {
            "is_valid": False,
            "violation_type": "NON_WARDROBE_ITEM",
            "message": (
                f"Unauthorized image: Detected '{top_class_name}' "
                f"({round(top_class_prob * 100, 1)}%), which is not related to clothing or fashion. "
                f"Only authentic clothing, footwear, and fashion accessories are accepted."
            ),
            "detected_items": [top_class_name],
            "confidence": round(top_class_prob, 2)
        }

    matched_label = wardrobe_matches[0][0] if wardrobe_matches else top_class_name
    return {
        "is_valid": True,
        "violation_type": None,
        "message": "Wardrobe item validated successfully.",
        "detected_items": [matched_label],
        "confidence": round(top_class_prob, 2)
    }


def log_security_alert_to_firestore(db, user_id: str, violation_type: str, details: str, endpoint: str):
    """
    Logs an unauthorized upload attempt into Firestore 'security_alerts' collection.
    Also looks up the user's name/email to make it easily identifiable by the Admin.
    """
    if db is None:
        print("[WARN] Firestore client is None, cannot log security alert.")
        return

    try:
        user_name = "Unknown User"
        user_email = "Not Available"

        if user_id:
            try:
                user_doc = db.collection("users").document(user_id).get()
                if user_doc.exists:
                    udata = user_doc.to_dict() or {}
                    first = udata.get("firstName", "")
                    last = udata.get("lastName", "")
                    full = f"{first} {last}".strip()
                    if full:
                        user_name = full
                    user_email = udata.get("email", user_email)
            except Exception as e:
                print(f"Error fetching user metadata: {e}")

        from google.cloud import firestore as gc_firestore

        db.collection("security_alerts").add({
            "userId": user_id or "anonymous",
            "userName": user_name,
            "userEmail": user_email,
            "violationType": violation_type,
            "details": details,
            "endpoint": endpoint,
            "status": "BLOCKED",
            "timestamp": gc_firestore.SERVER_TIMESTAMP,
            "actionTaken": "Upload rejected & alert generated for admin"
        })
        print(f"[SECURITY ALERT LOGGED] User '{user_name}' ({user_id}) triggered '{violation_type}' on '{endpoint}'")
    except Exception as e:
        print(f"[ERROR] Failed to write security alert to Firestore: {e}")
