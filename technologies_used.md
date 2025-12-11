# 🛠️ Technologies Used

## Overview

This document catalogs all technologies, frameworks, libraries, and tools used in the Hybrid OCR App project, along with rationale for each choice.

---

## 📱 Frontend / Mobile App

### Flutter 3.x
**Purpose:** Cross-platform mobile and desktop app framework  
**Why Chosen:**
- Single codebase for Android, iOS, Linux, Windows, macOS, Web
- Native performance (compiled to native code)
- Rich UI components
- Strong community and ecosystem
- Google-backed (same company as ML Kit)

**Alternatives Considered:**
- React Native: Good, but slower than Flutter, less desktop support
- Kotlin Multiplatform: Android-first, limited iOS maturity
- Native (separate Android/iOS): Too much duplication

**Version:** `>=3.0.0`

---

### Dart
**Purpose:** Programming language for Flutter  
**Why Chosen:**
- Required for Flutter
- Strong typing with null safety
- Async/await for clean asynchronous code
- AOT compilation for performance

**Version:** `>=3.0.0`

---

## 🔍 OCR Engines

### 1. Google ML Kit Text Recognition
**Purpose:** Primary OCR engine for fast, accurate text recognition  
**Package:** `google_mlkit_text_recognition: ^0.13.0`

**Why Chosen:**
- ✅ **Fast:** 2-3 seconds on mobile devices
- ✅ **Accurate:** 85-95% for receipts and simple documents
- ✅ **Offline:** Works completely offline (bundled model)
- ✅ **Small:** ~4MB bundled, or ~260KB unbundled
- ✅ **Free:** No API costs
- ✅ **Mobile-optimized:** Designed for on-device inference
- ✅ **Multi-script:** Latin, Chinese, Devanagari, Japanese, Korean

**Supported Platforms:** Android, iOS

**API Example:**
```dart
final inputImage = InputImage.fromFile(imageFile);
final textRecognizer = TextRecognizer();
final recognizedText = await textRecognizer.processImage(inputImage);
```

**Limitations:**
- Not available on desktop (Linux, Windows, macOS)
- Lower accuracy on complex layouts vs PaddleOCR

---

### 2. Tesseract 5 OCR
**Purpose:** Secondary OCR engine for rotation detection and fallback  
**Package:** `flutter_tesseract_ocr: ^0.4.24`

**Why Chosen:**
- ✅ **Rotation detection:** PSM 0 for orientation and script detection
- ✅ **Full OCR capability:** PSM 3/6 for text extraction
- ✅ **Cross-platform:** Works on Android, iOS, Linux, Windows, macOS
- ✅ **Offline:** Completely offline
- ✅ **Free and open-source:** Apache 2.0 license
- ✅ **LSTM engine:** Tesseract 5 uses neural networks (OEM 1)
- ✅ **Mature:** 30+ years of development

**Why receipts-ocr Used It Poorly:**
```python
# receipts-ocr only used PSM 0 (orientation detection)
subprocess.run(["tesseract", tmp_path, "stdout", "--psm", "0"])
# This doesn't extract any text!
```

**How We'll Use It Properly:**
```dart
// 1. Detect rotation
final osd = await FlutterTesseractOcr.extractText(
  imagePath,
  args: {"psm": "0"},  // Orientation and script detection
);

// 2. Rotate image based on detection
final rotatedImage = await rotateImage(image, rotation);

// 3. Full OCR with optimal PSM
final text = await FlutterTesseractOcr.extractText(
  rotatedImage.path,
  args: {
    "psm": "6",  // Uniform block of text
    "oem": "1",  // LSTM engine
    "preserve_interword_spaces": "1",
  },
);
```

**PSM Modes:**
- `0`: Orientation and script detection only
- `3`: Fully automatic page segmentation (multi-column)
- `6`: Assume uniform block of text (best for receipts)
- `11`: Sparse text (find as much text as possible)

**Supported Platforms:** Android, iOS, Linux, Windows, macOS

---

### 3. PaddleOCR PP-OCRv4
**Purpose:** Tertiary OCR engine for complex documents (via Docker backend)  
**Package:** `paddleocr>=2.7.0` (Python)

