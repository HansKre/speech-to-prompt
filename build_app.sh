#!/bin/bash
set -e

echo "Building SpeechToPrompt in release mode..."
swift build -c release

echo "Creating App Bundle..."
APP_DIR="SpeechToPrompt.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp ".build/release/SpeechToPrompt" "$APP_DIR/Contents/MacOS/SpeechToPrompt"

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
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

echo "Done! You can now run the app with: open SpeechToPrompt.app"
