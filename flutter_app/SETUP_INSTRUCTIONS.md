# Flutter App Setup Instructions

This document provides step-by-step instructions for setting up and running the Flutter mobile app.

---

## Prerequisites

### 1. Install Flutter SDK

**Linux:**
```bash
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
flutter doctor
```

**macOS:**
```bash
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
flutter doctor
```

**Windows:**
1. Download Flutter SDK from https://flutter.dev/docs/get-started/install/windows
2. Extract to `C:\src\flutter`
3. Add `C:\src\flutter\bin` to PATH
4. Run `flutter doctor` in Command Prompt

### 2. Install Platform-Specific Tools

**Android (All Platforms):**
1. Install Android Studio: https://developer.android.com/studio
2. Open Android Studio → SDK Manager
3. Install Android SDK (API 34)
4. Install Android SDK Command-line Tools
5. Accept licenses: `flutter doctor --android-licenses`

**iOS (macOS only):**
1. Install Xcode from App Store
2. Install Xcode Command Line Tools: `xcode-select --install`
3. Accept license: `sudo xcodebuild -license`
4. Install CocoaPods: `sudo gem install cocoapods`

**Linux Desktop:**
```bash
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

### 3. Verify Installation

```bash
flutter doctor -v
```

Expected output:
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain - develop for Android devices
[✓] Xcode - develop for iOS and macOS (macOS only)
[✓] Linux toolchain - develop for Linux desktop (Linux only)
[✓] Android Studio
[✓] Connected device
```

---

## Project Setup

### 1. Navigate to Flutter App Directory

```bash
cd /home/owner/Documents/paddle-ocr/flutter_app
```

### 2. Install Dependencies

```bash
flutter pub get
```

This will download all packages listed in `pubspec.yaml`:
- google_mlkit_text_recognition
- flutter_tesseract_ocr
- sqflite
- camera
- image_picker
- http
- flutter_bloc
- etc.

### 3. Configure Backend URL (Optional)

Edit `lib/screens/home_screen.dart`:

```dart
_ocrService = OCRService(
  backendUrl: 'http://192.168.1.135:5001',  // Your backend IP
  // backendUrl: null,  // Offline-only mode
);
```

**Finding Your Backend IP:**
```bash
# On Linux/macOS
hostname -I | awk '{print $1}'

# Or use Docker host
# For Android emulator: http://10.0.2.2:5001
# For iOS simulator: http://localhost:5001
# For physical device: http://<your-computer-ip>:5001
```

---

## Running the App

### 1. Connect a Device

**Android Physical Device:**
1. Enable Developer Options on your Android device
2. Enable USB Debugging
3. Connect via USB
4. Verify: `flutter devices`

**Android Emulator:**
1. Open Android Studio → AVD Manager
2. Create/start an emulator
3. Verify: `flutter devices`

**iOS Simulator (macOS only):**
```bash
open -a Simulator
flutter devices
```

**Linux Desktop:**
```bash
# No device needed, runs on desktop
flutter devices
```

### 2. Run the App

```bash
# Run in debug mode
flutter run

# Run in release mode (faster)
flutter run --release

# Run on specific device
flutter run -d <device-id>
```

### 3. Hot Reload

While the app is running:
- Press `r` to hot reload (fast)
- Press `R` to hot restart (slower, full restart)
- Press `q` to quit

---

## Building Release Versions

### Android APK

```bash
# Build APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk

# Install on connected device
flutter install
```

### Android App Bundle (for Google Play)

```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS App (macOS only)

```bash
# Build iOS app
flutter build ios --release

# Open in Xcode for signing and deployment
open ios/Runner.xcworkspace
```

### Linux Desktop

```bash
flutter build linux --release

# Output: build/linux/x64/release/bundle/
```

---

## Testing

### Run Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/ocr_service_test.dart

# Run with coverage
flutter test --coverage
```

### Manual Testing Checklist

- [ ] App launches successfully
- [ ] Camera permission requested
- [ ] Gallery permission requested
- [ ] Camera capture works
- [ ] Gallery selection works
- [ ] ML Kit OCR completes in 2-3s
- [ ] Tesseract fallback works
- [ ] Backend connection works (if configured)
- [ ] Results display correctly
- [ ] Text can be copied
- [ ] App works offline
- [ ] Database saves results

---

## Troubleshooting

### "Flutter command not found"

```bash
# Add Flutter to PATH
export PATH="$PATH:$HOME/flutter/bin"

# Make permanent
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### "No devices found"

```bash
# Check connected devices
flutter devices

# For Android, enable USB debugging
# For iOS, trust computer on device
```

### "Gradle build failed" (Android)

```bash
# Clean build
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### "Pod install failed" (iOS)

```bash
cd ios
pod deintegrate
pod install
cd ..
flutter run
```

### "ML Kit model download failed"

- Ensure device has internet connection on first run
- ML Kit downloads models automatically (one-time, ~10MB)
- Check Google Play Services is installed (Android)

### "Tesseract language data missing"

- flutter_tesseract_ocr downloads data automatically
- Check storage permissions are granted
- Verify internet connection on first run

### "Backend connection failed"

```bash
# Verify backend is running
docker compose ps

# Check backend health
curl http://localhost:5001/health

# For physical device, use computer's IP
curl http://192.168.1.135:5001/health
```

---

## Development Tips

### VS Code Setup

1. Install Flutter extension
2. Install Dart extension
3. Open `flutter_app` folder in VS Code
4. Press F5 to run with debugging

### Android Studio Setup

1. Open `flutter_app` folder
2. Wait for Gradle sync
3. Click Run button (green triangle)

### Useful Commands

```bash
# Check for updates
flutter upgrade

# Analyze code
flutter analyze

# Format code
flutter format lib/

# Clean build artifacts
flutter clean

# Show device logs
flutter logs
```

---

## Next Steps

1. **Test the app** on your device
2. **Configure backend URL** if using PaddleOCR
3. **Customize UI** in `lib/screens/` files
4. **Add features** (history screen, export, etc.)
5. **Build release version** for distribution

For more information, see:
- Flutter documentation: https://flutter.dev/docs
- ML Kit documentation: https://developers.google.com/ml-kit/vision/text-recognition
- Tesseract documentation: https://github.com/tesseract-ocr/tesseract

