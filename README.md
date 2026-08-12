# SpeechToPrompt

A macOS app that records your voice, transcribes it locally with [whisper.cpp](https://github.com/ggml-org/whisper.cpp), and organizes the results into projects and prompts — optionally refined or translated by an LLM.

## Features

- **Local transcription** — Whisper (`ggml-large-v3-turbo`) running on-device with Metal GPU acceleration; live transcription while recording.
- **Projects & prompts** — organize recordings into projects, rename, mark as done; raw and refined text stored as Markdown files.
- **AI refinement** — turn a raw transcription into a polished prompt via an Azure OpenAI / OpenAI-compatible endpoint (manual or automatic).
- **Auto-translate** — optionally translate transcriptions to English.
- **Attachments** — paste or drop images/files into a prompt; embedded as Markdown links.
- **Quality of life** — one-click copy, open file, reveal in Finder; automatic Spotify pause during recording; built-in model downloader and diagnostics log.

### Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Start / stop recording | `⌘R` |
| Show keyboard shortcuts | `⌘K` |
| Confirm dialog | `Return` |
| Close dialog | `Esc` |

## Tech Stack

- Swift 5.9 / SwiftUI, macOS 14+
- Swift Package Manager
- whisper.cpp (git submodule) with Metal backend
- AVFoundation for audio capture, AppleScript for Spotify control
- Data in `~/Library/Application Support/SpeechToPrompt/` (`projects.json`, `prompts/`, model, `diagnostics.log`)

## Prerequisites

- macOS 14.0+
- Xcode Command Line Tools (`xcode-select --install`)

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

The script builds the Swift package in release mode, assembles the `.app` bundle with Metal resources and entitlements, and codesigns it.

On first launch the app downloads the Whisper model (~1.5 GB) into Application Support. For AI refinement, open **Settings** (gear icon) and enter your API URL, key, model and API version.

## Project Structure

```
Package.swift               # Swift Package Manager manifest
build_app.sh                # Release build + app bundle
whisper.cpp/                # Git submodule — local speech-to-text inference
SpeechToPrompt/
  SpeechToPromptApp.swift   # Entry point
  RootView.swift            # Root view, settings & diagnostics sheets
  DashboardView.swift       # Empty state / project creation
  SidebarView.swift         # Project & prompt list
  ProjectWorkspaceView.swift, PromptDetailView.swift, RecordingOverlayView.swift
  AudioManager.swift        # Recording & resampling
  Whisper.swift, WhisperManager.swift  # Transcription
  ModelManager.swift        # Model download
  LLMManager.swift          # Refinement & translation
  AttachmentManager.swift   # Attachments
  ProjectStore.swift, Project.swift    # Persistence & models
  SpotifyManager.swift, DiagnosticsManager.swift
```
