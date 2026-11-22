import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.fileName,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final String fileName;
  final int receivedBytes;
  final int totalBytes;

  double get fraction =>
      totalBytes == 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1);
}

class ModelFiles {
  const ModelFiles({required this.modelPath, required this.projectorPath});

  final String modelPath;
  final String projectorPath;
}

class ModelDownloadPaused implements Exception {
  const ModelDownloadPaused();

  @override
  String toString() => 'Download paused. Run it again to resume.';
}

/// Downloads the public Qwen3.5 GGUF pair into app-private storage.
/// Partial files are retained and resumed with HTTP Range requests.
class ModelDownloadService {
  static const int modelBytes = 2783446368;
  static const int projectorBytes = 672422944;
  static const int totalBytes = modelBytes + projectorBytes;

  static const String _repo =
      'https://huggingface.co/gguf/Qwen3.5-4B-GGUF/resolve/main';
  static const String modelFile = 'qwen3.5-4b-Q4_K_M.gguf';
  static const String projectorFile = 'mmproj-qwen3.5-4b-F16.gguf';

  HttpClient? _client;
  bool _cancelRequested = false;

  Future<Directory> _modelDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      '\${root.path}\${Platform.pathSeparator}models',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<ModelFiles?> localFiles() async {
    final directory = await _modelDirectory();
    final model = File('\${directory.path}\${Platform.pathSeparator}$modelFile');
    final projector = File(
      '\${directory.path}\${Platform.pathSeparator}$projectorFile',
    );
    if (await model.exists() &&
        await projector.exists() &&
        await model.length() == modelBytes &&
        await projector.length() == projectorBytes) {
      return ModelFiles(modelPath: model.path, projectorPath: projector.path);
    }
    return null;
  }

  Future<ModelFiles> downloadAll({
    required void Function(ModelDownloadProgress progress) onProgress,
  }) async {
    _cancelRequested = false;
    final directory = await _modelDirectory();
    var completed = 0;

    final model = File('\${directory.path}\${Platform.pathSeparator}$modelFile');
    final projector = File(
      '\${directory.path}\${Platform.pathSeparator}$projectorFile',
    );

    if (await model.exists() && await model.length() == modelBytes) {
      completed += modelBytes;
    } else {
      await _downloadOne(
        fileName: modelFile,
        expectedBytes: modelBytes,
        target: model,
        completedBefore: completed,
        onProgress: onProgress,
      );
      completed += modelBytes;
    }

    if (_cancelRequested) throw const ModelDownloadPaused();

    if (await projector.exists() &&
        await projector.length() == projectorBytes) {
      completed += projectorBytes;
    } else {
      await _downloadOne(
        fileName: projectorFile,
        expectedBytes: projectorBytes,
        target: projector,
        completedBefore: completed,
        onProgress: onProgress,
      );
      completed += projectorBytes;
    }

    onProgress(
      ModelDownloadProgress(
        fileName: 'Complete',
        receivedBytes: totalBytes,
        totalBytes: totalBytes,
      ),
    );
    return ModelFiles(modelPath: model.path, projectorPath: projector.path);
  }

  Future<void> _downloadOne({
    required String fileName,
    required int expectedBytes,
    required File target,
    required int completedBefore,
    required void Function(ModelDownloadProgress progress) onProgress,
  }) async {
    if (await target.exists() && await target.length() != expectedBytes) {
      await target.delete();
    }
    final partial = File('\${target.path}.part');
    if (await partial.exists() && await partial.length() > expectedBytes) {
      await partial.delete();
    }

    var offset = await partial.exists() ? await partial.length() : 0;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 35)
      ..idleTimeout = const Duration(seconds: 90);
    _client = client;

    try {
      final request = await client.getUrl(Uri.parse('$_repo/$fileName'));
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }

      final response = await request.close();
      if (response.statusCode == HttpStatus.ok && offset > 0) {
        offset = 0;
      } else if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException(
          'HTTP \${response.statusCode} while downloading $fileName',
          uri: request.uri,
        );
      }

      final output = await partial.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      try {
        var received = offset;
        onProgress(
          ModelDownloadProgress(
            fileName: fileName,
            receivedBytes: completedBefore + received,
            totalBytes: totalBytes,
          ),
        );
        await for (final chunk in response) {
          if (_cancelRequested) throw const ModelDownloadPaused();
          await output.writeFrom(chunk);
          received += chunk.length;
          onProgress(
            ModelDownloadProgress(
              fileName: fileName,
              receivedBytes: completedBefore + received,
              totalBytes: totalBytes,
            ),
          );
          if (received > expectedBytes) {
            throw const FormatException(
              'Downloaded file is larger than expected.',
            );
          }
        }
        await output.flush();
        if (_cancelRequested) throw const ModelDownloadPaused();
        if (received != expectedBytes) {
          throw HttpException(
            'Incomplete $fileName: $received of $expectedBytes bytes. Retry to resume.',
          );
        }
      } finally {
        await output.close();
      }

      await partial.rename(target.path);
      // The source Hub does not publish a trusted SHA-256 manifest for these
      // quantized artifacts; this sidecar records a local audit fingerprint.
      final digest = await sha256.bind(target.openRead()).first;
      await File('\${target.path}.sha256').writeAsString('$digest  $fileName\n');
    } catch (error) {
      if (_cancelRequested) throw const ModelDownloadPaused();
      rethrow;
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  void cancel() {
    _cancelRequested = true;
    _client?.close(force: true);
  }
}
