# NextGen Cloth Engine (FitFuse)

A Flutter (web + mobile) app that builds outfit recommendations from your wardrobe, the weather and an AI outfit matcher. It uses Firebase (Auth + Firestore) and a Python recommender backend.

## Ports

| Service | Port | URL |
| --- | --- | --- |
| Flutter web app | 5000 | http://localhost:5000 |
| Recommender backend (FastAPI/uvicorn) | 8000 | http://127.0.0.1:8000 |

Flutter picks a random web port unless one is given, so always pass `--web-port`.

## Getting started (step by step)

Short version with just the commands: [START_GUIDE.md](START_GUIDE.md).

### 1. Install the prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.5 or newer) and Google Chrome
- [Python 3.10+](https://www.python.org/downloads/) with `pip`
- Git

Check your setup with `flutter doctor`.

### 2. Get the code

```
git clone https://github.com/Aurangzaibsial/Fashion-hub.git
cd Fashion-hub
```

### 3. Install the Flutter packages

```
flutter pub get
```

### 4. Set up the backend (first time only)

```
cd fitfuse-recommender
pip install -r requirements.txt
```

The backend needs a Firebase service account key saved as `fitfuse-recommender/serviceAccount.json`. Download it from Firebase Console > Project settings > Service accounts. Do not share this file or commit it to a public repo.

The first start can be slow because the image-safety models (torch, CLIP) load.

### 5. Start the backend (terminal 1)

```
cd fitfuse-recommender
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

Leave it running. Open http://127.0.0.1:8000/docs to confirm it is up.

### 6. Start the app (terminal 2)

From the project root:

```
flutter run -d chrome --web-port 5000
```

Then open http://localhost:5000. In VS Code you can instead pick **FitFuse (Chrome, port 5000)** in Run and Debug.

### 7. Use the app

1. The landing page opens first. Use its buttons to go to the login page.
2. Sign up for a new account, or log in with an existing one (email and password, or Google).
3. Add clothes in **Wardrobe**, then get outfits on **Home**.

### Restarting after code changes

Hot reload does not always pick up colour or new-class changes on web. Press `R` in the `flutter run` terminal for a hot restart, or stop and run it again, then hard-refresh Chrome with Ctrl+Shift+R.

### Run on a phone or emulator

The backend address defaults to `127.0.0.1`, which a phone cannot reach. Use your computer's LAN IP:

```
flutter run --dart-define=RECOMMENDER_URL=http://192.168.1.5:8000
```

and start uvicorn with `--host 0.0.0.0`.

Note: the weather recommendation call in `lib/homepage.dart` still uses a hardcoded `127.0.0.1:8000`, so on a phone the Home recommendations need that changed to use `kRecommenderUrl` too.

## Design

Midnight navy `#121A33`, rose gold `#E0A58F`, porcelain `#FAF9F7`. Headings use Sora and body text uses Manrope. At widths of 900px and above the app uses a sidebar and split-screen login. Below that it uses a bottom navigation bar.

Signed-out users see the landing page first (`lib/landing.dart`), then the login page.

## Flutter resources

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Online documentation](https://docs.flutter.dev/): tutorials, samples, guidance on mobile development, and a full API reference.
