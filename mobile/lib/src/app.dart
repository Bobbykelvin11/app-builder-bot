import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'local/local_generator.dart';
import 'local/model_catalog.dart';
import 'local/model_manager.dart';
import 'models.dart';
import 'screens/build_screen.dart';
import 'screens/history_screen.dart';
import 'screens/models_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/templates_screen.dart';
import 'storage.dart';

/// Tab indexes in [HomeShell].
class Tabs {
  static const build = 0;
  static const templates = 1;
  static const history = 2;
  static const model = 3;
  static const settings = 4;
}

/// App-wide state: settings, history, on-device models and generators.
class AppState extends ChangeNotifier {
  AppState(this.store, this.models)
    : history = store.loadHistory(),
      themeMode = _parseTheme(store.themeMode) {
    models.addListener(notifyListeners);
  }

  final Store store;
  final ModelManager models;
  final GeneratorApi api = GeneratorApi();
  final LocalGenerator local = LocalGenerator();
  List<Generation> history;
  ThemeMode themeMode;

  /// On-device generation is the default; the Vercel server is optional.
  bool get useDevice => store.engineMode != 'server';

  Future<void> setUseDevice(bool device) async {
    await store.setEngineMode(device ? 'device' : 'server');
    notifyListeners();
  }

  LocalModelInfo get selectedModel =>
      modelById(store.localModelId) ?? modelById(kDefaultLocalModelId)!;

  Future<void> selectModel(LocalModelInfo m) async {
    await store.setLocalModelId(m.id);
    notifyListeners();
  }

  Future<void> addToHistory(Generation g) async {
    history = [g, ...history.where((h) => h.id != g.id)];
    await store.saveHistory(history);
    notifyListeners();
  }

  Future<void> removeFromHistory(String id) async {
    history = history.where((h) => h.id != id).toList();
    await store.saveHistory(history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history = [];
    await store.saveHistory(history);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await store.setThemeMode(mode.name);
    notifyListeners();
  }

  void settingsChanged() => notifyListeners();

  @override
  void dispose() {
    models.removeListener(notifyListeners);
    local.unload();
    super.dispose();
  }

  static ThemeMode _parseTheme(String s) => ThemeMode.values.firstWhere(
    (m) => m.name == s,
    orElse: () => ThemeMode.system,
  );
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;

  /// Reads the state without subscribing (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}

class AppBuilderApp extends StatefulWidget {
  const AppBuilderApp({super.key, required this.store, required this.models});
  final Store store;
  final ModelManager models;

  @override
  State<AppBuilderApp> createState() => _AppBuilderAppState();
}

class _AppBuilderAppState extends State<AppBuilderApp> {
  late final AppState _state = AppState(widget.store, widget.models);

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness b) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: b,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) => AppStateScope(
    state: _state,
    child: ListenableBuilder(
      listenable: _state,
      builder: (context, _) => MaterialApp(
        title: 'App Builder',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: _state.themeMode,
        home: const HomeShell(),
      ),
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = Tabs.build;

  void _open(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      BuildScreen(onOpenTab: _open),
      const TemplatesScreen(),
      const HistoryScreen(),
      const ModelsScreen(),
      SettingsScreen(onOpenTab: _open),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _open,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Build',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Templates',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: 'Model',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
