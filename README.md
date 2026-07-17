# SpeechToPrompt

A macOS menu bar app that records speech and transcribes it locally using [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

## Prerequisites

- macOS 14.0+
- Xcode Command Line Tools (`xcode-select --install`)
- A Whisper model file (e.g. `ggml-base.en.bin`) — download from the [whisper.cpp models page](https://huggingface.co/ggerganov/whisper.cpp/tree/main)

## Setup

```bash
git clone --recurse-submodules <repo-url>
cd speech-to-prompt
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

## Build & Run

```bash
./build_app.sh
open SpeechToPrompt.app
```

This builds the Swift package in release mode, assembles the `.app` bundle with Metal resources and entitlements, codesigns it, and launches it.

## Project Structure

```
Package.swift              # Swift Package Manager manifest
build_app.sh               # Build script (release build + app bundle)
whisper.cpp/               # Git submodule — local speech-to-text inference
SpeechToPrompt/            # App source code
  SpeechToPromptApp.swift  # Entry point
  RootView.swift           # Main view
  ProjectStore.swift       # Persistence layer
```
