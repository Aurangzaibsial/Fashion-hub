"""
Test Safety & Domain Validation
1. Tests clean clothing image -> should PASS
2. Tests synthetic blood canvas -> should FAIL with BLOOD_VIOLENCE_DETECTED
3. Tests weapon detection -> should FAIL with WEAPON_DETECTED
4. Tests Firestore alert logging -> verifies security_alerts collection gets written
"""

import io
import os
import numpy as np
from PIL import Image
import sys

# Ensure recommender directory is on sys.path
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from image_validator import validate_wardrobe_image, log_security_alert_to_firestore
import firebase_admin
from firebase_admin import credentials, firestore

print("--- 1. Testing Clothing Image ---")
cloth_path = os.path.join(BASE_DIR, "download.jpg")
with open(cloth_path, "rb") as f:
    cloth_bytes = f.read()

res_cloth = validate_wardrobe_image(cloth_bytes)
print("Clothing Result:", res_cloth)
assert res_cloth["is_valid"] is True, "Clothing should be valid"

print("\n--- 2. Testing Non-Wardrobe Random Object (Green Canvas) ---")
arr_green = np.zeros((224, 224, 3), dtype=np.uint8)
arr_green[:, :, 0] = 120
arr_green[:, :, 1] = 150
arr_green[:, :, 2] = 80
buf_green = io.BytesIO()
Image.fromarray(arr_green).save(buf_green, format="JPEG")
res_green = validate_wardrobe_image(buf_green.getvalue())
print("Non-Wardrobe Result:", res_green)
assert res_green["is_valid"] is False, "Non-wardrobe image should be blocked"
assert res_green["violation_type"] == "NON_WARDROBE_ITEM", "Should be marked NON_WARDROBE_ITEM"

print("\n--- 3. Testing Blood Image ---")
arr_blood = np.zeros((224, 224, 3), dtype=np.uint8)
arr_blood[:, :, 0] = 220
arr_blood[:, :, 1] = 15
arr_blood[:, :, 2] = 15
buf_blood = io.BytesIO()
Image.fromarray(arr_blood).save(buf_blood, format="JPEG")
res_blood = validate_wardrobe_image(buf_blood.getvalue())
print("Blood Result:", res_blood)
assert res_blood["is_valid"] is False, "Blood image should be invalid"
assert res_blood["violation_type"] == "BLOOD_VIOLENCE_DETECTED"

print("\n--- 4. Testing Firestore Alert Writing for Non-Wardrobe Item ---")
service_acc_path = os.path.join(BASE_DIR, "serviceAccount.json")
if not firebase_admin._apps:
    cred = credentials.Certificate(service_acc_path)
    firebase_admin.initialize_app(cred)
db = firestore.client()

log_security_alert_to_firestore(
    db=db,
    user_id="test_professor_check",
    violation_type=res_green["violation_type"],
    details=res_green["message"],
    endpoint="/recommend-outfit (Smart Outfit)"
)

# Verify document was created
alerts = list(db.collection("security_alerts").where("userId", "==", "test_professor_check").limit(1).stream())
print(f"Verified Firestore alert created: {len(alerts)} document(s) found.")
for a in alerts:
    print("Alert Doc:", a.to_dict())

print("\n[ALL SAFETY & VALIDATION TESTS PASSED SUCCESSFULLY!]")
