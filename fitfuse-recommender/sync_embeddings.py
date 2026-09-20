"""
FitFuse Wardrobe Embeddings Synchronization Script
Run this script to generate visual and combined embeddings for all wardrobe items
across all users (or a specific user).
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import torch
from torchvision import transforms, models
from transformers import BertTokenizer, BertModel
from PIL import Image
import io
import os

# --- Device ---
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# --- Firebase Init ---
script_dir = os.path.dirname(os.path.abspath(__file__))
cred_path = os.path.join(script_dir, "serviceAccount.json")
cred = credentials.Certificate(cred_path)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

# --- Model Loading ---
print("[*] Loading models for embedding sync...")
tokenizer = BertTokenizer.from_pretrained("bert-base-uncased")
text_model = BertModel.from_pretrained("bert-base-uncased").to(device)
text_model.eval()

num_classes = 8
weights_path = os.path.join(script_dir, "fitfuse_resnet18.pth")

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
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

def compute_visual_embedding(image_bytes: bytes) -> torch.Tensor:
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    t = vision_transform(img).unsqueeze(0).to(device)
    with torch.no_grad():
        v = vision_model(t).cpu()
    return v.squeeze(0)

def compute_combined_embedding(image_bytes: bytes, title: str = "") -> torch.Tensor:
    vis = compute_visual_embedding(image_bytes).unsqueeze(0)
    if title:
        toks = tokenizer(title, return_tensors="pt", padding=True, truncation=True)
        toks = {k: v.to(device) for k, v in toks.items()}
        with torch.no_grad():
            txt = text_model(**toks).last_hidden_state.mean(dim=1).cpu()
        return torch.cat((vis, txt), dim=1).squeeze(0)
    return vis.squeeze(0)

def sync_all_users(re_embed_all=False):
    users = db.collection("users").stream()
    total_synced = 0

    for user in users:
        user_id = user.id
        print(f"\n[USER] Processing user: {user_id}")
        wardrobe_ref = db.collection("users").document(user_id).collection("wardrobe")
        embeddings_ref = db.collection("users").document(user_id).collection("embeddings")

        wardrobe_items = list(wardrobe_ref.stream())
        if not wardrobe_items:
            print(f"  [INFO] No wardrobe items found for user {user_id}")
            continue

        if re_embed_all:
            print("  [CLEAR] Clearing existing embeddings for fresh regeneration...")
            for e in embeddings_ref.stream():
                e.reference.delete()
            existing_urls = set()
        else:
            existing_urls = {
                e.to_dict().get("imageUrl")
                for e in embeddings_ref.stream()
                if "imageUrl" in e.to_dict()
            }

        synced_user_count = 0
        for doc in wardrobe_items:
            data = doc.to_dict()
            image_url = data.get("imageUrl")
            title = data.get("name", "Item")
            category = data.get("category", "Other")
            occasion = data.get("occasion", "All")

            if not image_url:
                continue

            if not re_embed_all and image_url in existing_urls:
                print(f"  [SKIP] Already embedded: {title} ({category})")
                continue

            try:
                print(f"  [EMBEDDING] {title} ({category})...")
                resp = requests.get(image_url, timeout=15)
                if resp.status_code == 200:
                    img_bytes = resp.content
                    vis_vec = compute_visual_embedding(img_bytes).tolist()
                    comb_vec = compute_combined_embedding(img_bytes, title).tolist()

                    embeddings_ref.add({
                        "title": title,
                        "imageUrl": image_url,
                        "category": category,
                        "occasion": occasion,
                        "visual_embedding": vis_vec,
                        "combined_embedding": comb_vec,
                    })
                    synced_user_count += 1
                    total_synced += 1
                    print(f"  [SUCCESS] Saved embedding for: {title}")
                else:
                    print(f"  [FAILED] Failed to download image ({resp.status_code}): {image_url}")
            except Exception as ex:
                print(f"  [ERROR] Error processing {title}: {ex}")

        print(f"[DONE] Synced {synced_user_count} items for user {user_id}")

    print(f"\n[FINISH] Total items embedded across all users: {total_synced}")

if __name__ == "__main__":
    import sys
    re_embed = "--re-embed" in sys.argv
    if re_embed:
        print("[MODE] Full Re-Embedding (clearing and rebuilding all embeddings)")
    else:
        print("[MODE] Missing Items Sync (only embedding items not yet in database)")
        print("       (To rebuild everything from scratch, run: python sync_embeddings.py --re-embed)")
    sync_all_users(re_embed_all=re_embed)
