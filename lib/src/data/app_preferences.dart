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

  static String get imagesRoot => (_data['imagesRoot'] as String?) ?? '';
  static void setImagesRoot(String v) {
    _data['imagesRoot'] = v;
    _persist();
  }
}
