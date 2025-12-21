#!/bin/bash
set -e

# Configuration
INSTALL_DIR="$HOME"
FLUTTER_ROOT="$INSTALL_DIR/flutter"
ANDROID_ROOT="$INSTALL_DIR/android-sdk"
# URL for Command Line Tools 11.0 (latest as of late 2024)
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

echo "=========================================="
echo "  Flutter & Android SDK Setup Script"
echo "=========================================="

# 1. Install system dependencies
echo "[1/6] Checking system dependencies..."
if command -v apt-get &> /dev/null; then
    echo "Installing dependencies via apt-get (requires sudo)..."
    sudo apt-get update
    sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk clang cmake ninja-build pkg-config libgtk-3-dev
else
    echo "Warning: 'apt-get' not found. Ensure the following are installed:"
    echo "  curl, git, unzip, xz-utils, zip, libglu1-mesa, openjdk-17-jdk, clang, cmake, ninja-build, pkg-config, libgtk-3-dev"
fi

# 2. Install Flutter SDK
echo "[2/6] Setting up Flutter SDK..."
if [ ! -d "$FLUTTER_ROOT" ]; then
    echo "Cloning Flutter (stable)..."
    git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_ROOT"
else
    echo "Flutter SDK found at $FLUTTER_ROOT"
fi

# 3. Install Android SDK Command Line Tools
echo "[3/6] Setting up Android SDK..."
if [ ! -d "$ANDROID_ROOT/cmdline-tools/latest" ]; then
    echo "Creating Android SDK directory..."
    mkdir -p "$ANDROID_ROOT/cmdline-tools"
    
    echo "Downloading Android Command Line Tools..."
    curl -o cmdline-tools.zip "$CMDLINE_TOOLS_URL"
    
    echo "Extracting..."
    unzip -q cmdline-tools.zip -d "$ANDROID_ROOT/cmdline-tools"
    
    # Move to 'latest' structure required by sdkmanager
    mv "$ANDROID_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_ROOT/cmdline-tools/latest"
    rm cmdline-tools.zip
else
    echo "Android Command Line Tools found at $ANDROID_ROOT"
fi

# 4. Configure Environment Variables for this session
export PATH="$FLUTTER_ROOT/bin:$ANDROID_ROOT/cmdline-tools/latest/bin:$ANDROID_ROOT/platform-tools:$PATH"
export ANDROID_HOME="$ANDROID_ROOT"

# 5. Install Android Components and Accept Licenses
echo "[4/6] Installing Android SDK Platform & Tools..."
# Accept licenses automatically
yes | sdkmanager --licenses > /dev/null 2>&1 || true

# Install specific versions matching the project
# Note: android-34 and build-tools;34.0.0 match the current project configuration
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "cmake;3.22.1" "ndk;26.1.10909125"

# 6. Final Flutter Setup
echo "[5/6] verifying Flutter configuration..."
flutter config --no-analytics
flutter doctor --android-licenses || true # Redundant check to ensure flutter sees them

echo "[6/6] Running Flutter Doctor..."
flutter doctor

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo "To use Flutter in future sessions, add these lines to your shell profile (~/.bashrc, ~/.zshrc):"
echo ""
echo "export PATH=\"\$PATH:$FLUTTER_ROOT/bin\""
echo "export ANDROID_HOME=\"$ANDROID_ROOT\""
echo "export PATH=\"\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools\""
echo ""
