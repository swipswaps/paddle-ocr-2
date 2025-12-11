#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  FLUTTER INSTALLATION FOR LINUX DESKTOP (Fedora 43)                  ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Install dependencies
echo "📦 Step 1: Installing dependencies..."
sudo dnf install -y \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  gtk3-devel \
  glib2-devel \
  libstdc++-devel \
  curl \
  git \
  unzip \
  xz

echo ""
echo "✅ Dependencies installed"
echo ""

# Step 2: Download Flutter
echo "📥 Step 2: Downloading Flutter SDK..."
cd ~
if [ -d "flutter" ]; then
  echo "⚠️  Flutter directory already exists. Removing old installation..."
  rm -rf flutter
fi

# Download latest stable Flutter for Linux
curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz -o flutter.tar.xz

echo ""
echo "✅ Flutter downloaded"
echo ""

# Step 3: Extract Flutter
echo "📂 Step 3: Extracting Flutter..."
tar xf flutter.tar.xz
rm flutter.tar.xz

echo ""
echo "✅ Flutter extracted to ~/flutter"
echo ""

# Step 4: Add to PATH
echo "🔧 Step 4: Adding Flutter to PATH..."

# Add to .bashrc
if ! grep -q 'export PATH="$PATH:$HOME/flutter/bin"' ~/.bashrc; then
  echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
  echo "✅ Added to ~/.bashrc"
else
  echo "⚠️  Already in ~/.bashrc"
fi

# Add to current session
export PATH="$PATH:$HOME/flutter/bin"

echo ""
echo "✅ Flutter added to PATH"
echo ""

# Step 5: Enable Linux desktop support
echo "🖥️  Step 5: Enabling Linux desktop support..."
flutter config --enable-linux-desktop

echo ""
echo "✅ Linux desktop enabled"
echo ""

# Step 6: Run flutter doctor
echo "🩺 Step 6: Running flutter doctor..."
flutter doctor

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  ✅ FLUTTER INSTALLATION COMPLETE!                                    ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Reload your shell:"
echo "   source ~/.bashrc"
echo ""
echo "2. Verify installation:"
echo "   flutter --version"
echo ""
echo "3. Run the Flutter app:"
echo "   cd ~/Documents/paddle-ocr/flutter_app"
echo "   flutter pub get"
echo "   flutter run -d linux"
echo ""
echo "🎉 You can now run Flutter apps on Linux desktop!"

