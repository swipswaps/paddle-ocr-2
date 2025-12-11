#!/bin/bash
# Simple script to run Flutter desktop app
# Run from paddle-ocr root directory: ./run_flutter.sh

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  FLUTTER DESKTOP OCR APP                                             ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if backend is running
echo "🔍 Checking backend status..."
if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo "✅ Backend is running at http://localhost:5001"
else
    echo "⚠️  Backend is NOT running!"
    echo ""
    echo "   Starting backend..."
    docker-compose up -d
    echo "   Waiting for backend to be ready..."
    sleep 3
    if curl -s http://localhost:5001/health > /dev/null 2>&1; then
        echo "✅ Backend started successfully"
    else
        echo "❌ Backend failed to start. Check: docker-compose logs"
        exit 1
    fi
fi

echo ""
echo "🚀 Starting Flutter app..."
echo ""
echo "   📝 Features:"
echo "      • Click 'Choose from Gallery' to select an image"
echo "      • Watch REAL-TIME LOGS during OCR processing"
echo "      • View results in Text/CSV/JSON/SQL tabs"
echo "      • Check History for past results"
echo ""
echo "   ⌨️  Hot reload: Press 'r' in this terminal"
echo "   🛑 Stop app: Press 'q' or Ctrl+C"
echo ""

cd flutter_app
source ~/.bashrc
flutter run -d linux