**Why Chosen:**
- ✅ **Highest accuracy:** 95-99% on complex layouts
- ✅ **CJK support:** Excellent for Chinese, Japanese, Korean
- ✅ **Layout analysis:** Handles multi-column, tables, complex structures
- ✅ **Open-source:** Apache 2.0 license

**Why Not Primary:**
- ❌ **Slow:** 60-90 seconds on CPU
- ❌ **Large:** ~200MB+ models
- ❌ **Python-only:** Not available as native mobile library
- ❌ **Complex:** Requires backend server for mobile use

**Use Case:** Fallback for images where ML Kit and Tesseract have low confidence (<85%)

**Supported Platforms:** Linux, Windows, macOS (via Python), Docker

---

## 💾 Data Storage

### SQLite (via sqflite)
**Purpose:** Local database for offline-first storage  
**Package:** `sqflite: ^2.3.2`

**Why Chosen:**
- ✅ **Offline-first:** No network required
- ✅ **Fast:** Local file-based database
- ✅ **Lightweight:** ~1MB library
- ✅ **SQL support:** Familiar query language
- ✅ **Cross-platform:** Android, iOS, Linux, Windows, macOS

**Schema:**
```sql
CREATE TABLE receipts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  image_path TEXT NOT NULL,
  text TEXT,
  confidence REAL,
  engine TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  synced BOOLEAN DEFAULT 0
);
```

**Supported Platforms:** Android, iOS, Linux, Windows, macOS

---

### PostgreSQL 15
**Purpose:** Backend database for multi-device sync (optional)  
**Package:** `postgres:15-alpine` (Docker)

**Why Chosen:**
- ✅ **Robust:** Production-grade relational database
- ✅ **JSON support:** Store OCR metadata as JSONB
- ✅ **Full-text search:** Built-in text search capabilities
- ✅ **Replication:** Multi-device sync support

**Use Case:** Optional cloud sync when backend is available

**Supported Platforms:** Linux, Windows, macOS (via Docker)

---

## 📷 Image Processing

### image (Dart package)
**Purpose:** Image manipulation (resize, rotate, crop, filters)  
**Package:** `image: ^4.1.7`

**Why Chosen:**
- ✅ **Pure Dart:** No native dependencies
- ✅ **Cross-platform:** Works everywhere Flutter works
- ✅ **Rich features:** Resize, rotate, crop, filters, format conversion

**Use Cases:**
- Rotate images based on Tesseract OSD
- Resize large images before OCR
- Apply preprocessing filters (grayscale, sharpen, contrast)

---

### camera (Flutter plugin)
**Purpose:** Access device camera for capturing receipts  
**Package:** `camera: ^0.11.0`

**Why Chosen:**
- ✅ **Official Flutter plugin:** Maintained by Flutter team
- ✅ **Cross-platform:** Android, iOS, macOS, Windows
- ✅ **Real-time preview:** Show camera feed before capture
- ✅ **High resolution:** Support for 4K+ capture

---

### OpenCV (Python - Backend)
**Purpose:** Advanced image preprocessing on backend  
**Package:** `opencv-python-headless>=4.8.0`

**Why Chosen:**
- ✅ **Industry standard:** Most comprehensive computer vision library
- ✅ **Preprocessing:** Denoising, deskewing, binarization, edge detection
- ✅ **Headless:** No GUI dependencies for server use

**Use Cases:**
- Deskew rotated receipts
- Remove noise from low-quality images
- Enhance contrast for faded text
- Detect document boundaries

---

## 🌐 Backend (Optional Docker Services)

### Flask 3.x
**Purpose:** Python web framework for REST API  
**Package:** `flask>=3.0.0`

**Why Chosen:**
- ✅ **Lightweight:** Minimal overhead
- ✅ **Flexible:** Easy to add endpoints
- ✅ **Python ecosystem:** Works with PaddleOCR, OpenCV, psutil

**Endpoints:**
- `POST /ocr` - Process image with PaddleOCR
- `POST /ocr/advanced` - Advanced preprocessing + OCR
- `GET /logs/stream` - Server-Sent Events for real-time logs
- `GET /health` - Health check

