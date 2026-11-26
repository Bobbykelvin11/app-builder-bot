import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onOpenTab});
  final ValueChanged<int> onOpenTab;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _showKey = false;
  bool _loaded = false;
  String? _urlError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      final store = AppStateScope.of(context).store;
      _url.text = store.apiUrlOverride ?? '';
      _key.text = store.appKeyOverride ?? '';
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !(uri.scheme == 'https' || uri.scheme == 'http') ||
          uri.host.isEmpty) {
        setState(
          () => _urlError = 'Enter a full URL like https://my-app.vercel.app',
        );
        return;
      }
    }
    setState(() => _urlError = null);
    final state = AppStateScope.of(context);
    await state.store.setApiUrlOverride(url);
    await state.store.setAppKeyOverride(_key.text);
    state.settingsChanged();
    if (mounted) {
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  Future<void> _reset() async {
    _url.clear();
    _key.clear();
    await _save();
  }

  Future<void> _clearHistory() async {
    final state = AppStateScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear all history?'),
        content: Text(
          'This deletes ${state.history.length} saved results from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) await state.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final keySource = state.store.appKeyOverride != null
        ? 'Using the key you entered'
        : (kDefaultAppKey.isNotEmpty
              ? 'Using the built-in key'
              : 'No key set yet');
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Generation engine',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('On this phone'),
                icon: Icon(Icons.offline_bolt),
              ),
              ButtonSegment(
                value: false,
                label: Text('Server'),
                icon: Icon(Icons.cloud_outlined),
              ),
            ],
            selected: {state.useDevice},
            onSelectionChanged: (s) => state.setUseDevice(s.first),
          ),
          const SizedBox(height: 6),
          Text(
            state.useDevice
                ? 'Uses the open-source model on your phone. Works offline, no API key.'
                : 'Uses the App Builder server. Needs internet and an App key.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.memory),
            title: const Text('On-device model'),
            subtitle: Text(state.selectedModel.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onOpenTab(Tabs.model),
          ),
          const Divider(height: 32),
          Text(
            'Server (optional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Server URL (optional override)',
              hintText: kDefaultApiBaseUrl,
              helperText: 'Leave empty to use the default: $kDefaultApiBaseUrl',
              helperMaxLines: 2,
              errorText: _urlError,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _key,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'App key',
              helperText: keySource,
              suffixIcon: IconButton(
                tooltip: _showKey ? 'Hide' : 'Show',
                icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Reset to defaults'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {state.themeMode},
            onSelectionChanged: (s) => state.setThemeMode(s.first),
          ),
          const SizedBox(height: 28),
          Text('Data', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Clear history'),
            subtitle: Text('${state.history.length} saved on this device'),
            onTap: state.history.isEmpty ? null : _clearHistory,
          ),
          const Divider(height: 32),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'App Builder 2.1.0',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            kDisclaimer,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
