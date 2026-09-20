
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
from collections import defaultdict
import io

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
app = FastAPI(title="FitFuse AI – Pre‑Embedded Recommender")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# --- Data Model for Embeds ---
class EmbedItem(BaseModel):
    userId:   str
    imageUrl: str
    title:    str
    category: str
    occasion: str = "All"

@app.post("/embed-item")
def embed_item(data: EmbedItem):
    """
    Call this immediately after you save a wardrobe item.
    It fetches the image, computes visual+combined embeddings,
    and writes them to Firestore in one go.
    """
    resp = requests.get(data.imageUrl)
    if resp.status_code != 200:
        raise HTTPException(400, "Invalid image URL")
    img_bytes = resp.content

    vis_vec  = compute_visual_embedding(img_bytes).tolist()
    comb_vec = compute_combined_embedding(img_bytes, data.title).tolist()

    db.collection("users").document(data.userId)\
      .collection("embeddings").add({
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

@app.get("/")
def root():
    return {"message": "FitFuse AI online - embeddings computed on save"}
