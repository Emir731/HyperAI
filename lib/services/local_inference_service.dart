import 'package:llamadart/llamadart.dart';

/// Owns the GGUF engine lifecycle. Model files remain on device.
class LocalInferenceService {
  LlamaEngine? _engine;
  LlamaEngine? get engine => _engine;

  Future<LlamaEngine> load({
    required String modelPath,
    required String projectorPath,
    required int contextLength,
    required int cpuThreads,
  }) async {
    final replacement = await LlamaEngine.load(
      LlamaModel(
        ModelSource.path(modelPath),
        projector: ModelSource.path(projectorPath),
      ),
      params: ModelParams(
        contextSize: contextLength,
        numberOfThreads: cpuThreads,
      ),
    );
    final previous = _engine;
    _engine = replacement;
    await previous?.dispose();
    return replacement;
  }

  Future<void> unload() async {
    final previous = _engine;
    _engine = null;
    await previous?.dispose();
  }

  Stream<dynamic> generate(
    ChatSession session,
    List<LlamaContentPart> parts, {
    required int maxTokens,
    required double temperature,
  }) => session.create(
    parts,
    params: GenerationParams(maxTokens: maxTokens, temp: temperature),
  );
}

