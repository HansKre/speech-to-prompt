#!/bin/bash
set -e

echo "Building SpeechToPrompt in release mode..."
swift build -c release

# Merge ggml-common.h into ggml-metal.metal in the build directory first
if [ -f ".build/release/whisper_whisper.bundle/ggml-metal.metal" ]; then
    if [ -f "whisper.cpp/ggml/src/ggml-common.h" ] && [ -f "whisper.cpp/ggml/src/ggml-metal.metal" ]; then
        echo "Embedding ggml-common.h into ggml-metal.metal in the build directory..."
        sed -e '/#include "ggml-common.h"/r whisper.cpp/ggml/src/ggml-common.h' -e '/#include "ggml-common.h"/d' < whisper.cpp/ggml/src/ggml-metal.metal > .build/release/whisper_whisper.bundle/ggml-metal.metal
    fi
fi

echo "Creating App Bundle..."
APP_DIR="SpeechToPrompt.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp ".build/release/SpeechToPrompt" "$APP_DIR/Contents/MacOS/SpeechToPrompt"

# Copy Whisper Metal resources bundle
if [ -d ".build/release/whisper_whisper.bundle" ]; then
    echo "Copying Whisper Metal resources bundle..."
    cp -R ".build/release/whisper_whisper.bundle" "$APP_DIR/Contents/Resources/"
fi


# Create Info.plist
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SpeechToPrompt</string>
    <key>CFBundleIdentifier</key>
    <string>com.privat.SpeechToPrompt</string>
    <key>CFBundleName</key>
    <string>SpeechToPrompt</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>This app needs access to the microphone to record your voice for transcription.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>This app needs to control Spotify to pause playback during audio recording.</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

# Codesign app bundle with entitlements
echo "Codesigning app bundle with entitlements..."
codesign --force --sign - --entitlements SpeechToPrompt/SpeechToPrompt.entitlements "$APP_DIR/Contents/MacOS/SpeechToPrompt"

echo "Done! You can now run the app with: open SpeechToPrompt.app"
