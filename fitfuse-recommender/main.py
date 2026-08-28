
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import BertTokenizer, BertModel
import torch
import numpy as np
from torchvision import transforms
from PIL import Image
import requests
import firebase_admin
from firebase_admin import credentials, firestore
from sklearn.metrics.pairwise import cosine_similarity
from collections import defaultdict
import io

# --- Firebase Init ---
cred = credentials.Certificate("serviceAccount.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# --- Load Models ---
print("🔄 Loading models…")
tokenizer    = BertTokenizer.from_pretrained("bert-base-uncased")
text_model   = BertModel.from_pretrained("bert-base-uncased")
vision_model = torch.hub.load('pytorch/vision', 'resnet18', pretrained=True)
vision_model.fc = torch.nn.Identity()
vision_model.eval()
print("✅ Models ready")

# --- Transforms ---
vision_transform = transforms.Compose([
    transforms.Resize((224,224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225])
])

def compute_visual_embedding(image_bytes: bytes) -> torch.Tensor:
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    t = vision_transform(img).unsqueeze(0)
    with torch.no_grad():
        v = vision_model(t)   # [1,512]
    return v.squeeze(0)      # [512]

def compute_combined_embedding(image_bytes: bytes, title: str="") -> torch.Tensor:
    vis = compute_visual_embedding(image_bytes).unsqueeze(0)  # [1,512]
    if title:
        toks = tokenizer(title, return_tensors="pt", padding=True, truncation=True)
        with torch.no_grad():
            txt = text_model(**toks).last_hidden_state.mean(dim=1)  # [1,768]
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


    dummy = torch.zeros((3,224,224))
    with torch.no_grad():
        vf = vision_model(dummy.unsqueeze(0))
        wt = tokenizer(weather, return_tensors="pt")
        wf = text_model(**wt).last_hidden_state.mean(dim=1)
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


@app.post("/recommend-outfit")
async def recommend_outfit(
    file:     UploadFile = File(...),
    userId:   str        = Query(...),
    category: str        = Query(default=None),
):
    if file.content_type not in ["image/jpeg","image/png","image/jpg"]:
        raise HTTPException(415, "Only images allowed")

    data = await file.read()
    qvec = compute_visual_embedding(data).numpy().reshape(1,-1)

   
    from collections import defaultdict
    embs = db.collection("users").document(userId).collection("embeddings").stream()
    groups = defaultdict(list)
    for e in embs:
        d = e.to_dict()
        if "visual_embedding" not in d: continue
        if category and category.lower()==d.get("category","").lower():
            continue
        groups[d["category"]].append(d)

    from sklearn.metrics.pairwise import cosine_similarity

    rec = {}
    for cat in ["Tops","Bottoms","Shoes"]:
        bucket = groups.get(cat, [])
        if not bucket:
            rec[cat] = {"title": f"No {cat.lower()} items", "imageUrl": ""}
            continue
        best = max(bucket, key=lambda it: cosine_similarity(
            qvec,
            np.array(it["visual_embedding"]).reshape(1,-1)
        )[0][0])
        rec[cat] = {"title": best["title"], "imageUrl": best["imageUrl"]}

    return {"recommended_outfit": rec}

@app.get("/")
def root():
    return {"message":"🧠 FitFuse AI online — embeddings computed on save"}
