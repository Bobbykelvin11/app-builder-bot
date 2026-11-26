import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app.dart';
import '../config.dart';
import 'result_screen.dart';

class BuildScreen extends StatefulWidget {
  const BuildScreen({super.key});
  @override
  State<BuildScreen> createState() => _BuildScreenState();
}

class _BuildScreenState extends State<BuildScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  String? _error;
  bool _offline = false;
  Timer? _draftTimer;
  bool _loadedDraft = false;

  static const _examples = [
    'A habit tracker with a daily checklist, streaks and a dark theme',
    'A tip calculator that splits the bill between friends',
    'A simple notes app with search and pinned notes',
    'A Pomodoro timer with work and break sessions',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedDraft) {
      _controller.text = AppStateScope.of(context).store.draft;
      _loadedDraft = true;
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_error != null) setState(() => _error = null);
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 400),
      () => AppStateScope.of(context).store.setDraft(value),
    );
    setState(() {});
  }

  String? _validate(String text) {
    if (text.isEmpty) return 'Describe the app you want first.';
    if (text.length < kMinPromptLength) {
      return 'Please write at least $kMinPromptLength characters.';
    }
    if (text.length > kMaxPromptLength) {
      return 'Please keep it under $kMaxPromptLength characters.';
    }
    return null;
  }

  Future<void> _generate() async {
    final text = _controller.text.trim();
    final problem = _validate(text);
    if (problem != null) {
      setState(() => _error = problem);
      _focus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    final state = AppStateScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _offline = false;
    });
    try {
      final result = await state.api.generate(
        prompt: text,
        baseUrl: state.store.effectiveApiUrl,
        appKey: state.store.effectiveAppKey,
      );
      await state.addToHistory(result);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(generation: result),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _offline = e.offline;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Something went wrong: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final length = _controller.text.trim().length;
    final hasKey = AppStateScope.of(context).store.effectiveAppKey.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('App Builder')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Describe the app you want',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'App Builder writes a starter Flutter lib/main.dart for your idea.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (!hasKey)
              Card(
                color: scheme.tertiaryContainer,
                child: ListTile(
                  leading: Icon(Icons.key, color: scheme.onTertiaryContainer),
                  title: Text(
                    'Add your App key in Settings to start generating.',
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ),
            TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: !_loading,
              minLines: 5,
              maxLines: 10,
              maxLength: kMaxPromptLength,
              textInputAction: TextInputAction.newline,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'A habit tracker with reminders and streaks…',
                errorText: _error != null && !_offline ? _error : null,
                errorMaxLines: 4,
                counterText: '$length / $kMaxPromptLength',
                suffixIcon: _controller.text.isEmpty || _loading
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
            if (_offline && _error != null)
              Card(
                color: scheme.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.wifi_off, color: scheme.onErrorContainer),
                  title: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  subtitle: Text(
                    'Your prompt is saved as a draft.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _loading ? 'Generating… (up to a minute)' : 'Generate',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 20),
            Text(
              'Try an example',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _examples)
                  ActionChip(
                    label: Text(e, overflow: TextOverflow.ellipsis),
                    onPressed: _loading
                        ? null
                        : () {
                            _controller.text = e;
                            _onChanged(e);
                          },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const DisclaimerCard(),
          ],
        ),
      ),
    );
  }
}

class DisclaimerCard extends StatelessWidget {
  const DisclaimerCard({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                kDisclaimer,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
