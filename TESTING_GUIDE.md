# Testing Guide

**Date**: 2025-12-10  
**Purpose**: How to test the Hybrid OCR system (React frontend + Flutter app + Backend)

---

## 🎯 Quick Answer: What Do I Need to Run?

### Testing React Frontend (Web Interface)

```bash
# Terminal 1: Start backend
docker compose up -d paddleocr-backend

# Terminal 2: Start React frontend
npm run dev

# Open browser: http://localhost:5173
```

**Features available**:
- ✅ Text/CSV/JSON/SQL tabs
- ✅ History button
- ✅ Advanced parsing
- ✅ Web-based interface
- ✅ PaddleOCR + Tesseract

---

### Testing Flutter App (Mobile/Desktop)

```bash
# Option A: Without backend (fastest, offline)
cd flutter_app
flutter run
# Works with ML Kit + Tesseract only

# Option B: With backend (full features)
# Terminal 1: Start backend
docker compose up -d paddleocr-backend

# Terminal 2: Run Flutter
cd flutter_app
flutter run
# Works with ML Kit + Tesseract + PaddleOCR
```

**Features available**:
- ✅ Live Text Detection (NEW!)
- ✅ Take Photo / Choose from Gallery
- ✅ Text/CSV/JSON/SQL tabs (NEW!)
- ✅ History screen (NEW!)
- ✅ Local SQLite database
- ✅ Offline-first (ML Kit + Tesseract)
- ✅ Optional PaddleOCR (if backend running)

---

## 📋 Testing Scenarios

### Scenario 1: Test Flutter App Standalone (No Backend)

**Goal**: Verify Flutter app works offline with ML Kit and Tesseract

**Steps**:
```bash
cd flutter_app
flutter run
```

**Test checklist**:
- [ ] App launches successfully
- [ ] Tap "Live Text Detection" → camera opens
- [ ] Point at text → text appears in < 1 second
- [ ] Tap "Take Photo" → camera opens → take photo
- [ ] OCR processes in 2-8 seconds
- [ ] Result screen shows with 4 tabs (Text/CSV/JSON/SQL)
- [ ] Tap each tab → content changes
- [ ] Tap copy icon → "copied to clipboard" message
- [ ] Tap History icon → history screen opens
- [ ] See saved result in history list
- [ ] Search for text → results filter
- [ ] Tap trash icon → confirm delete → result removed

**Expected performance**:
- Live text: < 1s latency
- Photo OCR: 2-8s (ML Kit or Tesseract)
- No PaddleOCR (backend not running)

---

### Scenario 2: Test Flutter App with Backend

**Goal**: Verify Flutter app can use PaddleOCR for difficult images

**Steps**:
```bash
# Terminal 1: Start backend
docker compose up -d paddleocr-backend
docker compose logs -f paddleocr-backend

# Terminal 2: Run Flutter
cd flutter_app
flutter run
```

**Test checklist**:
- [ ] Backend starts successfully
- [ ] Flutter app launches
- [ ] Take photo of difficult/rotated text
- [ ] OCR processes (may take 60-90s if using PaddleOCR)
- [ ] Check backend logs for monitoring data every 5s
- [ ] Check backend logs for lsof data every 10s
- [ ] Result shows "paddleocr" as engine
- [ ] Result saved to history

**Expected performance**:
- Easy images: 2-8s (ML Kit/Tesseract)
- Difficult images: 60-90s (PaddleOCR)
- Backend monitoring: 5s intervals (optimized)

---

### Scenario 3: Test React Frontend

**Goal**: Verify web interface works with all features

**Steps**:
```bash
# Terminal 1: Start backend
docker compose up -d paddleocr-backend

# Terminal 2: Start React
npm run dev

# Browser: http://localhost:5173
```

**Test checklist**:
- [ ] Web interface loads
- [ ] Upload image
- [ ] See real-time monitoring data during processing
- [ ] Result shows in Text tab
- [ ] Switch to CSV tab → see CSV format
- [ ] Switch to JSON tab → see JSON format
- [ ] Switch to SQL tab → see SQL format
- [ ] Click History button → see past results
- [ ] Search history → results filter

**Expected performance**:
- Processing: 15-90s (Tesseract → PaddleOCR cascade)
- Monitoring logs: Every 5s
- lsof logs: Every 10s

---

### Scenario 4: Test Backend Monitoring Optimization

**Goal**: Verify monitoring frequency reduced from 3s to 5s

**Steps**:
```bash
# Start backend with visible logs
docker compose up paddleocr-backend

# In another terminal: Upload large image
curl -X POST -F "file=@test_images/IMG_0372.jpg" http://localhost:5001/ocr
```

**Test checklist**:
- [ ] Logs show system metrics every 5 seconds (not 3)
- [ ] Logs show lsof output every 10 seconds (not every 5)
- [ ] CPU overhead reduced (compare with previous version)

