/// Shared prompt and post-processing used by both the server and on-device engines.
const String kSystemPrompt = '''
You generate a single, complete, self-contained Flutter `lib/main.dart` for the user's app idea.
Rules:
- Return ONLY Dart source code. No markdown, no code fences, no explanations before or after.
- Use only the Flutter SDK (package:flutter/material.dart and dart: libraries). No third-party packages.
- Start with the imports and include a `void main()` that calls runApp.
- Use Material 3 (useMaterial3: true) with light and dark themes.
- The code must compile with the current stable Flutter SDK and null safety.
- Never include API keys, secrets or real personal data.''';

final RegExp _fenceBlock = RegExp(
  r'```[a-zA-Z0-9_+-]*[ \t]*\r?\n([\s\S]*?)```',
);
final RegExp _openFence = RegExp(r'^```[a-zA-Z0-9_+-]*[ \t]*\r?\n?');
final RegExp _closeFence = RegExp(r'\r?\n?```\s*$');

/// Removes markdown code fences and surrounding chatter, like the server does.
String stripCodeFences(String text) {
  var s = text.trim();
  final block = _fenceBlock.firstMatch(s);
  if (block != null) {
    s = block.group(1)!;
  } else {
    s = s.replaceFirst(_openFence, '').replaceFirst(_closeFence, '');
  }
  return '${s.trim()}\n';
}
