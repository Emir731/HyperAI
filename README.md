# Hyper AI

Hyper AI is a Flutter chat app for local GGUF inference. Chat generation does
not call a hosted AI service. The model and vision projector are downloaded
once and stored in app-private storage; inference runs locally afterward.

## Current functionality

- First-run download of a Qwen3.5 4B quantized model and vision projector.
- Resumable HTTP downloads with progress and pause/retry behavior.
- Select a local GGUF model and separate multimodal projector manually.
- Load, unload, and replace the local inference engine.
- Stream responses and cancel the active generation.
- Select a gallery image and submit it with a prompt.
- Persist chat history, model paths, language, and generation settings locally.
- Create chats, rename or delete conversations, and edit, copy, or delete
  messages.
- English, Turkish, and Russian interface labels.
- Context length, temperature, output token limit, and CPU thread settings.

## First-run model setup

On first launch, the welcome screen offers a download action. It downloads the
Qwen3.5 4B Q4_K_M model and its F16 vision projector from the public
`gguf/Qwen3.5-4B-GGUF` Hugging Face repository into app-private storage.
The combined download is about 3.45 GB. Use Wi-Fi and keep at least 4 GB of
free storage available. Partial `.part` files are retained so a later retry
can resume with an HTTP Range request when supported by the server.

The downloader checks exact expected file sizes and writes a local SHA-256
fingerprint sidecar after each completed file. The source repository does not
publish a trusted SHA-256 manifest for these quantized artifacts, so this
fingerprint is an audit value, not a comparison against an upstream checksum.
No Hugging Face token is embedded in the app. The source repository must remain
public for first-run downloads to work.

After download, press Load model in Model settings. Later launches reuse the
files in app-private storage; inference itself works offline. Manual file
selection remains available.

## Model files

The downloader expects these exact, case-sensitive filenames:

1. `qwen3.5-4b-Q4_K_M.gguf`
2. `mmproj-qwen3.5-4b-F16.gguf`

The app passes the model and projector as local `ModelSource.path` values to
llamaDart and passes selected images as `LlamaImageContent(path: ...)`.
Qwen3.5 support depends on the llama.cpp revision bundled by the resolved
llamaDart version and a compatible model/projector pair.

## Build and checks

Requirements from the llamaDart installation guide are Flutter 3.38.6+, Dart
3.10.7+, and iOS 16.4+. The CI workflow runs formatting, static analysis,
tests, an Android debug build, an Android arm64 release build, and an unsigned
iOS Simulator build.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
flutter build ios --no-codesign
```

Model weights, API keys, and personal data must not be committed.

## Known limitations

- The generated Android release artifact targets arm64 Android devices. The
  debug artifact is for development and is larger.
- The iOS CI artifact is an unsigned Simulator app, not an installable iPhone
  IPA. A real-device IPA requires an Apple signing certificate, provisioning
  profile, and a configured bundle identifier/team.
- The named Qwen3.5 model/projector pair has not yet been qualified on a
  physical phone. Successful loading, image understanding, memory use, and
  performance still need a real-device test on the target Xiaomi 11T Pro.
- App persistence uses local preferences; image paths refer to picker-managed
  files and can become unavailable if the OS clears temporary storage.
- The UI does not expose a selectable GPU backend. llamaDart's automatic
  backend selection remains in effect and is runtime/device specific.
