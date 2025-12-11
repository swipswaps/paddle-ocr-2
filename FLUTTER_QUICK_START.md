# Flutter Desktop App - Quick Start

## TL;DR - One Command

```bash
./run_flutter.sh
```

That's it! The script will:
1. ✅ Check if backend is running (starts it if needed)
2. ✅ Launch the Flutter app
3. ✅ Show you what to do next

---

## What You'll See

### 1. Home Screen
- **"Choose from Gallery"** button - Click to select an image
- **"Live Text"** button - Camera-based OCR (mobile only)
- **"History"** button - View past OCR results

### 2. Processing Screen (NEW!)
- **Real-time logs** streaming from backend
- **Color-coded** log types:
  - 🔵 Blue = System logs
  - 🟢 Green = OCR processing logs
  - 🔴 Red = Errors
- **Progress bar** at top
- **Auto-scrolling** logs (like React frontend)

### 3. Result Screen
- **4 tabs**: Text / CSV / JSON / SQL
- **Export buttons** for each format
- **Confidence score** and processing time
- **Engine used** (Tesseract or PaddleOCR)

### 4. History Screen
- **Search** past results
- **Delete** old results
- **Preview** and re-open results

---

## Alternative Ways to Run

### Option 1: Simple Run (Recommended)
```bash
./run_flutter.sh
```

### Option 2: Full Clean Build
```bash
./test_flutter_desktop.sh
```
This does:
- `flutter pub add` dependencies
- `flutter clean`
- `flutter pub get`
- `flutter build linux --debug`
- `flutter run -d linux`

### Option 3: Manual (from flutter_app directory)
```bash
cd flutter_app
source ~/.bashrc
flutter run -d linux
```

### Option 4: Hot Reload During Development
If app is already running:
- Press **`r`** = Hot reload (fast, keeps state)
- Press **`R`** = Hot restart (full restart)
- Press **`q`** = Quit app

---

## Requirements

### Backend Must Be Running
The Flutter desktop app **requires** the backend for OCR processing.

**Check backend:**
```bash
curl http://localhost:5001/health
```

**Start backend:**
```bash
docker-compose up -d
```

**Stop backend:**
```bash
docker-compose down
```

### Flutter Must Be Installed
If you see `flutter: command not found`:

```bash
source ~/.bashrc
```

If still not found, install Flutter:
```bash
./install_flutter_linux.sh
```

---

## Testing the App

### Test OCR Processing
1. Run: `./run_flutter.sh`
2. Click **"Choose from Gallery"**
3. Select an image (receipt, document, etc.)
4. **Watch the logs!** You'll see:
   ```
   [SYSTEM] Starting OCR processing...
   [SYSTEM] Connecting to backend...
   [TESSERACT] Detecting rotation...
   [TESSERACT] Processing with PSM 6...
   [HYBRID] Tesseract confidence: 0.87
   [OCR] Starting PaddleOCR...
   [REAL DATA] CPU: 45%, Memory: 2.3GB, I/O: 15MB/s
   [OCR] PaddleOCR complete!
   [SYSTEM] OCR processing complete!
   ```
5. View result in **Text/CSV/JSON/SQL** tabs
6. Check **History** to see saved result

### Test History
1. Process a few images
2. Click **"History"** button
3. Search, delete, or re-open results

---

## Troubleshooting

### Black Window
**Problem**: App opens but shows black screen

**Solution**: SQLite library missing
```bash
sudo dnf install -y sqlite-libs sqlite-devel
```

### "Backend required for desktop OCR"
**Problem**: Error dialog saying backend is required

**Solution**: Start the backend
```bash
docker-compose up -d
```

### "flutter: command not found"
**Problem**: Flutter not in PATH

**Solution**: Source bashrc
```bash
source ~/.bashrc
```

### Build Errors
**Problem**: Compilation errors

**Solution**: Clean and rebuild
```bash
cd flutter_app
flutter clean
flutter pub get
flutter run -d linux
```

### No Logs Showing
**Problem**: Processing screen shows no logs

**Solution**: 
1. Check backend is running: `curl http://localhost:5001/health`
2. Check backend logs: `docker-compose logs -f backend`
3. Restart app with hot restart: Press `R`

---

## Key Differences: Desktop vs Mobile

| Feature | Desktop (Linux/Windows/Mac) | Mobile (Android/iOS) |
|---------|----------------------------|----------------------|
| **OCR Engine** | Backend (Tesseract + PaddleOCR) | ML Kit → Tesseract → Backend |
| **Backend Required** | ✅ YES (mandatory) | ❌ NO (optional) |
| **Processing Speed** | 5-90 seconds | 2-90 seconds |
| **Camera** | ❌ No live camera | ✅ Live camera OCR |
| **Offline Mode** | ❌ Needs backend | ✅ Works offline |
| **Log Streaming** | ✅ Real-time logs | ⚠️ Not implemented yet |

---

## Files You Care About

- **`run_flutter.sh`** - Simple one-command launcher (USE THIS!)
- **`test_flutter_desktop.sh`** - Full clean build + test
- **`flutter_app/`** - Flutter app source code
- **`FLUTTER_DESKTOP_OCR_SUMMARY.md`** - Technical implementation details

---

## Summary

**To run the app:**
```bash
./run_flutter.sh
```

**To test OCR:**
1. Click "Choose from Gallery"
2. Select an image
3. Watch real-time logs
4. View results

**To stop:**
- Press `q` or `Ctrl+C`

**That's it!** 🎉