**Expected log pattern**:
```
[REAL DATA] CPU: 45.2% | RAM: 1234MB ...     # t=0s
[REAL DATA] CPU: 52.1% | RAM: 1456MB ...     # t=5s
[REAL DATA] 12 model files | 45 files ...    # t=10s (lsof)
[REAL DATA] CPU: 67.8% | RAM: 2134MB ...     # t=15s
[REAL DATA] CPU: 89.3% | RAM: 3012MB ...     # t=20s
[REAL DATA] 12 model files | 45 files ...    # t=20s (lsof)
```

---

### Scenario 5: Test Flutter Image Optimization

**Goal**: Verify large images are downscaled before OCR

**Steps**:
```bash
cd flutter_app
flutter run --release  # Release mode for accurate performance
```

**Test images**:
1. Small image (< 2048px): Should process as-is
2. Large image (4000x3000px): Should auto-downscale

**Test checklist**:
- [ ] Upload small image → processes quickly (2-3s)
- [ ] Upload large image → processes quickly (2-3s, not 5-8s)
- [ ] Check processing time in result metadata
- [ ] Memory usage stays low (< 100MB)

**Expected performance**:
- Small images: 2-3s (ML Kit)
- Large images: 2-3s (ML Kit with auto-downscale)
- Memory: 50-100MB (vs 200-500MB before)

---

### Scenario 6: Test Live Text Detection

**Goal**: Verify real-time camera OCR works

**Requirements**: Physical device with camera (not emulator)

**Steps**:
```bash
cd flutter_app
flutter run  # Deploy to physical device
```

**Test checklist**:
- [ ] Tap "Live Text Detection" button
- [ ] Camera preview appears
- [ ] Point at receipt → text appears in overlay
- [ ] Point at document → text updates
- [ ] Point at sign → text updates
- [ ] Text appears in < 1 second
- [ ] Tap copy icon → text copied
- [ ] Back button returns to home

**Expected performance**:
- Latency: < 1 second
- Frame rate: 3-5 FPS
- Memory: ~100MB
- Battery: Low drain

---

## 🔍 Performance Benchmarks

### Before Optimizations

| Test | Time | Memory | CPU |
|------|------|--------|-----|
| Backend monitoring | 3s polling | N/A | 10-15% overhead |
| Flutter ML Kit (large) | 5-8s | 200-500MB | High |
| Flutter Tesseract (large) | 15-20s | 200-500MB | High |
| UI response | +1-2s delay | N/A | N/A |

### After Optimizations

| Test | Time | Memory | CPU |
|------|------|--------|-----|
| Backend monitoring | 5s polling | N/A | 2-3% overhead |
| Flutter ML Kit (optimized) | 2-3s | 50-100MB | Low |
| Flutter Tesseract (optimized) | 5-8s | 50-100MB | Low |
| UI response | Immediate | N/A | N/A |
| Live text detection | 200-300ms | ~100MB | Low |

---

## 🐛 Common Issues

### Issue: "Camera permission denied"
**Solution**: Enable camera permission in device settings

### Issue: "Backend not connecting" (Flutter)
**Solution**: 
- Use computer's IP address, not localhost
- Find IP: `ip addr` or `ifconfig`
- Update `main.dart`: `http://192.168.1.XXX:5001`

### Issue: "Port 5001 already in use"
**Solution**: 
```bash
docker compose down
docker compose up -d paddleocr-backend
```

### Issue: "Flutter build fails"
**Solution**:
```bash
cd flutter_app
flutter clean
flutter pub get
flutter run
```

---

## ✅ Testing Checklist Summary

### Backend
- [ ] Docker container starts
- [ ] Monitoring logs every 5s
- [ ] lsof logs every 10s
- [ ] OCR processing works
- [ ] CPU overhead < 5%

### React Frontend
- [ ] Web interface loads
- [ ] Image upload works
- [ ] All tabs work (Text/CSV/JSON/SQL)
- [ ] History button works
- [ ] Real-time monitoring visible

### Flutter App
- [ ] App launches
- [ ] Live text detection works
- [ ] Take photo works
- [ ] Gallery import works
- [ ] All tabs work (Text/CSV/JSON/SQL)
- [ ] History screen works
- [ ] Search works
- [ ] Delete works
- [ ] Offline mode works
- [ ] Backend connection works (optional)

---

## 📚 Related Documentation

- **[FLUTTER_APP_USER_GUIDE.md](FLUTTER_APP_USER_GUIDE.md)** - How to use Flutter app
- **[PERFORMANCE_OPTIMIZATIONS.md](PERFORMANCE_OPTIMIZATIONS.md)** - Optimization details
- **[FLUTTER_CASCADE_VERIFICATION.md](FLUTTER_CASCADE_VERIFICATION.md)** - Cascade logic

