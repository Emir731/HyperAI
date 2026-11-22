# Hyper AI

Hyper AI is a Flutter chat app designed for local GGUF inference. Chat
generation does not call a hosted AI service. Model files are selected from
device storage and are not included in this repository.

## Current functionality

- Select a GGUF model and a separate multimodal projector.
- Load, unload, and replace the local inference engine.
- Stream responses and cancel the active generation.
- Select a gallery image and send its local path with the prompt.
- Keep chat history, model paths, language, and generation settings locally.
- Create chats, rename or delete conversations, and edit, copy, or delete
  messages.
- Use English, Turkish, or Russian labels for the core chat and model flows.
- Configure context length, temperature, output token limit, and CPU threads.

## First-run model setup

On first launch, the welcome screen offers a model download action. It downloads
the Qwen3.5 4B Q4_K_M model and its F16 vision projector from the public
`gguf/Qwen3.5-4B-GGUF` Hugging Face repository into app-private storage.
The combined download is about 3.45 GB. Use Wi-Fi and keep at least 4 GB of
free storage available. The app displays combined progress and keeps partial
`.part` files; pausing or losing the connection preserves partial data so a
later retry can continue with an HTTP Range request.

The downloader checks exact expected file sizes and writes a local SHA-256
fingerprint sidecar after each complete file. The source repository does not
publish a trusted SHA-256 manifest for these quantized artifacts, so this
fingerprint is an audit value, not a comparison against an upstream checksum.
No Hugging Face token is embedded in the app. The source repository must remain
public for first-run downloads to work.

After download, open Model settings and press Load model. Later launches reuse
the files in app-private storage; inference itself works offline. Manual file
selection remains available.

## Model files

For the intended Qwen3.5 4B vision setup, select:

1. `Qwen3.5-4B-Q4_K_M.gguf`
2. `mmproj-qwen3.5-4b-f16.gguf`

The app passes the model and projector as local `ModelSource.path` values to
llamaDart and passes selected images as `LlamaImageContent(path: ...)`. The
llama.cpp runtime used by llamaDart supports GGUF projector inputs. Qwen3.5
support depends on the llama.cpp revision bundled by the resolved
llamaDart version and a compatible model/projector pair. This repository has
not been qualified with the named model files on a physical phone; successful
loading and image understanding are not guaranteed until that device check.

The Android app requests Internet permission for the optional first-run model download. The runtime and
Flutter build tooling may need internet access during installation/build to
download their native artifacts. Once dependencies and model files are local,
inference itself is device-local.

## Build and checks

Requirements from the llamaDart installation guide are Flutter 3.38.6+, Dart
3.10.7+, and iOS 16.4+. This app targets Android and iOS.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build ios --no-codesign
```

Model weights, API keys, and personal data must not be committed.

## Known limitations

- App persistence currently uses local preferences; image paths refer to
  picker-managed files and can become unavailable if the OS clears temporary
  storage.
- The UI does not expose a selectable GPU backend. llamaDart's automatic
  backend selection remains in effect; GPU availability is runtime/device
  specific.
- Exact Qwen3.5 4B model/projector operation, memory use, and performance need
  validation on the target Xiaomi 11T Pro. An 8 GB device may still hit memory
  pressure with a large context or high-resolution image.
- Builds and automated tests must be run after `flutter pub get` succeeds in
  an environment with access to pub.dev and the native artifact hosts.

