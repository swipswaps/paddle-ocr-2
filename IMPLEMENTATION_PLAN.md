# 🚀 Implementation Plan: Hybrid OCR App

## Project Overview

**Goal:** Build Android + Linux compatible OCR app that improves upon receipts-ocr's reliability, speed, and UX

**Approach:** Flutter app with multi-engine OCR cascade (ML Kit → Tesseract → PaddleOCR)

**Timeline:** 3-4 weeks for MVP

---

## 📋 Phase 1: Flutter App Foundation (Week 1)

### Day 1-2: Project Setup

**Tasks:**
1. Create Flutter project
2. Set up project structure
3. Configure dependencies
4. Initialize Git repository

**Commands:**
```bash
# Create Flutter project
flutter create hybrid_ocr_app
cd hybrid_ocr_app

# Add dependencies
flutter pub add google_mlkit_text_recognition
flutter pub add flutter_tesseract_ocr
flutter pub add image
flutter pub add camera
flutter pub add sqflite
flutter pub add path_provider
flutter pub add http
flutter pub add flutter_bloc
flutter pub add equatable

# Initialize Git
git init
git add .
git commit -m "Initial Flutter project setup"
```

**Project Structure:**
```
hybrid_ocr_app/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── ocr_result.dart
│   │   └── receipt.dart
│   ├── services/
│   │   ├── ocr_service.dart
│   │   ├── ml_kit_service.dart
│   │   ├── tesseract_service.dart
│   │   ├── paddleocr_service.dart
│   │   ├── database_service.dart
│   │   └── sync_service.dart
│   ├── blocs/
│   │   ├── ocr_bloc.dart
│   │   ├── camera_bloc.dart
│   │   └── sync_bloc.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── camera_screen.dart
│   │   ├── result_screen.dart
│   │   └── history_screen.dart
│   └── widgets/
│       ├── confidence_indicator.dart
│       ├── ocr_result_card.dart
│       └── processing_overlay.dart
├── android/
├── ios/
├── linux/
├── test/
└── pubspec.yaml
```

**Deliverable:** Empty Flutter app that runs on Android and Linux

---

### Day 3-4: ML Kit Integration (Primary OCR)

**Tasks:**
1. Create `MLKitService` class
2. Implement image-to-text conversion
3. Calculate confidence scores
4. Add error handling

**Code:**
```dart
// lib/services/ml_kit_service.dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ocr_result.dart';

class MLKitService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  Future<OCRResult> recognizeText(File imageFile) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      stopwatch.stop();
      
      final confidence = _calculateConfidence(recognizedText);
      
      return OCRResult(
        text: recognizedText.text,
        confidence: confidence,
        engine: 'ML Kit',
        duration: stopwatch.elapsed,
        blocks: recognizedText.blocks.map((b) => {
          'text': b.text,
          'confidence': b.confidence ?? 0.0,
          'boundingBox': b.boundingBox,
        }).toList(),
      );
    } catch (e) {
      stopwatch.stop();
      throw OCRException('ML Kit failed: $e');
    }
  }
  
  double _calculateConfidence(RecognizedText text) {
    if (text.blocks.isEmpty) return 0.0;
    
    final confidences = text.blocks
        .where((b) => b.confidence != null)
        .map((b) => b.confidence!)
        .toList();
    
    if (confidences.isEmpty) return 0.5; // Default if no confidence data
    
    return confidences.reduce((a, b) => a + b) / confidences.length;
  }
  
  void dispose() {
    _textRecognizer.close();
  }
}
```

**Testing:**
```dart
// test/services/ml_kit_service_test.dart
void main() {
  test('ML Kit recognizes text from receipt image', () async {
    final service = MLKitService();
    final testImage = File('test/fixtures/receipt.jpg');
    
    final result = await service.recognizeText(testImage);
    
    expect(result.text, isNotEmpty);
    expect(result.confidence, greaterThan(0.0));
    expect(result.engine, equals('ML Kit'));
  });
}
```

**Deliverable:** Working ML Kit OCR with confidence scores

---

### Day 5-6: Tesseract Integration (Secondary OCR)

**Tasks:**
1. Create `TesseractService` class
2. Implement rotation detection (PSM 0)
3. Implement full OCR (PSM 6)
4. Add image rotation logic

**Code:**
```dart
// lib/services/tesseract_service.dart
import 'dart:io';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import '../models/ocr_result.dart';

class TesseractService {
  Future<OCRResult> recognizeText(File imageFile) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Step 1: Detect rotation
      final rotation = await _detectRotation(imageFile);
      
      // Step 2: Rotate image if needed
      final rotatedImage = rotation != 0 
          ? await _rotateImage(imageFile, rotation)
          : imageFile;
      
      // Step 3: Full OCR with optimal PSM
      final text = await FlutterTesseractOcr.extractText(
        rotatedImage.path,
        args: {
          "psm": "6",  // Uniform block of text
          "oem": "1",  // LSTM engine
          "preserve_interword_spaces": "1",
        },
      );
      
      stopwatch.stop();
      
      return OCRResult(
        text: text,
        confidence: _estimateConfidence(text),
        engine: 'Tesseract 5',
        duration: stopwatch.elapsed,
        metadata: {'rotation': rotation},
      );
    } catch (e) {
      stopwatch.stop();
      throw OCRException('Tesseract failed: $e');
    }
  }
  
  Future<int> _detectRotation(File imageFile) async {
    try {
      final osd = await FlutterTesseractOcr.extractText(
        imageFile.path,
        args: {"psm": "0"},  // Orientation and script detection
      );
      
      // Parse rotation from OSD output
      final rotateMatch = RegExp(r'Rotate: (\d+)').firstMatch(osd);
      return rotateMatch != null ? int.parse(rotateMatch.group(1)!) : 0;
    } catch (e) {
      return 0; // No rotation if detection fails
    }
  }
  
  Future<File> _rotateImage(File imageFile, int degrees) async {
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    
    if (image == null) return imageFile;
    
    final rotated = img.copyRotate(image, angle: degrees.toDouble());
    final rotatedPath = '${imageFile.parent.path}/rotated_${imageFile.uri.pathSegments.last}';
    final rotatedFile = File(rotatedPath);
    await rotatedFile.writeAsBytes(img.encodeJpg(rotated));
    
    return rotatedFile;
  }
  
  double _estimateConfidence(String text) {
    // Heuristic: longer text with proper words = higher confidence
    if (text.isEmpty) return 0.0;
    
    final words = text.split(RegExp(r'\s+'));
    final validWords = words.where((w) => w.length > 2).length;
    
    return (validWords / words.length).clamp(0.0, 1.0);
  }
}
```

