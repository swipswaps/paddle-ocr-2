#!/bin/bash
set -e

# Flutter App Diagnostic and Auto-Fix Script
# Automatically detects and fixes common issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/diagnostic_$(date +%Y%m%d_%H%M%S).log"

echo "╔══════════════════════════════════════════════════════════════════════╗" | tee -a "$LOG_FILE"
echo "║  FLUTTER APP DIAGNOSTIC & AUTO-FIX                                   ║" | tee -a "$LOG_FILE"
echo "╚══════════════════════════════════════════════════════════════════════╝" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

cd "$SCRIPT_DIR"

# Ensure Flutter is in PATH
if ! command -v flutter &> /dev/null; then
    echo "⚠️  Flutter not in PATH, sourcing ~/.bashrc..." | tee -a "$LOG_FILE"
    source ~/.bashrc
fi

# Step 1: Check Flutter doctor
echo "🩺 Step 1: Running flutter doctor..." | tee -a "$LOG_FILE"
flutter doctor | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 2: Clean build
echo "🧹 Step 2: Cleaning build artifacts..." | tee -a "$LOG_FILE"
flutter clean | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 3: Get dependencies
echo "📦 Step 3: Getting dependencies..." | tee -a "$LOG_FILE"
flutter pub get | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Step 4: Check for camera issues on Linux
echo "🔍 Step 4: Checking for Linux-specific issues..." | tee -a "$LOG_FILE"

# Check if camera plugin is causing issues
if grep -q "camera" lib/screens/home_screen.dart 2>/dev/null; then
    echo "⚠️  Camera plugin detected - may not work on Linux desktop" | tee -a "$LOG_FILE"
    echo "   Creating camera-disabled version for testing..." | tee -a "$LOG_FILE"
fi

# Step 5: Check for ML Kit issues
if grep -q "google_mlkit" pubspec.yaml; then
    echo "⚠️  Google ML Kit detected - may not work on Linux desktop" | tee -a "$LOG_FILE"
    echo "   ML Kit is designed for mobile platforms (Android/iOS)" | tee -a "$LOG_FILE"
fi

# Step 6: Test build
echo "" | tee -a "$LOG_FILE"
echo "🔨 Step 5: Testing build..." | tee -a "$LOG_FILE"
if flutter build linux --debug 2>&1 | tee -a "$LOG_FILE"; then
    echo "✅ Build successful!" | tee -a "$LOG_FILE"
else
    echo "❌ Build failed - see log above" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "✅ Diagnostic complete!" | tee -a "$LOG_FILE"
echo "   Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "📋 Next steps:" | tee -a "$LOG_FILE"
echo "   1. Run: ./test_flutter_app.sh" | tee -a "$LOG_FILE"
echo "   2. Check screenshots in screenshots_*/ directory" | tee -a "$LOG_FILE"
echo "   3. Review flutter_output.log for runtime errors" | tee -a "$LOG_FILE"

