#!/bin/bash
set -e

# Flutter App Automated Testing Script
# Uses xdotool for UI automation to abstract complexity from user

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/flutter_test_$(date +%Y%m%d_%H%M%S).log"
SCREENSHOT_DIR="$SCRIPT_DIR/screenshots_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$SCREENSHOT_DIR"

echo "╔══════════════════════════════════════════════════════════════════════╗" | tee -a "$LOG_FILE"
echo "║  FLUTTER APP AUTOMATED TEST                                          ║" | tee -a "$LOG_FILE"
echo "╚══════════════════════════════════════════════════════════════════════╝" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check dependencies
echo "📋 Checking dependencies..." | tee -a "$LOG_FILE"
command -v xdotool >/dev/null 2>&1 || { echo "❌ xdotool not found. Installing..."; sudo dnf install -y xdotool; }
command -v scrot >/dev/null 2>&1 || { echo "❌ scrot not found. Installing..."; sudo dnf install -y scrot; }
command -v flutter >/dev/null 2>&1 || { echo "❌ flutter not found. Run: source ~/.bashrc"; exit 1; }

echo "✅ All dependencies available" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Launch Flutter app in background
echo "🚀 Launching Flutter app..." | tee -a "$LOG_FILE"
cd "$SCRIPT_DIR"
source ~/.bashrc
flutter run -d linux > "$SCRIPT_DIR/flutter_output.log" 2>&1 &
FLUTTER_PID=$!
echo "   Flutter PID: $FLUTTER_PID" | tee -a "$LOG_FILE"

# Wait for app window to appear
echo "⏳ Waiting for app window..." | tee -a "$LOG_FILE"
WINDOW_ID=""
for i in {1..30}; do
    sleep 1
    WINDOW_ID=$(xdotool search --name "flutter_app" 2>/dev/null | head -1 || true)
    if [ -n "$WINDOW_ID" ]; then
        echo "✅ App window found: $WINDOW_ID" | tee -a "$LOG_FILE"
        break
    fi
    echo "   Attempt $i/30..." | tee -a "$LOG_FILE"
done

if [ -z "$WINDOW_ID" ]; then
    echo "❌ App window not found after 30 seconds" | tee -a "$LOG_FILE"
    echo "📄 Flutter output:" | tee -a "$LOG_FILE"
    tail -50 "$SCRIPT_DIR/flutter_output.log" | tee -a "$LOG_FILE"
    kill $FLUTTER_PID 2>/dev/null || true
    exit 1
fi

# Activate window
xdotool windowactivate "$WINDOW_ID"
sleep 1

# Take initial screenshot
echo "📸 Taking screenshot: initial state" | tee -a "$LOG_FILE"
scrot "$SCREENSHOT_DIR/01_initial.png" -u -b

# Check if window is black (error state)
echo "🔍 Analyzing window state..." | tee -a "$LOG_FILE"
WINDOW_GEOMETRY=$(xdotool getwindowgeometry "$WINDOW_ID")
echo "$WINDOW_GEOMETRY" | tee -a "$LOG_FILE"

# Get window title
WINDOW_TITLE=$(xdotool getwindowname "$WINDOW_ID")
echo "   Window title: $WINDOW_TITLE" | tee -a "$LOG_FILE"

# Check Flutter logs for errors
echo "" | tee -a "$LOG_FILE"
echo "📄 Flutter output (last 30 lines):" | tee -a "$LOG_FILE"
tail -30 "$SCRIPT_DIR/flutter_output.log" | tee -a "$LOG_FILE"

# Check for specific errors
if grep -q "Camera" "$SCRIPT_DIR/flutter_output.log"; then
    echo "" | tee -a "$LOG_FILE"
    echo "⚠️  Camera-related errors detected" | tee -a "$LOG_FILE"
fi

if grep -q "Exception" "$SCRIPT_DIR/flutter_output.log"; then
    echo "" | tee -a "$LOG_FILE"
    echo "❌ Exceptions detected in Flutter output" | tee -a "$LOG_FILE"
    grep "Exception" "$SCRIPT_DIR/flutter_output.log" | tee -a "$LOG_FILE"
fi

if grep -q "Error" "$SCRIPT_DIR/flutter_output.log"; then
    echo "" | tee -a "$LOG_FILE"
    echo "❌ Errors detected in Flutter output" | tee -a "$LOG_FILE"
    grep "Error" "$SCRIPT_DIR/flutter_output.log" | tee -a "$LOG_FILE"
fi

# Try to interact with the app
echo "" | tee -a "$LOG_FILE"
echo "🖱️  Attempting to interact with app..." | tee -a "$LOG_FILE"

# Click in center of window
WINDOW_X=$(echo "$WINDOW_GEOMETRY" | grep "Position" | awk '{print $2}' | cut -d',' -f1)
WINDOW_Y=$(echo "$WINDOW_GEOMETRY" | grep "Position" | awk '{print $2}' | cut -d',' -f2)
WINDOW_W=$(echo "$WINDOW_GEOMETRY" | grep "Geometry" | awk '{print $2}' | cut -d'x' -f1)
WINDOW_H=$(echo "$WINDOW_GEOMETRY" | grep "Geometry" | awk '{print $2}' | cut -d'x' -f2)

CENTER_X=$((WINDOW_X + WINDOW_W / 2))
CENTER_Y=$((WINDOW_Y + WINDOW_H / 2))

echo "   Clicking at center: ($CENTER_X, $CENTER_Y)" | tee -a "$LOG_FILE"
xdotool mousemove "$CENTER_X" "$CENTER_Y"
sleep 0.5
scrot "$SCREENSHOT_DIR/02_before_click.png" -u -b
xdotool click 1
sleep 1
scrot "$SCREENSHOT_DIR/03_after_click.png" -u -b

# Wait a bit to see if anything changes
sleep 3
scrot "$SCREENSHOT_DIR/04_after_wait.png" -u -b

echo "" | tee -a "$LOG_FILE"
echo "📊 Test Summary:" | tee -a "$LOG_FILE"
echo "   - Screenshots saved to: $SCREENSHOT_DIR" | tee -a "$LOG_FILE"
echo "   - Flutter output log: $SCRIPT_DIR/flutter_output.log" | tee -a "$LOG_FILE"
echo "   - Test log: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Keep app running for manual inspection
echo "✅ Test complete. App is still running (PID: $FLUTTER_PID)" | tee -a "$LOG_FILE"
echo "   Press Ctrl+C to stop the app, or run: kill $FLUTTER_PID" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Save PID for cleanup
echo "$FLUTTER_PID" > "$SCRIPT_DIR/flutter_app.pid"

wait $FLUTTER_PID