**Deliverable:** Working Tesseract OCR with rotation correction

---

### Day 7: OCR Cascade Logic

**Tasks:**
1. Create `HybridOCRService` that combines all engines
2. Implement confidence-based cascade
3. Add fallback logic

**Code:**
```dart
// lib/services/ocr_service.dart
import 'dart:io';
import '../models/ocr_result.dart';
import 'ml_kit_service.dart';
import 'tesseract_service.dart';
import 'paddleocr_service.dart';

class HybridOCRService {
  final MLKitService _mlKit = MLKitService();
  final TesseractService _tesseract = TesseractService();
  final PaddleOCRService _paddleOCR = PaddleOCRService();
  
  Future<OCRResult> recognize(File imageFile) async {
    // Try ML Kit first (fast, accurate)
    final mlKitResult = await _mlKit.recognizeText(imageFile);
    if (mlKitResult.confidence > 0.90) {
      return mlKitResult;
    }
    
    // Try Tesseract with rotation correction
    final tesseractResult = await _tesseract.recognizeText(imageFile);
    if (tesseractResult.confidence > 0.85) {
      return tesseractResult;
    }
    
    // Fall back to PaddleOCR (if backend available)
    if (await _paddleOCR.isAvailable()) {
      return await _paddleOCR.recognizeText(imageFile);
    }
    
    // Return best result from local engines
    return mlKitResult.confidence > tesseractResult.confidence
        ? mlKitResult
        : tesseractResult;
  }
  
  void dispose() {
    _mlKit.dispose();
  }
}
```

**Deliverable:** Smart OCR cascade that chooses best engine

---

## 📋 Phase 2: Database & UI (Week 2)

### Day 8-9: SQLite Database

**Tasks:**
1. Create database schema
2. Implement CRUD operations
3. Add migration support

**Schema:**
```sql
CREATE TABLE receipts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  image_path TEXT NOT NULL,
  text TEXT,
  confidence REAL,
  engine TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  synced BOOLEAN DEFAULT 0,
  metadata TEXT  -- JSON
);
```

**Deliverable:** Working local database

---

### Day 10-11: Camera Integration

**Tasks:**
1. Implement camera screen
2. Add real-time preview
3. Add capture button
4. Process captured image

**Deliverable:** Working camera with OCR processing

---

### Day 12-13: Results UI

**Tasks:**
1. Display OCR results
2. Show confidence indicator
3. Allow editing of text
4. Add save/export options

**Deliverable:** Complete UI for viewing and editing results

---

### Day 14: History & Search

**Tasks:**
1. List all scanned receipts
2. Add search functionality
3. Add filters (by date, confidence)

**Deliverable:** Receipt history with search

---

## 📋 Phase 3: Docker Backend Integration (Week 3)

### Day 15-16: Enhance Docker Backend

**Tasks:**
1. Add proper Tesseract integration to backend
2. Improve PaddleOCR preprocessing
3. Add Redis for job queue
4. Update API endpoints

**Deliverable:** Enhanced Docker backend

---

### Day 17-18: Sync Service

**Tasks:**
1. Implement background sync
2. Handle offline/online transitions
3. Conflict resolution
4. Progress notifications

**Deliverable:** Working sync between Flutter and backend

---

### Day 19-20: Testing & Optimization

**Tasks:**
1. Test on real devices (Android phone, Linux desktop)
2. Benchmark performance
3. Optimize image preprocessing
4. Fix bugs

**Deliverable:** Tested, optimized app

---

### Day 21: Documentation & Deployment

**Tasks:**
1. Write user documentation
2. Create installation guide
3. Build release APK (Android)
4. Build Linux AppImage

**Deliverable:** Deployable app with documentation

---

## 📊 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Average OCR time | < 5 seconds | 90% of receipts |
| Accuracy | > 90% | Word-level accuracy |
| Offline functionality | 100% | Works without network |
| Platform support | Android + Linux | Both working |
| User satisfaction | > 4/5 stars | User feedback |

---

## 🎯 MVP Features (Must Have)

- [x] Camera capture
- [x] ML Kit OCR (primary)
- [x] Tesseract OCR (fallback)
- [x] Local SQLite storage
- [x] Receipt history
- [x] Confidence indicator
- [x] Text editing
- [x] Export to text/JSON

---

## 🚀 Future Features (Nice to Have)

- [ ] PaddleOCR backend integration
- [ ] Multi-device sync
- [ ] Receipt parsing (extract merchant, date, total)
- [ ] Expense categorization
- [ ] PDF export
- [ ] Batch processing
- [ ] Cloud backup

---

**Next Steps:** Start with Phase 1, Day 1-2 (Project Setup)

