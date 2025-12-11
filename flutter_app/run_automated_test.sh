#!/bin/bash
# Master automation script - handles everything automatically
# No manual intervention required

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  FLUTTER APP - FULLY AUTOMATED TEST & DIAGNOSTIC                    ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Source bashrc to get Flutter in PATH
source ~/.bashrc

# Step 1: Add missing dependency
echo "📦 Step 1: Adding file_selector dependency..."
flutter pub add file_selector

# Step 2: Clean and rebuild
echo ""
echo "🧹 Step 2: Cleaning build..."
flutter clean

echo ""
echo "📦 Step 3: Getting all dependencies..."
flutter pub get

# Step 3: Build
echo ""
echo "🔨 Step 4: Building Linux app..."
flutter build linux --debug

# Step 4: Run with automated testing
echo ""
echo "🚀 Step 5: Launching app..."
chmod +x test_flutter_app.sh diagnose_and_fix.sh
./test_flutter_app.sh

