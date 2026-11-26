import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.offline = false});
  final String message;
  final bool offline;
  @override
  String toString() => message;
}

class GeneratorApi {
  GeneratorApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static Uri endpoint(String baseUrl) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse('$base/api/generate');
  }

  Future<Generation> generate({
    required String prompt,
    required String baseUrl,
    required String appKey,
  }) async {
    final Uri uri;
    try {
      uri = endpoint(baseUrl);
      if (!uri.hasScheme || uri.host.isEmpty) throw const FormatException();
    } on FormatException {
      throw ApiException('The server URL in Settings is not valid.');
    }
    if (appKey.isEmpty) {
      throw ApiException('Add your App key in Settings first.');
    }

    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'X-App-Key': appKey},
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(kRequestTimeout);
    } on TimeoutException {
      throw ApiException(
        'The server took too long to answer. Try a shorter idea or try again.',
      );
    } on SocketException {
      throw ApiException(
        "You're offline or the server can't be reached. Your history still works offline.",
        offline: true,
      );
    } on HandshakeException {
      throw ApiException(
        'Secure connection to the server failed. Check the server URL.',
      );
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', offline: true);
    }

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}

    if (res.statusCode != 200) {
      final detail = data?['detail'];
      final message = detail is String && detail.isNotEmpty
          ? detail
          : _fallback(res.statusCode);
      throw ApiException(message);
    }
    final code = data?['code'];
    if (code is! String || code.trim().isEmpty) {
      throw ApiException(
        'The server returned no code. Try rephrasing your idea.',
      );
    }
    return Generation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      prompt: prompt,
      code: code,
      file: (data?['file'] as String?) ?? 'lib/main.dart',
      createdAt: DateTime.now(),
      model: data?['model'] as String?,
    );
  }

  static String _fallback(int status) => switch (status) {
    401 => 'The App key was rejected. Check it in Settings.',
    404 => 'The server URL looks wrong (endpoint not found). Check Settings.',
    429 => 'Too many requests. Wait a minute and try again.',
    >= 500 => 'The server had a problem (HTTP $status). Try again shortly.',
    _ => 'Request failed (HTTP $status).',
  };
}
