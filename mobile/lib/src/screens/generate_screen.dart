import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../local/model_catalog.dart';
import '../models.dart';
import '../prompting.dart';
import 'build_screen.dart';
import 'result_screen.dart';

/// Streams code from the on-device model, with a Stop button.
class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key, required this.prompt, required this.model});
  final String prompt;
  final LocalModelInfo model;

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  final _buffer = StringBuffer();
  final _scroll = ScrollController();
  StreamSubscription<String>? _sub;
  bool _loading = true;
  bool _done = false;
  bool _stopped = false;
  String? _error;
  int _chunks = 0;
  final _watch = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    final state = AppStateScope.read(context);
    final path = state.models.pathFor(widget.model);
    _watch.start();
    _sub = state.local
        .generate(model: widget.model, modelPath: path, prompt: widget.prompt)
        .listen(
          (delta) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _buffer.write(delta);
              _chunks++;
            });
            if (_scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = _friendly(e);
            });
          },
          onDone: _finish,
        );
  }

  String _friendly(Object e) {
    final s = '$e';
    if (s.contains('memory') || s.contains('alloc')) {
      return 'The phone ran out of memory loading the model. Try the smaller 0.5B model on the Model tab.';
    }
    return 'On-device generation failed: $s';
  }

  Future<void> _finish() async {
    _watch.stop();
    if (!mounted || _error != null) return;
    final raw = _buffer.toString();
    if (raw.trim().isEmpty) {
      setState(
        () => _error = _stopped
            ? 'Stopped before any code was written.'
            : 'The model returned nothing. Try again or rephrase.',
      );
      return;
    }
    setState(() => _done = true);
    final g = Generation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      prompt: widget.prompt,
      code: stripCodeFences(raw),
      file: 'lib/main.dart',
      createdAt: DateTime.now(),
      model: widget.model.name,
      source: 'device',
      stopped: _stopped,
    );
    final state = AppStateScope.read(context);
    await state.addToHistory(g);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(generation: g)),
    );
  }

  void _stop() {
    setState(() => _stopped = true);
    AppStateScope.read(context).local.stop();
  }

  @override
  void dispose() {
    if (!_done && _error == null) {
      AppStateScope.read(context).local.stop();
    }
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secs = _watch.elapsed.inSeconds;
    final running = _error == null && !_done;
    return Scaffold(
      appBar: AppBar(title: const Text('Writing code on your phone')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (running) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                _loading
                    ? 'Loading ${widget.model.name}… the first run can take up to a minute.'
                    : '${widget.model.name} • ${_buffer.length} characters • ${secs}s'
                          '${_chunks > 0 && secs > 0 ? ' • ${(_chunks / secs).toStringAsFixed(1)} chunks/s' : ''}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
            if (_error != null)
              Card(
                margin: const EdgeInsets.all(12),
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _buffer.isEmpty ? '…' : _buffer.toString(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const [
                        'Menlo',
                        'Courier',
                        'RobotoMono',
                      ],
                      fontSize: 12.5,
                      height: 1.45,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: running
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _stopped ? null : _stop,
                      icon: const Icon(Icons.stop),
                      label: Text(_stopped ? 'Stopping…' : 'Stop'),
                    )
                  : OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Back'),
                    ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: DisclaimerCard(),
            ),
          ],
        ),
      ),
    );
  }
}
