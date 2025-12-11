# 🎯 Hybrid Multi-Engine OCR Architecture

## Executive Summary

This architecture improves upon receipts-ocr by combining **three OCR engines** in a smart cascade:
1. **Google ML Kit** (Primary) - Fast, offline, mobile-optimized
2. **Tesseract 5** (Secondary) - Rotation detection, fallback OCR
3. **PaddleOCR** (Tertiary) - Complex documents, batch processing via Docker backend

**Key Improvement:** receipts-ocr used Tesseract poorly (only for rotation detection). We'll use it properly as a full OCR fallback.

---

## 📊 How receipts-ocr Used Tesseract (Poorly)

### What receipts-ocr Did:
```python
# Only used Tesseract for Orientation and Script Detection (OSD)
subprocess.run(["tesseract", tmp_path, "stdout", "--psm", "0"])
# PSM 0 = Orientation and script detection only, NO OCR!
```

**Problems:**
- ❌ Only detected rotation, didn't extract text
- ❌ Wasted Tesseract's OCR capabilities
- ❌ Still relied on PaddleOCR (60-90 seconds)
- ❌ No fallback if PaddleOCR failed

---

## ✅ Improved Multi-Engine Strategy

### Engine Comparison

| Engine | Speed | Accuracy | Offline | Mobile | Best For |
|--------|-------|----------|---------|--------|----------|
| **ML Kit** | ⚡ 2-3s | 85-95% | ✅ Yes | ✅ Native | Receipts, simple docs |
| **Tesseract 5** | ⚡ 3-5s | 80-90% | ✅ Yes | ✅ Yes | Rotated text, fallback |
| **PaddleOCR** | 🐌 60-90s | 95-99% | ✅ Yes | ❌ No | Complex layouts, CJK |

### Cascade Logic

```
┌─────────────────────────────────────────────────────────────┐
│ 1. ML Kit (Primary - Fast & Accurate)                       │
│    ├─ Confidence > 90% → DONE ✅                            │
│    └─ Confidence < 90% → Continue to Tesseract              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Tesseract 5 (Secondary - Rotation + OCR)                 │
│    ├─ Detect rotation (PSM 0)                               │
│    ├─ Auto-rotate image                                     │
│    ├─ Full OCR (PSM 3 or PSM 6)                             │
│    ├─ Confidence > 85% → DONE ✅                            │
│    └─ Confidence < 85% → Continue to PaddleOCR              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. PaddleOCR (Tertiary - Heavy Artillery)                   │
│    ├─ Send to Docker backend (if available)                 │
│    ├─ Advanced preprocessing (deskew, denoise)              │
│    ├─ PaddleOCR PP-OCRv4 (60-90s)                           │
│    └─ Return best result ✅                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Architecture Components

### Flutter App (Offline-First)

```dart
class HybridOCRService {
  // Primary: Google ML Kit
  Future<OCRResult> recognizeWithMLKit(File image) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer();
    final recognizedText = await textRecognizer.processImage(inputImage);
    
