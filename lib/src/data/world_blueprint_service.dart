import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_preferences.dart';
import '../models/world_blueprint.dart';

class WorldBlueprintService {
  static File get _file {
    final root = AppPreferences.assetsRoot;
    final path = root.isNotEmpty
        ? p.join(root, 'world.json')
        : 'world.json';
    return File(path);
  }

  static Future<WorldBlueprint?> load() async {
    final file = _file;
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return WorldBlueprint.fromJson(json);
    } catch (e) {
      debugPrint('WorldBlueprintService.load error: $e');
      return null;
    }
  }

  static Future<void> save(WorldBlueprint blueprint) async {
    try {
      final file = _file;
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(blueprint.toJson()),
        flush: true,
      );
    } catch (e) {
      debugPrint('WorldBlueprintService.save error: $e');
    }
  }

  static bool get exists => _file.existsSync();
}
