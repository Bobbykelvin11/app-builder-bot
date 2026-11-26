// Ready-made, compile-checked Flutter apps that work with no model and no network.
import 'package:material_ui/material_ui.dart';

class AppTemplate {
  const AppTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.code,
  });
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String code;
}

const List<AppTemplate> kTemplates = [
  AppTemplate(
    id: 'todo',
    name: 'Todo list',
    description: 'Add, check off and swipe away tasks.',
    icon: Icons.checklist,
    code: _todo,
  ),
  AppTemplate(
    id: 'habits',
    name: 'Habit tracker',
    description: 'Daily checklist with streaks and progress.',
    icon: Icons.local_fire_department,
    code: _habits,
  ),
  AppTemplate(
    id: 'tip',
    name: 'Tip calculator',
    description: 'Split the bill with a tip slider.',
    icon: Icons.calculate,
    code: _tip,
  ),
  AppTemplate(
    id: 'pomodoro',
    name: 'Pomodoro timer',
    description: '25/5 focus timer with session count.',
    icon: Icons.timer,
    code: _pomodoro,
  ),
  AppTemplate(
    id: 'notes',
    name: 'Notes',
    description: 'Notes with search, pinning and an editor.',
    icon: Icons.sticky_note_2,
    code: _notes,
  ),
];

const String _todo = r'''import 'package:flutter/material.dart';

void main() => runApp(const TodoApp());

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
      home: const TodoPage(),
    );
  }
}

class Todo {
  Todo(this.title);
  final String title;
  bool done = false;
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final List<Todo> _todos = [];
  final TextEditingController _controller = TextEditingController();

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _todos.insert(0, Todo(text)));
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _todos.where((t) => !t.done).length;
    return Scaffold(
      appBar: AppBar(title: Text('Todo ($remaining left)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Add a task', border: OutlineInputBorder()),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
          ),
          Expanded(
            child: _todos.isEmpty
                ? const Center(child: Text('Nothing to do yet'))
                : ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (context, i) {
                      final todo = _todos[i];
                      return Dismissible(
                        key: ObjectKey(todo),
                        onDismissed: (_) => setState(() => _todos.removeAt(i)),
                        background: Container(color: Colors.red.withValues(alpha: 0.3)),
                        child: CheckboxListTile(
                          value: todo.done,
                          title: Text(
                            todo.title,
                            style: TextStyle(decoration: todo.done ? TextDecoration.lineThrough : null),
                          ),
                          onChanged: (v) => setState(() => todo.done = v ?? false),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
''';

const String _habits = r'''import 'package:flutter/material.dart';

void main() => runApp(const HabitApp());

class HabitApp extends StatelessWidget {
  const HabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habits',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      home: const HabitPage(),
    );
  }
}

class Habit {
  Habit(this.name);
  final String name;
  final Set<DateTime> doneDays = {};

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get doneToday => doneDays.contains(today());

  int get streak {
    var day = today();
    var count = 0;
    while (doneDays.contains(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }
}

class HabitPage extends StatefulWidget {
  const HabitPage({super.key});

  @override
  State<HabitPage> createState() => _HabitPageState();
}

class _HabitPageState extends State<HabitPage> {
  final List<Habit> _habits = [Habit('Drink water'), Habit('Read 10 pages'), Habit('Walk 20 minutes')];

  Future<void> _addHabit() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New habit'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) setState(() => _habits.add(Habit(name)));
  }

  @override
  Widget build(BuildContext context) {
    final done = _habits.where((h) => h.doneToday).length;
    return Scaffold(
      appBar: AppBar(title: Text('Today: $done / ${_habits.length}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHabit,
        icon: const Icon(Icons.add),
        label: const Text('Habit'),
      ),
      body: ListView(
        children: [
          LinearProgressIndicator(value: _habits.isEmpty ? 0 : done / _habits.length),
          for (final h in _habits)
            CheckboxListTile(
              title: Text(h.name),
              subtitle: Text('Streak: ${h.streak} day${h.streak == 1 ? '' : 's'}'),
              value: h.doneToday,
              onChanged: (v) => setState(() {
                if (v == true) {
                  h.doneDays.add(Habit.today());
                } else {
                  h.doneDays.remove(Habit.today());
                }
              }),
            ),
        ],
      ),
    );
  }
}
''';

