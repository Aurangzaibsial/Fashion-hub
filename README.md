# NextGen Cloth Engine (FitFuse)

A Flutter (web + mobile) app that builds outfit recommendations from your wardrobe, the weather and an AI outfit matcher. It uses Firebase (Auth + Firestore) and a Python recommender backend.

## Ports

| Service | Port | URL |
| --- | --- | --- |
| Flutter web app | 5000 | http://localhost:5000 |
| Recommender backend (FastAPI/uvicorn) | 8000 | http://127.0.0.1:8000 |

Flutter picks a random web port unless one is given, so always pass `--web-port`.

## Run

1. Start the recommender backend:

   ```
   cd fitfuse-recommender
   python -m uvicorn main:app --host 127.0.0.1 --port 8000
   ```

2. Start the app:

   ```
   flutter pub get
   flutter run -d chrome --web-port 5000
   ```

   In VS Code you can instead pick **FitFuse (Chrome, port 5000)** from Run and Debug (see `.vscode/launch.json`).

To point the app at a different backend, build with `--dart-define`, for example:

```
flutter run -d chrome --web-port 5000 --dart-define=RECOMMENDER_URL=http://192.168.1.5:8000
```

## Design

Midnight navy `#121A33`, rose gold `#E0A58F`, porcelain `#FAF9F7`. Headings use Sora and body text uses Manrope. At widths of 900px and above the app uses a sidebar and split-screen login. Below that it uses a bottom navigation bar.

Signed-out users see the landing page first (`lib/landing.dart`), then the login page.

## Flutter resources

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Online documentation](https://docs.flutter.dev/): tutorials, samples, guidance on mobile development, and a full API reference.
