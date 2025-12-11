# Hybrid OCR Flutter App

A mobile OCR application with intelligent cascade processing: ML Kit → Tesseract → PaddleOCR.

## Features

- **Fast Local OCR**: ML Kit (2-3s) and Tesseract (5-8s) run entirely on-device
- **Offline-First**: Works without internet connection using local engines
- **Optional Backend**: Connect to PaddleOCR backend for highest accuracy (60-90s)
- **Smart Cascade**: Automatically selects best engine based on confidence thresholds
- **Result Comparison**: View both Tesseract and PaddleOCR results side-by-side
- **Local Storage**: SQLite database for offline result storage
- **Cross-Platform**: Android, iOS, and Linux support

## Architecture

### OCR Cascade Strategy

```
1. ML Kit (2-3s, mobile-optimized)
   ├─ Confidence >= 90% → Return result
   └─ Confidence < 90% → Continue to step 2

2. Tesseract (5-8s, offline)
   ├─ Confidence >= 85% → Return result
   └─ Confidence < 85% → Continue to step 3

3. PaddleOCR via Backend (60-90s, most accurate)
   ├─ Backend available → Use PaddleOCR
   └─ Backend unavailable → Return best local result
```

### Technology Stack

- **Frontend**: Flutter 3.x (Dart)
- **OCR Engines**:
  - Google ML Kit Text Recognition (on-device)
  - Tesseract OCR (on-device)
  - PaddleOCR (via HTTP backend)
- **Storage**: SQLite (sqflite)
- **State Management**: BLoC pattern
- **Image Processing**: camera, image_picker, image packages

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── ocr_result.dart       # Data models
│   ├── services/
│   │   ├── ocr_service.dart      # Hybrid OCR logic
│   │   └── database_service.dart # SQLite operations
│   ├── screens/
│   │   ├── home_screen.dart      # Main screen
│   │   └── result_screen.dart    # Result display
│   └── widgets/
├── android/                      # Android configuration
├── ios/                          # iOS configuration
├── linux/                        # Linux configuration
└── pubspec.yaml                  # Dependencies
```

## Setup

### Prerequisites

1. **Flutter SDK**: Install from https://flutter.dev/docs/get-started/install
2. **Android Studio** (for Android) or **Xcode** (for iOS)
3. **Tesseract Data Files**: Automatically downloaded by flutter_tesseract_ocr

### Installation

```bash
cd flutter_app

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build APK (Android)
flutter build apk --release

# Build iOS app
flutter build ios --release
```

## Configuration

### Backend URL

Edit `lib/screens/home_screen.dart` to configure the backend:

```dart
_ocrService = OCRService(
  backendUrl: 'http://your-backend-ip:5001',  // Enable PaddleOCR
  // backendUrl: null,  // Offline-only mode
);
```

### Confidence Thresholds

Edit `lib/services/ocr_service.dart`:

```dart
static const double mlKitThreshold = 0.90;      // ML Kit threshold
static const double tesseractThreshold = 0.85;  // Tesseract threshold
```

## Usage

1. **Launch App**: Open the app on your device
2. **Capture Image**: Tap "Take Photo" or "Choose from Gallery"
3. **Processing**: Watch the cascade progress (ML Kit → Tesseract → PaddleOCR)
4. **View Results**: See extracted text with confidence scores
5. **Compare Results**: If Tesseract was used, compare with PaddleOCR result

## Permissions

### Android

- `INTERNET`: For backend communication
- `CAMERA`: For taking photos
- `READ_EXTERNAL_STORAGE`: For gallery access
- `WRITE_EXTERNAL_STORAGE`: For saving results

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select images</string>
```

## Performance

| Engine | Speed | Accuracy | Offline | Use Case |
|--------|-------|----------|---------|----------|
| ML Kit | 2-3s | Good | ✅ | Quick scans, simple text |
| Tesseract | 5-8s | Better | ✅ | Medium complexity |
| PaddleOCR | 60-90s | Best | ❌ | Complex layouts, high accuracy |

## Integration with React Frontend

This Flutter app is designed as a **secondary option** alongside the React frontend:

- **React Frontend**: Web-based UI at `http://localhost:5173`
- **Flutter App**: Mobile/desktop native app
- **Shared Backend**: Both connect to the same PaddleOCR backend at `http://localhost:5001`

Users can choose:
- **Web**: Use React frontend in browser
- **Mobile**: Use Flutter app on Android/iOS
- **Desktop**: Use Flutter app on Linux/Windows/macOS

## Troubleshooting

### ML Kit not working
- Ensure Google Play Services is installed (Android)
- Check internet connection for first-time model download

### Tesseract errors
- Verify language data files are downloaded
- Check storage permissions

### Backend connection failed
- Verify backend URL is correct
- Check firewall settings
- Ensure backend is running: `docker compose ps`

## Future Enhancements

- [ ] History screen with search
- [ ] Export results (PDF, TXT, JSON)
- [ ] Batch processing
- [ ] Cloud sync (optional)
- [ ] Custom confidence thresholds in UI
- [ ] Real-time camera OCR
- [ ] Multi-language support

## License

See parent project LICENSE file.