---

### Gunicorn
**Purpose:** WSGI HTTP server for Flask  
**Package:** `gunicorn>=21.0.0`

**Why Chosen:**
- ✅ **Production-ready:** Battle-tested
- ✅ **Threading support:** `--threads 4` for concurrent requests
- ✅ **Worker processes:** `--workers 4` for CPU-bound tasks

**Configuration:**
```bash
gunicorn --bind 0.0.0.0:5001 --workers 4 --threads 2 --timeout 300 app:app
```

---

### Redis (Planned)
**Purpose:** Job queue and caching  
**Package:** `redis:7-alpine` (Docker)

**Why Chosen:**
- ✅ **Fast:** In-memory data store
- ✅ **Job queue:** With Celery for background processing
- ✅ **Caching:** Cache OCR results to avoid reprocessing

**Use Cases:**
- Queue batch OCR jobs
- Cache frequently accessed results
- Rate limiting

---

## 📊 Monitoring & Logging

### psutil
**Purpose:** System and process monitoring  
**Package:** `psutil>=5.9.0`

**Why Chosen:**
- ✅ **Real-time metrics:** CPU, memory, I/O, threads
- ✅ **Process-specific:** Track OCR worker process
- ✅ **Cross-platform:** Linux, Windows, macOS

**Critical Learning:**
> "Just because PaddleOCR is silent doesn't mean it does nothing"

**Use Case:**
```python
process = psutil.Process(os.getpid())
cpu_percent = process.cpu_percent(interval=0.5)
memory_mb = process.memory_info().rss / (1024 * 1024)
io_counters = process.io_counters()
```

---

## 🔄 State Management (Flutter)

### flutter_bloc
**Purpose:** State management for Flutter app  
**Package:** `flutter_bloc: ^8.1.4`

**Why Chosen:**
- ✅ **Predictable:** Unidirectional data flow
- ✅ **Testable:** Easy to unit test business logic
- ✅ **Scalable:** Works for small and large apps

**Use Cases:**
- OCR processing state (idle, processing, success, error)
- Camera state
- Sync state

---

## 🐳 Containerization

### Docker & Docker Compose
**Purpose:** Backend service orchestration  
**Version:** Docker 24.x, Compose V2

**Why Chosen:**
- ✅ **Isolation:** Each service in its own container
- ✅ **Reproducibility:** Same environment everywhere
- ✅ **Easy deployment:** `docker compose up`

**Services:**
- `paddleocr-backend`: Flask + PaddleOCR + Tesseract
- `postgres`: PostgreSQL database
- `redis`: Job queue and cache (planned)

---

## 📦 Package Managers

### pip (Python)
**Purpose:** Python package management  
**Best Practice:** Use `>=` for version constraints, not `==`

### pub (Dart/Flutter)
**Purpose:** Dart package management  
**Best Practice:** Use `^` for compatible versions

### npm (Node.js - for old frontend)
**Purpose:** JavaScript package management  
**Note:** Will be replaced by Flutter app

---

## 🔧 Development Tools

### VS Code
**Extensions:**
- Flutter
- Dart
- Python
- Docker

### Git
**Version Control:** All code tracked in Git

---

## 📊 Technology Decision Matrix

| Requirement | Technology | Rationale |
|-------------|-----------|-----------|
| Cross-platform UI | Flutter | Single codebase, native performance |
| Fast OCR | ML Kit | 2-3s, mobile-optimized |
| Rotation detection | Tesseract | PSM 0 for OSD |
| Fallback OCR | Tesseract | PSM 6 for full OCR |
| Complex documents | PaddleOCR | Highest accuracy |
| Local storage | SQLite | Offline-first |
| Cloud sync | PostgreSQL | Multi-device support |
| Image processing | image (Dart) | Pure Dart, cross-platform |
| Backend API | Flask | Python ecosystem |
| Monitoring | psutil | Real system metrics |
| State management | flutter_bloc | Predictable, testable |

---

**Next:** See `mistakes_and_solutions.md` for problems encountered and how they were solved.

