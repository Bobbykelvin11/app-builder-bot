import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'models.dart';
import 'screens/build_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'storage.dart';

/// App-wide state: settings, history and the generator client.
class AppState extends ChangeNotifier {
  AppState(this.store)
    : history = store.loadHistory(),
      themeMode = _parseTheme(store.themeMode);

  final Store store;
  final GeneratorApi api = GeneratorApi();
  List<Generation> history;
  ThemeMode themeMode;

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
}

class AppBuilderApp extends StatefulWidget {
  const AppBuilderApp({super.key, required this.store});
  final Store store;

  @override
  State<AppBuilderApp> createState() => _AppBuilderAppState();
}

class _AppBuilderAppState extends State<AppBuilderApp> {
  late final AppState _state = AppState(widget.store);

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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const BuildScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Build',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
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
