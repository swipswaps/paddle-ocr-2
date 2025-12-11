# Flutter App User Guide

**Date**: 2025-12-10  
**App**: Hybrid OCR Mobile App  
**Version**: 1.0.0

---

## 📱 How to Use the Flutter App

### Installation & Setup

#### Option 1: Run on Connected Device/Emulator

```bash
cd flutter_app

# Install dependencies (first time only)
flutter pub get

# Run on connected device or emulator
flutter run
```

#### Option 2: Build APK for Android

```bash
cd flutter_app

# Build release APK
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk

# Install on device:
adb install build/app/outputs/flutter-apk/app-release.apk
```

#### Option 3: Build for iOS (macOS only)

```bash
cd flutter_app

# Build iOS app
flutter build ios --release

# Open in Xcode to deploy
open ios/Runner.xcworkspace
```

---

## 🎯 Main Features

### 1. **Live Text Detection** 🆕 (Instant OCR)

**What it does**: Real-time text recognition through your camera - no photo needed!

**How to use**:
1. Tap the green **"Live Text Detection"** button on home screen
2. Point your camera at any text (receipt, document, sign, etc.)
3. Text appears instantly in the overlay at the bottom
4. Tap the copy icon to copy text to clipboard

**Performance**:
- Processing: 200-300ms per frame
- Latency: < 1 second
- Works offline (uses ML Kit)
- No backend required

**Best for**: Quick scans, instant lookups, copying text without saving

---

### 2. **Take Photo** (Capture & OCR)

**What it does**: Capture a photo and process it with hybrid OCR cascade

**How to use**:
1. Tap **"Take Photo"** button on home screen
2. Camera opens - take a photo of your document
3. App processes with smart cascade:
   - **Step 1**: ML Kit (2-3s) - Fast, mobile-optimized
   - **Step 2**: Tesseract (5-8s) - If ML Kit confidence < 90%
   - **Step 3**: PaddleOCR (60-90s) - If both fail & backend available
4. Result screen shows with tabs (Text/CSV/JSON/SQL)
5. Result automatically saved to local database

**Performance**:
- Average: 2-8 seconds (90% of images use ML Kit)
- Works offline (ML Kit + Tesseract)
- Optional backend for PaddleOCR

**Best for**: Documents you want to save and process later

---

### 3. **Choose from Gallery** (Import & OCR)

**What it does**: Select existing photo from gallery and process with OCR

**How to use**:
1. Tap **"Choose from Gallery"** button on home screen
2. Select image from your photo library
3. App processes with same hybrid cascade as "Take Photo"
4. Result screen shows with tabs
5. Result saved to database

**Best for**: Processing existing photos, batch processing screenshots

---

### 4. **History** 📚 (View Past Results)

**What it does**: Browse all past OCR results stored in local database

**How to use**:
1. Tap the **History icon** (clock) in top-right of home screen
2. See list of all past OCR results
3. **Search**: Type in search bar to filter by text or filename
4. **View**: Tap any result to see full details (coming soon)
5. **Delete**: Tap trash icon to delete a result

**Features**:
- Search by text content or filename
- Shows metadata: engine used, confidence, processing time
- Preview of detected text
- Relative timestamps ("2h ago", "3d ago")
- Swipe to refresh

**Storage**: All data stored locally in SQLite database on your device

---

## 📊 Result Screen (Tabs)

After OCR processing, you'll see a result screen with **4 tabs**:

### Tab 1: **Text** 📝

Shows the OCR result in plain text format:
- **Metadata card**: File, engine, confidence, processing time, blocks
- **Primary result**: Main OCR text (selectable)
- **Tesseract result**: Comparison result if available

**Actions**:
- Copy icon: Copies text to clipboard
- Share icon: Share text (coming soon)

---

### Tab 2: **CSV** 📊

Shows OCR result formatted as CSV (Comma-Separated Values):

```csv
Block,Line,Text,Confidence
"Block 1","Line 1","RECEIPT","95.2%"
"Block 1","Line 2","Total: $45.99","95.2%"
```

**Use cases**:
- Import into Excel/Google Sheets
- Data analysis
- Batch processing

**Actions**:
- Copy icon: Copies CSV to clipboard

---

### Tab 3: **JSON** 🔧

Shows OCR result formatted as JSON:

```json
{
  "filename": "IMG_0372.jpg",
  "engine": "mlkit",
  "confidence": 0.952,
  "processing_time": 2.3,
  "timestamp": "2025-12-10T15:30:00.000Z",
  "text": "RECEIPT\nTotal: $45.99",
  "blocks": [...]
}
```

**Use cases**:
- API integration
- Web development
- Data exchange

**Actions**:
- Copy icon: Copies JSON to clipboard

---

### Tab 4: **SQL** 🗄️

Shows OCR result as SQL INSERT statement:

```sql
INSERT INTO ocr_results (
  filename,
  engine,
  confidence,
  raw_text,
  timestamp,
  processing_time
) VALUES (
  'IMG_0372.jpg',
  'mlkit',
  0.952,
  'RECEIPT\nTotal: $45.99',
  '2025-12-10T15:30:00.000Z',
  2.3
);
```

**Use cases**:
- Database import
- Backup/restore
- Data migration

**Actions**:
- Copy icon: Copies SQL to clipboard

---

## 🔧 Configuration

### Backend Connection (Optional)

To enable PaddleOCR (most accurate, slowest):

1. **Start Docker backend**:
   ```bash
   docker compose up -d paddleocr-backend
   ```

2. **Configure Flutter app**:
   - Edit `flutter_app/lib/main.dart`
   - Set backend URL: `http://YOUR_IP:5001`
   - Default: `http://localhost:5001` (works on emulator)

3. **For physical device**:
   - Find your computer's IP: `ip addr` or `ifconfig`
   - Use: `http://192.168.1.XXX:5001`

**Without backend**:
- App works fine with ML Kit + Tesseract
- 90% of images process in 2-3 seconds
- Fully offline

---

## 📱 App Navigation

```
Home Screen
├─ [History Icon] → History Screen
│                   ├─ Search results
│                   ├─ View result (tap card)
│                   └─ Delete result (trash icon)
│
├─ [Live Text Detection] → Live Text Screen
│                          ├─ Real-time camera OCR
│                          └─ Copy text
│
├─ [Take Photo] → Camera → Result Screen
│                          ├─ Text tab
│                          ├─ CSV tab
│                          ├─ JSON tab
│                          └─ SQL tab
│
└─ [Choose from Gallery] → Gallery → Result Screen
                                     (same tabs as above)
```

---

## 🎨 UI Elements

### Home Screen
- **Title**: "Hybrid OCR"
- **History Icon**: Top-right corner (clock icon)
- **3 Main Buttons**:
  1. Green button: Live Text Detection
  2. Blue button: Take Photo
  3. Outlined button: Choose from Gallery

### Result Screen
- **Title**: "OCR Result"
- **Copy Icon**: Copies current tab content
- **Share Icon**: Share content (coming soon)
- **4 Tabs**: Text, CSV, JSON, SQL

### History Screen
- **Title**: "History"
- **Refresh Icon**: Reload results
- **Search Bar**: Filter by text/filename
- **Result Cards**: Tap to view, trash to delete

---

## ⚡ Performance Tips

1. **For fastest results**: Use Live Text Detection (instant)
2. **For good balance**: Take Photo with ML Kit (2-3s, 90% success)
3. **For best accuracy**: Enable backend for PaddleOCR fallback
4. **Large images**: App auto-downscales to 2048px for speed
5. **Battery saving**: Close Live Text Detection when not in use

---

## 🐛 Troubleshooting

### Camera not working
- Check app permissions: Settings → Apps → Hybrid OCR → Permissions
- Enable Camera permission

### Backend not connecting
- Verify Docker is running: `docker compose ps`
- Check IP address is correct (not localhost on physical device)
- Ensure port 5001 is accessible

### Slow processing
- Large images are auto-downscaled (this is normal)
- First run may be slower (model loading)
- Check if backend is running (adds 60-90s for PaddleOCR)

### No results in History
- Results only saved when using "Take Photo" or "Choose from Gallery"
- Live Text Detection does NOT save to history (by design)

---

## 📚 Related Documentation

- **[PERFORMANCE_OPTIMIZATIONS.md](PERFORMANCE_OPTIMIZATIONS.md)** - Performance improvements
- **[FLUTTER_CASCADE_VERIFICATION.md](FLUTTER_CASCADE_VERIFICATION.md)** - Cascade logic
- **[FLUTTER_APP_INTEGRATION.md](FLUTTER_APP_INTEGRATION.md)** - Technical integration details
- **[ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md)** - System architecture