    return OCRResult(
      text: recognizedText.text,
      confidence: calculateConfidence(recognizedText),
      engine: 'ML Kit',
      duration: stopwatch.elapsed,
    );
  }
  
  // Secondary: Tesseract (IMPROVED - Full OCR, not just rotation!)
  Future<OCRResult> recognizeWithTesseract(File image) async {
    // Step 1: Detect rotation
    final osdResult = await FlutterTesseractOcr.extractText(
      image.path,
      args: {
        "psm": "0",  // Orientation and script detection
      },
    );
    
    final rotation = parseRotation(osdResult);
    
    // Step 2: Rotate image if needed
    final rotatedImage = rotation != 0 
        ? await rotateImage(image, rotation) 
        : image;
    
    // Step 3: Full OCR with optimal PSM
    final ocrResult = await FlutterTesseractOcr.extractText(
      rotatedImage.path,
      args: {
        "psm": "6",  // Assume uniform block of text
        "preserve_interword_spaces": "1",
      },
    );
    
    return OCRResult(
      text: ocrResult,
      confidence: calculateTesseractConfidence(ocrResult),
      engine: 'Tesseract 5',
      duration: stopwatch.elapsed,
      metadata: {'rotation': rotation},
    );
  }
  
  // Tertiary: PaddleOCR via Docker backend
  Future<OCRResult> recognizeWithPaddleOCR(File image) async {
    final response = await http.post(
      Uri.parse('http://backend:5001/ocr'),
      headers: {'Content-Type': 'application/octet-stream'},
      body: await image.readAsBytes(),
    );
    
    final data = jsonDecode(response.body);
    return OCRResult(
      text: data['text'],
      confidence: data['confidence'],
      engine: 'PaddleOCR',
      duration: Duration(milliseconds: data['duration_ms']),
      metadata: data['metadata'],
    );
  }
  
  // Smart cascade
  Future<OCRResult> recognize(File image) async {
    // Try ML Kit first
    final mlKitResult = await recognizeWithMLKit(image);
    if (mlKitResult.confidence > 0.90) {
      return mlKitResult;
    }
    
    // Try Tesseract with rotation correction
    final tesseractResult = await recognizeWithTesseract(image);
    if (tesseractResult.confidence > 0.85) {
      return tesseractResult;
    }
    
    // Fall back to PaddleOCR (if backend available)
    if (await isBackendAvailable()) {
      return await recognizeWithPaddleOCR(image);
    }
    
    // Return best result from local engines
    return mlKitResult.confidence > tesseractResult.confidence
        ? mlKitResult
        : tesseractResult;
  }
}
```

---

## 🔧 Tesseract Improvements Over receipts-ocr

### What receipts-ocr Did Wrong:

```python
# receipts-ocr/backend/app.py line 1113
result = subprocess.run(
    ["tesseract", tmp_path, "stdout", "--psm", "0"],  # PSM 0 = OSD only!
    capture_output=True,
    text=True,
    timeout=30,
)
# Only parsed rotation angle, never used Tesseract for actual OCR
```

**Issues:**
1. ❌ PSM 0 = Orientation/Script Detection only (no text extraction)
2. ❌ Detected rotation but didn't use it to improve OCR
3. ❌ Wasted subprocess overhead for minimal benefit
4. ❌ No confidence scoring
5. ❌ No preprocessing optimization

### What We'll Do Right:

```python
# 1. Detect rotation with PSM 0
osd_result = tesseract.image_to_osd(image)
rotation = parse_rotation(osd_result)

# 2. Rotate image
rotated = rotate_image(image, rotation)

# 3. Preprocess for better accuracy
preprocessed = preprocess_for_tesseract(rotated)

# 4. Full OCR with optimal PSM
text = tesseract.image_to_string(
    preprocessed,
    config='--psm 6 --oem 1'  # PSM 6 = uniform block, OEM 1 = LSTM
)

# 5. Get confidence scores
data = tesseract.image_to_data(preprocessed, output_type=Output.DICT)
confidence = calculate_average_confidence(data['conf'])
```

**Improvements:**
1. ✅ Use rotation detection to actually improve results
2. ✅ Full OCR with Tesseract 5 LSTM engine (OEM 1)
3. ✅ Proper PSM selection (6 for receipts, 3 for multi-column)
4. ✅ Confidence scoring for cascade decisions
5. ✅ Image preprocessing (denoise, sharpen, binarize)

---

## 📱 Flutter Packages Required

```yaml
dependencies:
  # Primary OCR
  google_mlkit_text_recognition: ^0.13.0

  # Secondary OCR
  flutter_tesseract_ocr: ^0.4.24

  # Image processing
  image: ^4.1.7
  camera: ^0.11.0

  # Local storage
  sqflite: ^2.3.2
  path_provider: ^2.1.2

  # HTTP client (for Docker backend)
  http: ^1.2.0

  # UI
  flutter_bloc: ^8.1.4
  equatable: ^2.0.5
```

---

## 🐳 Docker Backend Enhancements

### Keep from receipts-ocr:
- PostgreSQL for multi-device sync
- Flask API structure
- Logging infrastructure

### Improve:
1. **Add Tesseract to Docker backend** (receipts-ocr had it but didn't use it properly)
2. **Add Redis** for job queuing
3. **Add MinIO** for image storage
4. **Improve PaddleOCR integration** with better preprocessing

### Updated Dockerfile:

```dockerfile
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # OpenCV dependencies
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    # Tesseract OCR (IMPROVED - actually use it!)
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-chi-sim \
    tesseract-ocr-jpn \
    libtesseract-dev \
    # Utils
    procps \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5001