const String _tip = r'''import 'package:flutter/material.dart';

void main() => runApp(const TipApp());

class TipApp extends StatelessWidget {
  const TipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tip Calculator',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green, brightness: Brightness.dark),
      home: const TipPage(),
    );
  }
}

class TipPage extends StatefulWidget {
  const TipPage({super.key});

  @override
  State<TipPage> createState() => _TipPageState();
}

class _TipPageState extends State<TipPage> {
  double _bill = 0;
  double _tipPercent = 15;
  int _people = 1;

  @override
  Widget build(BuildContext context) {
    final tip = _bill * _tipPercent / 100;
    final total = _bill + tip;
    final each = total / _people;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tip Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Bill amount', prefixText: '\$ ', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _bill = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 24),
          Text('Tip: ${_tipPercent.round()}%', style: text.titleMedium),
          Slider(
            value: _tipPercent,
            min: 0,
            max: 30,
            divisions: 30,
            label: '${_tipPercent.round()}%',
            onChanged: (v) => setState(() => _tipPercent = v),
          ),
          Row(
            children: [
              Text('People', style: text.titleMedium),
              const Spacer(),
              IconButton.outlined(
                onPressed: _people > 1 ? () => setState(() => _people--) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$_people', style: text.titleLarge)),
              IconButton.outlined(onPressed: () => setState(() => _people++), icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tip: \$${tip.toStringAsFixed(2)}', style: text.titleMedium),
                  Text('Total: \$${total.toStringAsFixed(2)}', style: text.titleMedium),
                  const Divider(),
                  Text('Each person pays \$${each.toStringAsFixed(2)}', style: text.headlineSmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
''';

const String _pomodoro = r'''import 'dart:async';

import 'package:flutter/material.dart';

void main() => runApp(const PomodoroApp());

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomodoro',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange, brightness: Brightness.dark),
      home: const TimerPage(),
    );
  }
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  static const int workSeconds = 25 * 60;
  static const int breakSeconds = 5 * 60;

  int _remaining = workSeconds;
  bool _isWork = true;
  int _completed = 0;
  Timer? _timer;

  bool get _running => _timer != null;

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _timer = null);
      return;
    }
    setState(() {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    });
  }

  void _tick() {
    setState(() {
      if (_remaining > 0) {
        _remaining--;
        return;
      }
      if (_isWork) _completed++;
      _isWork = !_isWork;
      _remaining = _isWork ? workSeconds : breakSeconds;
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _isWork = true;
      _remaining = workSeconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _isWork ? workSeconds : breakSeconds;
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('Pomodoro')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_isWork ? 'Focus' : 'Break', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(value: 1 - _remaining / total, strokeWidth: 10),
                  Center(child: Text('$minutes:$seconds', style: Theme.of(context).textTheme.displayMedium)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Sessions completed: $_completed'),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pause' : 'Start'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh), label: const Text('Reset')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
''';

const String _notes = r'''import 'package:flutter/material.dart';

void main() => runApp(const NotesApp());

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.amber),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.amber, brightness: Brightness.dark),
      home: const NotesPage(),
    );
  }
}

class Note {
  Note({required this.title, required this.body, this.pinned = false});
  String title;
  String body;
  bool pinned;
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final List<Note> _notes = [];
  String _query = '';

  Future<void> _edit([Note? note]) async {
    final result = await Navigator.of(context).push<Note>(
      MaterialPageRoute(builder: (_) => EditNotePage(note: note)),
    );
    if (result == null) return;
    setState(() {
      if (note == null) _notes.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _notes
        .where((n) => n.title.toLowerCase().contains(_query) || n.body.toLowerCase().contains(_query))
        .toList()
      ..sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              hintText: 'Search notes',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('No notes'))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final n = visible[i];
                      return ListTile(
                        title: Text(n.title.isEmpty ? 'Untitled' : n.title),
                        subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _edit(n),
                        trailing: IconButton(
                          icon: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                          onPressed: () => setState(() => n.pinned = !n.pinned),
                        ),
                        onLongPress: () => setState(() => _notes.remove(n)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class EditNotePage extends StatefulWidget {
  const EditNotePage({super.key, this.note});
  final Note? note;

  @override
  State<EditNotePage> createState() => _EditNotePageState();
}

class _EditNotePageState extends State<EditNotePage> {
  late final TextEditingController _title = TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _body = TextEditingController(text: widget.note?.body ?? '');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    final note = widget.note ?? Note(title: '', body: '');
    note.title = _title.text.trim();
    note.body = _body.text.trim();
    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New note' : 'Edit note'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.check))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(hintText: 'Title')),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(hintText: 'Write something…', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
''';
