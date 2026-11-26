import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../templates.dart';
import 'result_screen.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ready-made Flutter apps. They work offline with no model and no server, '
            'and every template has been checked to compile.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final t in kTemplates)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(t.icon)),
                title: Text(t.name),
                subtitle: Text(t.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResultScreen(
                      generation: Generation(
                        id: 'template-${t.id}',
                        prompt: 'Template: ${t.name}',
                        code: t.code,
                        file: 'lib/main.dart',
                        createdAt: DateTime.now(),
                        source: 'template',
                      ),
                      isTemplate: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