CMD ["gunicorn", "--bind", "0.0.0.0:5001", "--workers", "4", "--threads", "2", "--timeout", "300", "app:app"]
```

### Updated requirements.txt:

```txt
flask>=3.0.0
flask-cors>=4.0.0
paddleocr>=2.7.0
paddlepaddle>=2.5.0
opencv-python-headless>=4.8.0
numpy>=1.24.0,<2.0.0
psycopg2-binary>=2.9.0
gunicorn>=21.0.0
psutil>=5.9.0

# ADD: Tesseract Python bindings
pytesseract>=0.3.10

# ADD: Redis for job queue
redis>=5.0.0
celery>=5.3.0

# ADD: Image processing
Pillow>=10.0.0
scikit-image>=0.22.0
```

---

## 🎯 Performance Comparison

### receipts-ocr (Old):
```
User uploads receipt
  ↓
PaddleOCR processes (60-90 seconds)
  ↓
Result returned
```
**Total time:** 60-90 seconds
**Offline:** Yes (but slow)
**Mobile:** No (Docker required)

### Hybrid Architecture (New):
```
User uploads receipt
  ↓
ML Kit processes (2-3 seconds) → 90% success rate
  ↓ (if confidence < 90%)
Tesseract processes (3-5 seconds) → 8% additional success
  ↓ (if confidence < 85%)
PaddleOCR processes (60-90 seconds) → 2% edge cases
```
**Average time:** 2-3 seconds (90% of cases)
**Offline:** Yes (fast)
**Mobile:** Yes (native)

---

## 🔄 Sync Strategy (Flutter ↔ Docker)

### Offline-First Workflow:

```dart
class SyncService {
  Future<void> processReceipt(File image) async {
    // 1. Process locally (fast)
    final localResult = await hybridOCR.recognize(image);

    // 2. Save to local SQLite immediately
    await db.insert('receipts', {
      'image_path': image.path,
      'text': localResult.text,
      'confidence': localResult.confidence,
      'engine': localResult.engine,
      'synced': false,
    });

    // 3. Show result to user immediately (no waiting!)
    showResult(localResult);

    // 4. Background sync to Docker backend (if available)
    if (await isBackendAvailable() && localResult.confidence < 0.90) {
      syncToBackend(image, localResult);
    }
  }

  Future<void> syncToBackend(File image, OCRResult localResult) async {
    // Send to backend for better processing
    final backendResult = await http.post(
      Uri.parse('http://backend:5001/ocr/advanced'),
      body: {
        'image': base64Encode(await image.readAsBytes()),
        'local_result': jsonEncode(localResult.toJson()),
      },
    );

    // Update local database with better result
    if (backendResult.confidence > localResult.confidence) {
      await db.update('receipts', {
        'text': backendResult.text,
        'confidence': backendResult.confidence,
        'engine': 'PaddleOCR',
        'synced': true,
      });

      // Notify user of improved result
      showNotification('Receipt re-processed with better accuracy!');
    }
  }
}
```

---

## 📊 Expected Results

### Speed Improvements:
- **90% of receipts:** 2-3 seconds (ML Kit)
- **8% of receipts:** 5-8 seconds (Tesseract fallback)
- **2% of receipts:** 60-90 seconds (PaddleOCR for complex cases)
- **Average:** ~5 seconds (vs 60-90 seconds in receipts-ocr)

### Accuracy Improvements:
- **ML Kit:** 85-95% (good for most receipts)
- **Tesseract:** 80-90% (handles rotated text better)
- **PaddleOCR:** 95-99% (complex layouts, CJK text)
- **Combined:** 95%+ (best engine wins)

### Platform Support:
- ✅ Android (native app)
- ✅ iOS (native app)
- ✅ Linux (desktop app)
- ✅ Windows (desktop app)
- ✅ macOS (desktop app)
- ✅ Web (browser app)

---

## 🚀 Next Steps

1. **Build Flutter app** with ML Kit + Tesseract
2. **Test cascade logic** with real receipts
3. **Enhance Docker backend** with proper Tesseract integration
4. **Implement sync strategy** for offline-first operation
5. **Benchmark performance** against receipts-ocr

**Key Principle:** Fast local processing first, cloud enhancement later (optional).

