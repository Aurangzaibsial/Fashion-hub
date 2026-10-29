# How to start the servers

You need two terminals open at the same time. Start the backend first, then the app.

Project folder: `D:\Fabric fusion`

## Terminal 1: backend (port 8000)

```
cd "D:\Fabric fusion\fitfuse-recommender"
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

Ready when you see `Uvicorn running on http://127.0.0.1:8000`. The first start can take a while because the AI models load.

Check it: open http://127.0.0.1:8000/docs

## Terminal 2: app (port 5000)

```
cd "D:\Fabric fusion"
flutter run -d chrome --web-port 5000
```

Chrome opens by itself. If it does not, open http://localhost:5000

## While the app is running

In the `flutter run` terminal:

| Key | What it does |
| --- | --- |
| `r` | Hot reload (small code changes) |
| `R` | Hot restart (colour, theme or new-class changes) |
| `q` | Quit the app |

If the screen still looks old, press Ctrl+Shift+R in Chrome.

## Stop the servers

Press `Ctrl+C` in each terminal (or `q` in the app terminal).

## First time only

```
cd "D:\Fabric fusion"
flutter pub get

cd fitfuse-recommender
pip install -r requirements.txt
```

`fitfuse-recommender\serviceAccount.json` must exist (Firebase service account key).

## If something fails

| Problem | Fix |
| --- | --- |
| `Address already in use` on 8000 | Backend already running. Close the old terminal, or run `netstat -ano \| findstr :8000` and `taskkill /PID <pid> /F` |
| `Address already in use` on 5000 | Same, for port 5000 |
| `No module named uvicorn` | `pip install -r requirements.txt` in `fitfuse-recommender` |
| `flutter` is not recognized | Add `C:\flutter\bin` to PATH, then reopen the terminal |
| Home shows no recommendations or images are not checked | Backend (terminal 1) is not running |
| Old colours or layout | Press `R`, then Ctrl+Shift+R in Chrome |
