import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Synchronous, file-backed key-value store.
/// Call [load] once at app startup before accessing any value.
class AppPreferences {
  AppPreferences._();

  static final _file =
      File(p.join(Directory.current.path, 'tese_prefs.json'));

  static Map<String, dynamic> _data = {};

  static void load() {
    try {
      if (_file.existsSync()) {
        _data = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      }
    } catch (_) {}
  }

  static void _persist() {
    try {
      _file.writeAsStringSync(jsonEncode(_data));
    } catch (_) {}
  }

  static String get apiKey => (_data['apiKey'] as String?) ?? '';
  static void setApiKey(String v) {
    _data['apiKey'] = v;
    _persist();
  }

  static String get assetsRoot {
    final v = (_data['assetsRoot'] as String?) ?? '';
    if (v.isNotEmpty) return v;
    // migrate old key
    return (_data['imagesRoot'] as String?) ?? '';
  }

  static void setAssetsRoot(String v) {
    _data['assetsRoot'] = v;
    _data.remove('imagesRoot');
    _persist();
  }

  @Deprecated('use assetsRoot')
  static String get imagesRoot => assetsRoot;
  @Deprecated('use setAssetsRoot')
  static void setImagesRoot(String v) => setAssetsRoot(v);

  static bool get ollamaEnabled => (_data['ollamaEnabled'] as bool?) ?? false;
  static void setOllamaEnabled(bool v) {
    _data['ollamaEnabled'] = v;
    _persist();
  }

  static String get ollamaHost =>
      (_data['ollamaHost'] as String?) ?? 'http://localhost:11434';
  static void setOllamaHost(String v) {
    _data['ollamaHost'] = v;
    _persist();
  }

  static String get ollamaModel =>
      (_data['ollamaModel'] as String?) ?? 'gemma4:latest';
  static void setOllamaModel(String v) {
    _data['ollamaModel'] = v;
    _persist();
  }

  static bool get testingChecklistEnabled =>
      (_data['testingChecklistEnabled'] as bool?) ?? false;
  static void setTestingChecklistEnabled(bool v) {
    _data['testingChecklistEnabled'] = v;
    _persist();
  }

  static Set<String> get testingChecklistProgress => ((_data['testingChecklistProgress'] as List?) ?? [])
      .cast<String>()
      .toSet();
  static void setTestingChecklistProgress(Set<String> ids) {
    _data['testingChecklistProgress'] = ids.toList();
    _persist();
  }
}
