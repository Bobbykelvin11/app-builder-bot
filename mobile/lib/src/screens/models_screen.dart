import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../local/model_catalog.dart';
import '../local/model_manager.dart';

class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('On-device model')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Download an open-source coding model once. After that, App Builder writes code '
            'entirely on your phone: no internet, no server, no API key.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final m in kLocalModels)
            _ModelCard(model: m, selected: state.selectedModel.id == m.id),
          const SizedBox(height: 8),
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Models come from Hugging Face (Qwen2.5-Coder, Apache-2.0) and are stored in this app\'s '
                'documents folder. Keep the app open while downloading; if it stops, tap Resume and it '
                'continues where it left off. Generation is slower than the server and uses a lot of '
                'battery; small models write simpler code.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model, required this.selected});
  final LocalModelInfo model;
  final bool selected;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete model?'),
        content: Text(
          'This frees ${model.sizeLabel}. You can download it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final state = AppStateScope.read(context);
      await state.local.unload();
      await state.models.delete(model);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final mm = state.models;
    final status = mm.statusOf(model);
    final scheme = Theme.of(context).colorScheme;
    final progress = mm.progressOf(model);
    final downloading = status.state == ModelState.downloading;

    final actions = <Widget>[];
    switch (status.state) {
      case ModelState.ready:
        actions.add(
          selected
              ? const Chip(
                  avatar: Icon(Icons.check, size: 18),
                  label: Text('In use'),
                )
              : FilledButton.tonal(
                  onPressed: () => state.selectModel(model),
                  child: const Text('Use this model'),
                ),
        );
        actions.add(
          TextButton.icon(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        );
      case ModelState.downloading:
        actions.add(
          OutlinedButton.icon(
            onPressed: () => mm.stop(model),
            icon: const Icon(Icons.pause),
            label: const Text('Pause'),
          ),
        );
        actions.add(
          TextButton(
            onPressed: () => mm.stop(model, discard: true),
            child: const Text('Cancel'),
          ),
        );
      case ModelState.partial:
        actions.add(
          FilledButton.icon(
            onPressed: () {
              state.selectModel(model);
              mm.download(model);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
          ),
        );
        actions.add(
          TextButton(
            onPressed: () => mm.stop(model, discard: true),
            child: const Text('Cancel'),
          ),
        );
      case ModelState.notDownloaded:
        actions.add(
          FilledButton.icon(
            onPressed: () {
              state.selectModel(model);
              mm.download(model);
            },
            icon: const Icon(Icons.download),
            label: Text('Download ${model.sizeLabel}'),
          ),
        );
    }

    return Card(
      shape: selected
          ? RoundedRectangleBorder(
              side: BorderSide(color: scheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(model.description),
            const SizedBox(height: 4),
            Text(
              '${model.sizeLabel} • needs about ${model.minRamGb} GB RAM • ${model.license}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            if (downloading || status.state == ModelState.partial) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text(
                '${formatBytes(status.downloaded)} of ${model.sizeLabel} (${(progress * 100).toStringAsFixed(0)}%)'
                '${downloading ? '' : ' • paused'}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (status.error != null) ...[
              const SizedBox(height: 6),
              Text(
                status.error!,
                style: TextStyle(color: scheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}
