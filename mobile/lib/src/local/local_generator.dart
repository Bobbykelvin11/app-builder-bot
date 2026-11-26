import 'dart:async';

import 'package:llamadart/llamadart.dart';

import '../prompting.dart';
import 'model_catalog.dart';

/// Runs an open-source GGUF model on the device with llama.cpp (via llamadart).
class LocalGenerator {
  LlamaEngine? _engine;
  String? _loadedPath;
  Future<void>? _loading;
  bool _busy = false;

  bool get isBusy => _busy;
  bool isLoaded(String path) => _engine != null && _loadedPath == path;

  Future<void> _ensureLoaded(String path) async {
    if (isLoaded(path)) return;
    if (_loading != null) await _loading;
    if (isLoaded(path)) return;
    final completer = Completer<void>();
    _loading = completer.future;
    try {
      await unload();
      _engine = await LlamaEngine.load(
        LlamaModel(ModelSource.path(path)),
        params: const ModelParams(contextSize: 4096),
      );
      _loadedPath = path;
      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _loading = null;
    }
  }

  /// Streams raw text deltas. Call [stop] to end early.
  Stream<String> generate({
    required LocalModelInfo model,
    required String modelPath,
    required String prompt,
    int maxTokens = 2048,
  }) async* {
    if (_busy) throw StateError('A generation is already running.');
    _busy = true;
    try {
      await _ensureLoaded(modelPath);
      final engine = _engine!;
      final messages = [
        const LlamaChatMessage.fromText(
          role: LlamaChatRole.system,
          text: kSystemPrompt,
        ),
        LlamaChatMessage.fromText(role: LlamaChatRole.user, text: prompt),
      ];
      await for (final chunk in engine.create(
        messages,
        params: GenerationParams(maxTokens: maxTokens, temp: 0.2, topP: 0.9),
        enableThinking: false,
      )) {
        final t = chunk.text;
        if (t.isNotEmpty) yield t;
      }
    } finally {
      _busy = false;
    }
  }

  void stop() {
    try {
      _engine?.cancelGeneration();
    } catch (_) {}
  }

  Future<void> unload() async {
    final e = _engine;
    _engine = null;
    _loadedPath = null;
    if (e != null) await e.dispose();
  }
}
