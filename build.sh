#!/bin/bash
export HOME="/home/ubuntu"
export FLUTTER_ROOT="$HOME/flutter"
export ANDROID_ROOT="$HOME/android-sdk"
export PATH="$FLUTTER_ROOT/bin:$ANDROID_ROOT/cmdline-tools/latest/bin:$ANDROID_ROOT/platform-tools:$PATH"
export ANDROID_HOME="$ANDROID_ROOT"

# Fix for "Flutter requires Android SDK 36"
yes | sdkmanager "platforms;android-36" "build-tools;36.0.0" || true
# Also ensure 34 is there as fallback
yes | sdkmanager "platforms;android-34" "build-tools;34.0.0" || true

flutter config --no-analytics
flutter build apk --debug
