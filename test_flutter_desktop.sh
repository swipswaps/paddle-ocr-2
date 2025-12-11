#!/bin/bash
# Single-command Flutter desktop test
# Handles everything automatically

cd "$(dirname "$0")/flutter_app"
source ~/.bashrc

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  FLUTTER DESKTOP - AUTOMATED BUILD & TEST                            ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Add dependencies
echo "📦 Adding desktop dependencies..."
flutter pub add file_selector sqflite_common_ffi

# Clean and get deps
echo "🧹 Cleaning..."
flutter clean
flutter pub get

# Build
echo "🔨 Building..."
flutter build linux --debug

# Run
echo "🚀 Running..."
echo ""
echo "✅ App should open in a new window"
echo "   - Click 'Choose Image File' to test"
echo "   - Press Ctrl+C here to stop the app"
echo ""

flutter run -d linux

