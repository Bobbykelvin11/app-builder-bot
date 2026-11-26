import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

/// Local, offline storage for history, draft prompt and settings.
class Store {
  Store._(this._prefs);

  static const _kHistory = 'history_v1';
  static const _kDraft = 'draft_prompt';
  static const _kApiUrl = 'api_base_url_override';
  static const _kAppKey = 'app_key_override';
  static const _kThemeMode = 'theme_mode';
  static const _kEngine = 'engine_mode';
  static const _kModel = 'local_model_id';

  final SharedPreferences _prefs;

  static Future<Store> open() async =>
      Store._(await SharedPreferences.getInstance());

  // ---- History ----
  List<Generation> loadHistory() {
    final raw = _prefs.getString(_kHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map(Generation.tryParse).whereType<Generation>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<Generation> items) async {
    final trimmed = items
        .take(kMaxHistoryItems)
        .map((g) => g.toJson())
        .toList();
    await _prefs.setString(_kHistory, jsonEncode(trimmed));
  }

  // ---- Draft ----
  String get draft => _prefs.getString(_kDraft) ?? '';
  Future<void> setDraft(String value) => _prefs.setString(_kDraft, value);

  // ---- Settings ----
  String? get apiUrlOverride => _nonEmpty(_prefs.getString(_kApiUrl));
  String? get appKeyOverride => _nonEmpty(_prefs.getString(_kAppKey));

  String get effectiveApiUrl => apiUrlOverride ?? kDefaultApiBaseUrl;
  String get effectiveAppKey => appKeyOverride ?? kDefaultAppKey;

  Future<void> setApiUrlOverride(String? value) =>
      _setOrRemove(_kApiUrl, value);
  Future<void> setAppKeyOverride(String? value) =>
      _setOrRemove(_kAppKey, value);

  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  /// 'device' (default, on-device open-source model) or 'server' (Vercel API).
  String get engineMode => _prefs.getString(_kEngine) ?? 'device';
  Future<void> setEngineMode(String mode) => _prefs.setString(_kEngine, mode);

  String? get localModelId => _prefs.getString(_kModel);
  Future<void> setLocalModelId(String id) => _prefs.setString(_kModel, id);

  Future<void> _setOrRemove(String key, String? value) async {
    final v = value?.trim();
    if (v == null || v.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, v);
    }
  }

  static String? _nonEmpty(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}
