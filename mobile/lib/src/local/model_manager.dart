import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';

enum ModelState { notDownloaded, partial, downloading, ready }

class ModelStatus {
  const ModelStatus(this.state, {this.downloaded = 0, this.error});
  final ModelState state;
  final int downloaded;
  final String? error;
}

/// Downloads, resumes, cancels and deletes GGUF models in the app's documents folder.
class ModelManager extends ChangeNotifier {
  ModelManager._(this._dir);

  final Directory _dir;
  final Map<String, ModelStatus> _status = {};
  final Map<String, _ActiveDownload> _active = {};

  static Future<ModelManager> open() async {
    final docs = await getApplicationDocumentsDirectory();
    return openAt(Directory('${docs.path}/models'));
  }

  /// Opens a manager that stores models in [dir] (used by tests too).
  static Future<ModelManager> openAt(Directory dir) async {
    await dir.create(recursive: true);
    final m = ModelManager._(dir);
    await m.refresh();
    return m;
  }

  String pathFor(LocalModelInfo m) => '${_dir.path}/${m.fileName}';
  String _partPath(LocalModelInfo m) => '${pathFor(m)}.part';

  ModelStatus statusOf(LocalModelInfo m) =>
      _status[m.id] ?? const ModelStatus(ModelState.notDownloaded);
  bool isReady(LocalModelInfo m) => statusOf(m).state == ModelState.ready;
  double progressOf(LocalModelInfo m) =>
      (statusOf(m).downloaded / m.sizeBytes).clamp(0.0, 1.0);

  Future<void> refresh() async {
    for (final m in kLocalModels) {
      if (_active.containsKey(m.id)) continue;
      final f = File(pathFor(m));
      final part = File(_partPath(m));
      if (await f.exists() && await f.length() == m.sizeBytes) {
        _status[m.id] = ModelStatus(ModelState.ready, downloaded: m.sizeBytes);
      } else if (await part.exists()) {
        _status[m.id] = ModelStatus(
          ModelState.partial,
          downloaded: await part.length(),
        );
      } else {
        _status[m.id] = const ModelStatus(ModelState.notDownloaded);
      }
    }
    notifyListeners();
  }

  /// Starts or resumes a download. Completes when finished, paused or failed.
  Future<void> download(LocalModelInfo m) async {
    if (_active.containsKey(m.id) || isReady(m)) return;
    final job = _ActiveDownload();
    _active[m.id] = job;
    final part = File(_partPath(m));
    var have = await part.exists() ? await part.length() : 0;
    if (have > m.sizeBytes) {
      await part.delete();
      have = 0;
    }
    _set(m, ModelStatus(ModelState.downloading, downloaded: have));

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    job.client = client;
    IOSink? sink;
    try {
      final res = await _get(client, Uri.parse(m.url), have);
      if (res.statusCode == 200) {
        have = 0; // Server ignored Range: start over.
      } else if (res.statusCode == 416) {
        await res.drain<void>();
        have = await part.length();
      } else if (res.statusCode != 206) {
        await res.drain<void>();
        throw HttpException('Download failed (HTTP ${res.statusCode}).');
      }
      if (res.statusCode != 416) {
        sink = part.openWrite(
          mode: have == 0 ? FileMode.write : FileMode.append,
        );
        var lastNotify = DateTime.now();
        await for (final chunk in res) {
          if (job.cancelled) break;
          sink.add(chunk);
          have += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds > 250) {
            lastNotify = now;
            _set(m, ModelStatus(ModelState.downloading, downloaded: have));
          }
        }
        await sink.flush();
        await sink.close();
        sink = null;
      }
      if (job.cancelled) {
        if (job.discard && await part.exists()) await part.delete();
        return;
      }
      final size = await part.length();
      if (size != m.sizeBytes) {
        throw HttpException(
          'Download incomplete ($size of ${m.sizeBytes} bytes). Tap Resume to continue.',
        );
      }
      await part.rename(pathFor(m));
      _set(m, ModelStatus(ModelState.ready, downloaded: m.sizeBytes));
    } on SocketException {
      _set(
        m,
        ModelStatus(
          ModelState.partial,
          downloaded: have,
          error: 'Network lost. Tap Resume to continue.',
        ),
      );
    } on FileSystemException catch (e) {
      _set(
        m,
        ModelStatus(
          ModelState.partial,
          downloaded: have,
          error:
              'Storage error: ${e.osError?.message ?? e.message}. Free up space and resume.',
        ),
      );
    } catch (e) {
      if (!job.cancelled) {
        _set(
          m,
          ModelStatus(
            ModelState.partial,
            downloaded: have,
            error: e is HttpException ? e.message : '$e',
          ),
        );
      }
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      client.close(force: true);
      _active.remove(m.id);
      await refresh();
      if (statusOf(m).state != ModelState.ready && _lastError[m.id] != null) {
        _status[m.id] = ModelStatus(
          statusOf(m).state,
          downloaded: statusOf(m).downloaded,
          error: _lastError[m.id],
        );
        notifyListeners();
      }
      _lastError.remove(m.id);
    }
  }

  final Map<String, String?> _lastError = {};

  Future<HttpClientResponse> _get(HttpClient client, Uri uri, int from) async {
    var current = uri;
    for (var i = 0; i < 6; i++) {
      final req = await client.getUrl(current);
      req.followRedirects = false;
      if (from > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
      final res = await req.close();
      if (res.isRedirect || (res.statusCode >= 300 && res.statusCode < 400)) {
        final loc = res.headers.value(HttpHeaders.locationHeader);
        await res.drain<void>();
        if (loc == null) {
          throw const HttpException('Redirect without a location.');
        }
        current = current.resolve(loc);
        continue;
      }
      return res;
    }
    throw const HttpException('Too many redirects.');
  }

  /// Pauses (keeps the partial file so it can resume) or cancels (deletes it).
  Future<void> stop(LocalModelInfo m, {bool discard = false}) async {
    final job = _active[m.id];
    if (job != null) {
      job.cancelled = true;
      job.discard = discard;
      job.client?.close(force: true);
    } else if (discard) {
      final part = File(_partPath(m));
      if (await part.exists()) await part.delete();
      await refresh();
    }
  }

  Future<void> delete(LocalModelInfo m) async {
    await stop(m, discard: true);
    for (final p in [pathFor(m), _partPath(m)]) {
      final f = File(p);
      if (await f.exists()) await f.delete();
    }
    await refresh();
  }

  void _set(LocalModelInfo m, ModelStatus s) {
    _status[m.id] = s;
    if (s.error != null) _lastError[m.id] = s.error;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final j in _active.values) {
      j.cancelled = true;
      j.client?.close(force: true);
    }
    super.dispose();
  }
}

class _ActiveDownload {
  bool cancelled = false;
  bool discard = false;
  HttpClient? client;
}
