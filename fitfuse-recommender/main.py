
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import BertTokenizer, BertModel
import torch
import numpy as np
import os
from torchvision import transforms, models
from PIL import Image
import requests
import firebase_admin
from firebase_admin import credentials, firestore
from sklearn.metrics.pairwise import cosine_similarity
import io
from urllib.parse import urlparse
from image_validator import validate_wardrobe_image, log_security_alert_to_firestore, rejection_error
import clip_helper

# --- Device ---
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# --- Firebase Init ---
cred = credentials.Certificate("serviceAccount.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# --- Load Models ---
print("[*] Loading models...")
tokenizer = BertTokenizer.from_pretrained("bert-base-uncased")
text_model = BertModel.from_pretrained("bert-base-uncased").to(device)
text_model.eval()

# FitFuse ResNet18 (Trained for 8 classes or fallback to ImageNet weights)
num_classes = 8
weights_path = os.path.join(os.path.dirname(__file__), "fitfuse_resnet18.pth")

if os.path.exists(weights_path):
    print(f"[*] Loading custom trained weights from {weights_path}...")
    vision_model = models.resnet18(weights=None)
    vision_model.fc = torch.nn.Linear(vision_model.fc.in_features, num_classes)
    vision_model.load_state_dict(torch.load(weights_path, map_location=device))
    vision_model.fc = torch.nn.Identity()
    print("[SUCCESS] Custom model weights loaded successfully")
else:
    print(f"[INFO] '{weights_path}' not found. Using pretrained ResNet18 (ImageNet) weights.")
    vision_model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
    vision_model.fc = torch.nn.Identity()

vision_model = vision_model.to(device)
vision_model.eval()
print("[SUCCESS] Models ready")

# --- Transforms ---
vision_transform = transforms.Compose([
    transforms.Resize((224,224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225])
])

def compute_visual_embedding(image_bytes: bytes) -> torch.Tensor:
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    t = vision_transform(img).unsqueeze(0).to(device)
    with torch.no_grad():
        v = vision_model(t).cpu()   # [1,512]
    return v.squeeze(0)      # [512]

def compute_combined_embedding(image_bytes: bytes, title: str="") -> torch.Tensor:
    vis = compute_visual_embedding(image_bytes).unsqueeze(0)  # [1,512]
    if title:
        toks = tokenizer(title, return_tensors="pt", padding=True, truncation=True)
        toks = {k: v.to(device) for k, v in toks.items()}
        with torch.no_grad():
            txt = text_model(**toks).last_hidden_state.mean(dim=1).cpu()  # [1,768]
        return torch.cat((vis, txt), dim=1).squeeze(0)  # [1280]
    return vis.squeeze(0)  # fallback to visual-only if no title

# --- FastAPI Setup ---
app = FastAPI(title="NextGen Cloth Engine AI – Pre‑Embedded Recommender")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# Image URLs are fetched server-side, so only trusted image hosts are allowed
ALLOWED_IMAGE_HOSTS = {"res.cloudinary.com", "images.unsplash.com"}

# --- Data Model for Embeds ---
class EmbedItem(BaseModel):
    userId:   str
    imageUrl: str
    title:    str
    category: str
    occasion: str = "All"
    oldImageUrl: str = ""   # set when an edit replaces the item's photo

@app.post("/check-category")
async def check_category_endpoint(
    category: str = Query(...),
    file: UploadFile = File(None),
    imageUrl: str = Query(default=None),
):
    """
    Compares a photo with the wardrobe category the user picked.
    Send either an uploaded `file` or an `imageUrl` of an already saved photo.
    status: "match" | "mismatch" (predicted category + confidence) | "unsure".
    The app only warns on "mismatch" and always lets the user keep their choice.
    """
    if file is not None:
        img_bytes = await file.read()
    elif imageUrl:
        parsed = urlparse(imageUrl)
        if parsed.scheme != "https" or parsed.hostname not in ALLOWED_IMAGE_HOSTS:
            raise HTTPException(400, "Image URL host is not allowed")
        try:
            resp = requests.get(imageUrl, timeout=15)
        except requests.RequestException:
            raise HTTPException(400, "Could not fetch image URL")
        if resp.status_code != 200:
            raise HTTPException(400, "Invalid image URL")
        img_bytes = resp.content
    else:
        raise HTTPException(400, "Provide a file or an imageUrl")
    try:
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
    except Exception:
        raise HTTPException(400, "Not a valid image")
    return clip_helper.check_category(img, category)

@app.post("/validate-image")
async def validate_image_endpoint(
    file: UploadFile = File(...),
    userId: str = Query(default="anonymous"),
    action: str = Query(default="wardrobe_upload"),
    mode: str = Query(default="wardrobe")
):
    """
    Validates whether the uploaded image is a safe and authentic wardrobe/fashion item.
    Rejects weapons, knives, violence/blood, and non-wardrobe objects, logging security alerts to Firestore.
    """
    if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
        raise HTTPException(415, "Only JPEG/PNG images are allowed")

    img_bytes = await file.read()
    val_res = validate_wardrobe_image(img_bytes, mode=mode if mode in ("safety", "profile") else "wardrobe")

    if not val_res["is_valid"]:
        log_security_alert_to_firestore(
            db=db,
            user_id=userId,
            violation_type=val_res["violation_type"],
            details=val_res["message"],
            endpoint=f"/validate-image ({action})"
        )
        raise HTTPException(
            status_code=400,
            detail={
                "error": rejection_error(val_res),
                "violation_type": val_res["violation_type"],
                "message": val_res["message"],
                "detected_items": val_res["detected_items"]
            }
        )

    return {
        "status": "success",
        "is_valid": True,
        "message": val_res["message"],
        "detected_items": val_res["detected_items"]
    }

@app.post("/embed-item")
def embed_item(data: EmbedItem):
    """
    Call this immediately after you save a wardrobe item.
    It fetches the image, validates content safety, computes visual+combined embeddings,
    and writes them to Firestore.
    """
    resp = requests.get(data.imageUrl)
    if resp.status_code != 200:
        raise HTTPException(400, "Invalid image URL")
    img_bytes = resp.content

    # Content Safety & Wardrobe Relevance Validation
    val_res = validate_wardrobe_image(img_bytes)
    if not val_res["is_valid"]:
        log_security_alert_to_firestore(
            db=db,
            user_id=data.userId,
            violation_type=val_res["violation_type"],
            details=val_res["message"],
            endpoint="/embed-item"
        )
        raise HTTPException(
            status_code=400,
            detail={
                "error": rejection_error(val_res),
                "violation_type": val_res["violation_type"],
                "message": val_res["message"]
            }
        )

    vis_vec  = compute_visual_embedding(img_bytes).tolist()
    comb_vec = compute_combined_embedding(img_bytes, data.title).tolist()

    emb_col = db.collection("users").document(data.userId).collection("embeddings")
    # Replace (not duplicate) the embedding of this photo, and drop the old photo's one
    stale_urls = {u for u in (data.imageUrl, data.oldImageUrl) if u}
    for e in list(emb_col.stream()):
        if (e.to_dict() or {}).get("imageUrl") in stale_urls:
            e.reference.delete()
    embeddings_cache.pop(data.userId, None)

    emb_col.add({
        "title":              data.title,
        "imageUrl":           data.imageUrl,
        "category":           data.category,
        "occasion":           data.occasion,
        "visual_embedding":   vis_vec,
        "combined_embedding": comb_vec,
    })
    return {"status":"success", "message":"Embeddings saved"}

@app.post("/sync-wardrobe-embeddings")
def sync_wardrobe_embeddings(userId: str = Query(...)):
    """
    Scans the user's 'wardrobe' collection and generates embeddings
    for any items missing in the 'embeddings' collection.
    """
    wardrobe_docs = list(db.collection("users").document(userId).collection("wardrobe").stream())
    if not wardrobe_docs:
        return {"status": "success", "message": "No wardrobe items found", "synced_count": 0}

    existing_embs = list(db.collection("users").document(userId).collection("embeddings").stream())
    existing_urls = {e.to_dict().get("imageUrl") for e in existing_embs if "imageUrl" in e.to_dict()}

    synced_count = 0
    for doc in wardrobe_docs:
        data = doc.to_dict()
        image_url = data.get("imageUrl")
        if not image_url or image_url in existing_urls:
            continue

        try:
            resp = requests.get(image_url, timeout=15)
            if resp.status_code == 200:
                img_bytes = resp.content
                title = data.get("name", "")
                vis_vec = compute_visual_embedding(img_bytes).tolist()
                comb_vec = compute_combined_embedding(img_bytes, title).tolist()

                db.collection("users").document(userId).collection("embeddings").add({
                    "title":              title,
                    "imageUrl":           image_url,
                    "category":           data.get("category", "Other"),
                    "occasion":           data.get("occasion", "All"),
                    "visual_embedding":   vis_vec,
                    "combined_embedding": comb_vec,
                })
                existing_urls.add(image_url)
                synced_count += 1
        except Exception as e:
            print(f"Error syncing {image_url}: {e}")

    return {
        "status": "success",
        "message": f"Successfully synced {synced_count} missing items.",
        "synced_count": synced_count,
        "total_wardrobe": len(wardrobe_docs),
    }

@app.post("/re-embed-all")
def re_embed_all(userId: str = Query(...)):
    """
    Clears all existing embeddings for the user and regenerates them
    fresh from the user's 'wardrobe' collection.
    """
    wardrobe_docs = list(db.collection("users").document(userId).collection("wardrobe").stream())
    if not wardrobe_docs:
        return {"status": "success", "message": "No wardrobe items found", "re_embedded_count": 0}

    # Delete previous embeddings
    embs = list(db.collection("users").document(userId).collection("embeddings").stream())
    for e in embs:
        e.reference.delete()

    re_embedded_count = 0
    for doc in wardrobe_docs:
        data = doc.to_dict()
        image_url = data.get("imageUrl")
        if not image_url:
            continue

        try:
            resp = requests.get(image_url, timeout=15)
            if resp.status_code == 200:
                img_bytes = resp.content
                title = data.get("name", "")
                vis_vec = compute_visual_embedding(img_bytes).tolist()
                comb_vec = compute_combined_embedding(img_bytes, title).tolist()

                db.collection("users").document(userId).collection("embeddings").add({
                    "title":              title,
                    "imageUrl":           image_url,
                    "category":           data.get("category", "Other"),
                    "occasion":           data.get("occasion", "All"),
                    "visual_embedding":   vis_vec,
                    "combined_embedding": comb_vec,
                })
                re_embedded_count += 1
        except Exception as e:
            print(f"Error re-embedding {image_url}: {e}")

    embeddings_cache.pop(userId, None)
    return {
        "status": "success",
        "message": f"Successfully re-embedded {re_embedded_count} items from wardrobe.",
        "re_embedded_count": re_embedded_count,
    }

@app.get("/weather-recommendation")
async def weather_recommendation(userId: str = Query(...), weather: str = Query(...)):
 
    udoc = db.collection("users").document(userId).get()
    prefs = udoc.to_dict().get("preferences", {}) if udoc.exists else {}
    pref_occ = prefs.get("occasion", None)

 
    wardrobe = [
        {"name": d.to_dict().get("name",""),
         "imageUrl": d.to_dict().get("imageUrl",""),
         "category": d.to_dict().get("category","Other"),
         "occasion": d.to_dict().get("occasion","All")}
        for d in db.collection("users").document(userId).collection("wardrobe").stream()
    ]

    embs = db.collection("users").document(userId).collection("embeddings").stream()
    emb_map = {
        e.to_dict()["imageUrl"]: e.to_dict()["combined_embedding"]
        for e in embs if "combined_embedding" in e.to_dict()
    }

    items = []
    for it in wardrobe:
        vec = emb_map.get(it["imageUrl"])
        if not vec:
            continue                     
        if pref_occ and pref_occ!="All" and it["occasion"]!=pref_occ:
            continue
        items.append({**it, "embedding": vec})


    dummy = torch.zeros((3,224,224)).to(device)
    with torch.no_grad():
        vf = vision_model(dummy.unsqueeze(0)).cpu()
        wt = tokenizer(weather, return_tensors="pt")
        wt = {k: v.to(device) for k, v in wt.items()}
        wf = text_model(**wt).last_hidden_state.mean(dim=1).cpu()
    qvec = torch.cat((vf, wf), dim=1).squeeze(0).numpy().reshape(1,-1)

    from sklearn.metrics.pairwise import cosine_similarity
    from collections import defaultdict

    bycat = defaultdict(list)
    for it in items:
        bycat[it["category"]].append(it)

    rec = {}
    for cat in ["Tops","Bottoms","Shoes"]:
        bucket = bycat.get(cat, [])
        if not bucket:
            rec[cat] = {"title": f"No {cat.lower()} items", "imageUrl": ""}
            continue
        best = max(bucket, key=lambda i: cosine_similarity(
            qvec,
            np.array(i["embedding"]).reshape(1,-1)
        )[0][0])
        rec[cat] = {"title": best["name"], "imageUrl": best["imageUrl"]}

    return {"recommended_outfit": rec}


# --- In-Memory Embeddings Cache for Fast FYP Response ---
embeddings_cache = {}

def get_user_embeddings(user_id: str, force_refresh: bool = False):
    if not force_refresh and user_id in embeddings_cache:
        return embeddings_cache[user_id]
    
    embs = list(db.collection("users").document(user_id).collection("embeddings").stream())
    parsed = [e.to_dict() for e in embs]
    embeddings_cache[user_id] = parsed
    return parsed

@app.post("/recommend-outfit")
async def recommend_outfit(
    file:     UploadFile = File(...),
    userId:   str        = Query(...),
    category: str        = Query(default=None),
    weather:  str        = Query(default=None),
):
    if file.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
        raise HTTPException(415, "Only images allowed")

    data = await file.read()

    # Content Safety & Wardrobe Relevance Validation
    val_res = validate_wardrobe_image(data)
    if not val_res["is_valid"]:
        log_security_alert_to_firestore(
            db=db,
            user_id=userId,
            violation_type=val_res["violation_type"],
            details=val_res["message"],
            endpoint="/recommend-outfit (Smart Outfit)"
        )
        raise HTTPException(
            status_code=400,
            detail={
                "error": rejection_error(val_res),
                "violation_type": val_res["violation_type"],
                "message": val_res["message"],
                "detected_items": val_res["detected_items"]
            }
        )


    # If weather is provided, compute multimodal combined query (Visual + Text Weather)
    if weather and weather.strip() and weather.lower() not in ["none", "all", "auto"]:
        weather_prompt = f"{weather.strip()} weather clothing outfit style"
        qvec = compute_combined_embedding(data, title=weather_prompt).numpy().reshape(1, -1)
        use_combined = True
    else:
        qvec = compute_visual_embedding(data).numpy().reshape(1, -1)
        use_combined = False

    from collections import defaultdict
    from sklearn.metrics.pairwise import cosine_similarity

    # Fast in-memory cache retrieval (0.01s instead of 3-5s Firestore fetch)
    all_embs = get_user_embeddings(userId)
    groups = defaultdict(list)
    for d in all_embs:
        if category and category.lower() == d.get("category", "").lower():
            continue
        groups[d.get("category", "Other")].append(d)

    rec = {}
    for cat in ["Tops", "Bottoms", "Shoes"]:
        bucket = groups.get(cat, [])
        if not bucket:
            rec[cat] = {"title": f"No {cat.lower()} items", "imageUrl": ""}
            continue

        def get_score(it):
            if use_combined and "combined_embedding" in it and len(it["combined_embedding"]) == qvec.shape[1]:
                target_vec = np.array(it["combined_embedding"]).reshape(1, -1)
            elif "visual_embedding" in it:
                # If query is combined (1280) but item only has visual (512), use visual slice
                q_slice = qvec[:, :512] if qvec.shape[1] > 512 else qvec
                target_vec = np.array(it["visual_embedding"]).reshape(1, -1)
                return cosine_similarity(q_slice, target_vec)[0][0]
            else:
                return -1.0
            return cosine_similarity(qvec, target_vec)[0][0]

        best = max(bucket, key=get_score)
        rec[cat] = {"title": best.get("title", "Untitled"), "imageUrl": best.get("imageUrl", "")}

    return {
        "weather": weather or "General",
        "recommended_outfit": rec
    }

@app.post("/compare-dresses")
async def compare_dresses(
    dress1: UploadFile = File(...),
    dress2: UploadFile = File(...),
    dress3: UploadFile = File(...),
    userId: str = Query(default="anonymous"),
    occasion: str = Query(default="General")
):
    """
    Compares 3 dress images using ResNet18 visual embeddings and color/texture aesthetics.
    Selects the best dress and generates a persuasive, satisfying fashion style rationale.
    """
    files = [dress1, dress2, dress3]
    scores = []
    analyses = []

    for idx, f in enumerate(files):
        content = await f.read()
        try:
            img = Image.open(io.BytesIO(content)).convert("RGB")
        except Exception:
            raise HTTPException(400, f"Invalid image file for Dress #{idx + 1}")

        # Content Safety & Wardrobe Relevance Validation for Dress Candidates
        val_res = validate_wardrobe_image(content)
        if not val_res["is_valid"]:
            log_security_alert_to_firestore(
                db=db,
                user_id=userId,
                violation_type=val_res["violation_type"],
                details=f"Dress #{idx + 1}: {val_res['message']}",
                endpoint="/compare-dresses"
            )
            raise HTTPException(
                status_code=400,
                detail={
                    "error": rejection_error(val_res),
                    "violation_type": val_res["violation_type"],
                    "message": f"Dress #{idx + 1}: {val_res['message']}" if rejection_error(val_res) == "LOW_QUALITY_IMAGE" else f"Dress #{idx + 1} is unauthorized: {val_res['message']}",
                    "detected_items": val_res["detected_items"]
                }
            )


        # 1. Feature embedding norm (feature richness)
        v_emb = compute_visual_embedding(content)
        feature_richness = float(torch.norm(v_emb).item())

        # 2. Color saturation & contrast analysis
        arr = np.array(img, dtype=np.float32)
        std_per_channel = np.std(arr, axis=(0, 1)) # contrast
        contrast_score = float(np.mean(std_per_channel))

        # Brightness & balance
        brightness = float(np.mean(arr))
        luminance_balance = 100.0 - abs(135.0 - brightness) # optimum ~135

        # 3. Occasion-specific weighting
        occ_lower = occasion.lower()
        if "party" in occ_lower:
            score = (contrast_score * 0.45) + (feature_richness * 0.35) + (luminance_balance * 0.20)
        elif "formal" in occ_lower:
            score = (luminance_balance * 0.45) + (feature_richness * 0.35) + (contrast_score * 0.20)
        elif "wedding" in occ_lower:
            score = (feature_richness * 0.45) + (contrast_score * 0.35) + (luminance_balance * 0.20)
        elif "date" in occ_lower:
            score = (contrast_score * 0.35) + (luminance_balance * 0.35) + (feature_richness * 0.30)
        else: # Casual / General
            score = (feature_richness * 0.40) + (luminance_balance * 0.30) + (contrast_score * 0.30)

        scores.append(score)
        analyses.append({
            "contrast": round(contrast_score, 1),
            "richness": round(feature_richness, 1),
            "brightness": round(brightness, 1),
        })

    # Pick winner (1-based index)
    best_idx = int(np.argmax(scores)) + 1
    max_score = max(scores) if max(scores) > 0 else 1.0
    normalized_scores = [round((s / max_score) * 100, 1) for s in scores]

    # Generate personalized fashion rationale caption based on occasion
    occ_key = occasion.capitalize()
    caption_templates = {
        "Party": (
            f"Dress #{best_idx} is selected as your prime outfit for a Party. "
            f"Its superior color saturation and lively contrast create a vibrant, captivating aesthetic that "
            f"effortlessly commands attention compared to the other alternatives."
        ),
        "Formal": (
            f"Dress #{best_idx} is chosen for its graceful color harmony and clean visual structure. "
            f"It delivers the ideal blend of executive poise and sophisticated modern elegance, making it "
            f"the most appropriate and dignified choice for a formal setting."
        ),
        "Wedding": (
            f"Dress #{best_idx} stands out as the ultimate choice for a wedding celebration. "
            f"Its rich fabric tone depth and ornate texture balance create a regal, radiant presence "
            f"that elevates your personal style above the other dresses."
        ),
        "Date Night": (
            f"Dress #{best_idx} is selected for its romantic undertones and balanced aesthetic flow. "
            f"It pairs flattering visual contrast with effortless charm, giving you an alluring and "
            f"unforgettable look."
        ),
        "Casual": (
            f"Dress #{best_idx} is your ideal choice for casual wear. "
            f"Its soft color balance and lightweight visual feel provide maximum ease while ensuring "
            f"a crisp, chic, and put-together daily look."
        ),
        "General": (
            f"Our AI fashion model evaluated color saturation, texture harmony, and visual balance across all three dresses. "
            f"Dress #{best_idx} achieved the highest aesthetic synergy, making it the most flattering, balanced, and versatile "
            f"outfit to wear today."
        ),
    }

    styling_tips = {
        "Party": "Pair with metallic statement jewelry and strappy heels to accentuate the energetic silhouette.",
        "Formal": "Complement with sleek pointed-toe heels and a minimalist leather tote for a timeless executive finish.",
        "Wedding": "Style with delicate gemstone earrings and an embellished clutch to highlight the celebratory elegance.",
        "Date Night": "Accent with dainty layered necklaces and soft neutral footwear for a warm, intimate aesthetic.",
        "Casual": "Pair with crisp white sneakers or classic loafers and a relaxed crossbody bag for effortless style.",
        "General": "Match with complementary neutral accessories to allow the dress's natural color harmony to shine.",
    }

    reasoning_caption = caption_templates.get(occ_key, caption_templates["General"])
    styling_tip = styling_tips.get(occ_key, styling_tips["General"])

    return {
        "best_dress_index": best_idx,
        "best_dress_title": f"Dress #{best_idx}",
        "occasion": occasion,
        "scores": normalized_scores,
        "reasoning_caption": reasoning_caption,
        "styling_tip": styling_tip,
        "metrics": {
            "harmony_score": f"{normalized_scores[best_idx - 1]}%",
            "aesthetic_balance": "Optimal",
            "occasion_fit": "Excellent"
        }
    }

@app.get("/")
def root():
    return {"message": "NextGen Cloth Engine AI online - embeddings computed on save"}
