class Generation {
  Generation({
    required this.id,
    required this.prompt,
    required this.code,
    required this.file,
    required this.createdAt,
    this.model,
  });

  final String id;
  final String prompt;
  final String code;
  final String file;
  final DateTime createdAt;
  final String? model;

  int get lineCount => '\n'.allMatches(code).length + 1;

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'code': code,
    'file': file,
    'createdAt': createdAt.toIso8601String(),
    if (model != null) 'model': model,
  };

  static Generation? tryParse(Object? json) {
    if (json is! Map) return null;
    final code = json['code'];
    final prompt = json['prompt'];
    if (code is! String || prompt is! String) return null;
    return Generation(
      id:
          (json['id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      prompt: prompt,
      code: code,
      file: (json['file'] as String?) ?? 'lib/main.dart',
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      model: json['model'] as String?,
    );
  }
}
