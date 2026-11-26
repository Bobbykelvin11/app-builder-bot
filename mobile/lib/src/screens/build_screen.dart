import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app.dart';
import '../config.dart';
import '../local/model_manager.dart';
import 'generate_screen.dart';
import 'result_screen.dart';

class BuildScreen extends StatefulWidget {
  const BuildScreen({super.key, required this.onOpenTab});
  final ValueChanged<int> onOpenTab;

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
      _controller.text = AppStateScope.read(context).store.draft;
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
      () => AppStateScope.read(context).store.setDraft(value),
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
    final state = AppStateScope.read(context);

    if (state.useDevice) {
      final model = state.selectedModel;
      if (!state.models.isReady(model)) {
        setState(
          () => _error = 'Download the on-device model first (Model tab), or use a template.',
        );
        return;
      }
      if (state.local.isBusy) {
        setState(
          () => _error =
              'A generation is still running. Wait for it or stop it first.',
        );
        return;
      }
      setState(() => _error = null);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GenerateScreen(prompt: text, model: model),
        ),
      );
      return;
    }

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

  Widget _engineCard(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (!state.useDevice) {
      final hasKey = state.store.effectiveAppKey.isNotEmpty;
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Using the server'),
          subtitle: Text(
            hasKey
                ? 'Needs internet.'
                : 'Add your App key in Settings to use the server.',
          ),
          trailing: TextButton(
            onPressed: () => state.setUseDevice(true),
            child: const Text('Use phone'),
          ),
        ),
      );
    }
    final model = state.selectedModel;
    final status = state.models.statusOf(model);
    final ready = status.state == ModelState.ready;
    final downloading = status.state == ModelState.downloading;
    return Card(
      color: ready ? null : scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(
          ready ? Icons.offline_bolt : Icons.download_for_offline,
          color: ready ? scheme.primary : scheme.onTertiaryContainer,
        ),
        title: Text(
          ready ? 'On-device: ${model.name}' : 'On-device model not downloaded',
        ),
        subtitle: Text(
          ready
              ? 'Works offline. No server or API key.'
              : downloading
              ? 'Downloading… ${(state.models.progressOf(model) * 100).toStringAsFixed(0)}%'
              : 'Download ${model.sizeLabel} once, or start from a template.',
        ),
        trailing: ready ? null : const Icon(Icons.chevron_right),
        onTap: ready ? null : () => widget.onOpenTab(Tabs.model),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final length = _controller.text.trim().length;
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
            const SizedBox(height: 8),
            _engineCard(context),
            const SizedBox(height: 8),
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
                    'Switch to the on-device model to work offline.',
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => widget.onOpenTab(Tabs.templates),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Browse ready-made templates (offline)'),
            ),
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
