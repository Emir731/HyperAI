# Hyper AI

Hyper AI is an offline-first Flutter assistant for study and image understanding. It runs a local GGUF model on the device; prompts and selected images are not sent to a cloud AI service by this app.

## Current implementation

- Responsive chat interface with a compact conversation sidebar.
- Local GGUF model selection and load/unload controls.
- Optional multimodal projector selection for vision-capable GGUF models.
- Streaming multi-turn chat using `llamadart`.
- Image selection from the device gallery and image prompts.
- Dark, low-distraction interface with one green accent and consistent rounded corners.
- Android and iOS Flutter project targets.

## Model setup

The app does not bundle model weights. Keep model files outside Git and select them from local device storage.

For the Qwen3.5 4B setup, choose these two files in **Settings → Model settings**:

1. Main model: `Qwen3.5-4B-Q4_K_M.gguf`
2. Vision projector: `mmproj-qwen3.5-4b-f16.gguf`

The main model and its projector must be a compatible pair. The model must be copied to the phone before loading it. On Android, use the file picker to select each file.

## Development requirements

- Flutter 3.38.6 or newer
- Dart 3.10.7 or newer
- iOS deployment target 16.4 or newer for the current `llamadart` Flutter runtime
- Android device with sufficient free RAM and storage for the selected model

Install dependencies and run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Build an Android APK:

```bash
flutter build apk --release
```

## Important notes

- Model loading and generation performance depend on the device, available memory, model quantization and native backend support.
- A 4B multimodal model can require substantial memory. Close other apps if the device reports memory pressure.
- The repository currently includes the first local-inference integration pass. It still needs validation on a physical Android device with the exact Qwen3.5 files, plus automated tests and further work on persistent chat history, message actions, user-facing generation settings and language selection.
- No model files, API keys or personal data should be committed to this repository.

## Privacy

Inference is designed to run locally. Network access may still be used by the operating system or package/build tooling during installation and updates; the chat-generation code does not call a hosted AI endpoint.
