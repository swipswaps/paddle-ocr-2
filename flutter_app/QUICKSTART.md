# Flutter App Quick Start

Get the Flutter OCR app running in 5 minutes.

---

## Prerequisites

You need Flutter SDK installed. If not installed:

```bash
# Linux/macOS
cd ~
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/flutter/bin"
flutter doctor
```

---

## Quick Setup

### 1. Install Dependencies

```bash
cd flutter_app
flutter pub get
```

### 2. Connect a Device

**Android Emulator:**
```bash
# Open Android Studio → AVD Manager → Start emulator
# Or from command line:
flutter emulators --launch <emulator_id>
```

**Physical Device:**
- Enable USB debugging on your device
- Connect via USB
- Verify: `flutter devices`

**Linux Desktop:**
```bash
# No device needed, runs on desktop
flutter devices
```

### 3. Run the App

```bash
flutter run
```

That's it! The app should launch on your device.

---

## Configuration

### Backend URL (Optional)

To enable PaddleOCR backend, edit `lib/screens/home_screen.dart`:

```dart
_ocrService = OCRService(
  backendUrl: 'http://YOUR_IP:5001',  // Enable PaddleOCR
);
```

**Find your backend IP:**
```bash
# Linux/macOS
hostname -I | awk '{print $1}'

# For Android emulator: http://10.0.2.2:5001
# For physical device: http://192.168.1.135:5001 (your computer's IP)
```

### Offline-Only Mode

Leave `backendUrl: null` to use only ML Kit and Tesseract (no internet needed).

---

## Usage

1. **Launch app** on your device
2. **Tap "Take Photo"** or **"Choose from Gallery"**
3. **Wait for processing**:
   - ML Kit: 2-3 seconds (fast)
   - Tesseract: 5-8 seconds (if ML Kit confidence < 90%)
   - PaddleOCR: 60-90 seconds (if Tesseract confidence < 85% and backend available)
4. **View results** with confidence scores
5. **Copy text** using the copy button

---

## Build Release APK

```bash
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk

# Install on device
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Troubleshooting

### "Flutter command not found"
```bash
export PATH="$PATH:$HOME/flutter/bin"
```

### "No devices found"
```bash
flutter devices
# Enable USB debugging on Android device
```

### "Gradle build failed"
```bash
flutter clean
flutter pub get
flutter run
```

### "Backend connection failed"
- Verify backend is running: `docker compose ps`
- Check backend URL in `home_screen.dart`
- Use computer's IP, not `localhost` (for physical devices)

---

## Features

- ✅ **Fast**: 2-3s with ML Kit (90% of cases)
- ✅ **Offline**: Works without internet
- ✅ **Accurate**: Falls back to PaddleOCR for complex text
- ✅ **Comparison**: See results from multiple engines
- ✅ **Local Storage**: SQLite database

---

## Next Steps

- See `SETUP_INSTRUCTIONS.md` for detailed setup
- See `README.md` for full documentation
- See `../FLUTTER_APP_INTEGRATION.md` for architecture details

---

## Support

For issues or questions:
1. Check `SETUP_INSTRUCTIONS.md`
2. Run `flutter doctor -v` to diagnose issues
3. Check logs: `flutter logs`

