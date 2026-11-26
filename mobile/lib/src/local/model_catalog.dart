/// Open-source GGUF coding models that App Builder can run on the phone.
class LocalModelInfo {
  const LocalModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.minRamGb,
    required this.license,
  });

  final String id;
  final String name;
  final String description;
  final String fileName;
  final String url;
  final int sizeBytes;
  final int minRamGb;
  final String license;

  String get sizeLabel => formatBytes(sizeBytes);
}

const String kDefaultLocalModelId = 'qwen2.5-coder-1.5b-q4km';

const List<LocalModelInfo> kLocalModels = [
  LocalModelInfo(
    id: 'qwen2.5-coder-1.5b-q4km',
    name: 'Qwen2.5-Coder 1.5B (recommended)',
    description:
        'Better code quality. Best on phones with 6 GB of RAM or more.',
    fileName: 'qwen2.5-coder-1.5b-instruct-q4_k_m.gguf',
    url: 'https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf',
    sizeBytes: 1117320768,
    minRamGb: 4,
    license: 'Apache-2.0',
  ),
  LocalModelInfo(
    id: 'qwen2.5-coder-0.5b-q4km',
    name: 'Qwen2.5-Coder 0.5B (small & fast)',
    description: 'For older or low-RAM phones. Faster, but simpler code.',
    fileName: 'qwen2.5-coder-0.5b-instruct-q4_k_m.gguf',
    url: 'https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf',
    sizeBytes: 491400064,
    minRamGb: 3,
    license: 'Apache-2.0',
  ),
];

LocalModelInfo? modelById(String? id) {
  for (final m in kLocalModels) {
    if (m.id == id) return m;
  }
  return null;
}

String formatBytes(num bytes) {
  if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(2)} GB';
  if (bytes >= 1e6) return '${(bytes / 1e6).toStringAsFixed(0)} MB';
  if (bytes >= 1e3) return '${(bytes / 1e3).toStringAsFixed(0)} KB';
  return '${bytes.toInt()} B';
}
