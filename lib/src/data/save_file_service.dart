import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/save_data.dart';

class SaveFileService {
  @pragma('vm:prefer-inline')
  static Future<Directory> get _savesDir async {
    final dir = Directory('saves');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static Future<List<SaveData>> listSaves() async {
    final dir = await _savesDir;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    final saves = <SaveData>[];
    for (final file in files) {
      try {
        final json = jsonDecode(file.readAsStringSync());
        saves.add(SaveData.fromJson(json));
      } catch (e) {
        debugPrint('Error loading save ${file.path}: $e');
      }
    }

    saves.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return saves;
  }

  static Future<SaveData?> loadSave(String saveName) async {
    final dir = await _savesDir;
    final file = File('${dir.path}/$saveName.json');

    if (!file.existsSync()) return null;

    try {
      final json = jsonDecode(file.readAsStringSync());
      return SaveData.fromJson(json);
    } catch (e) {
      debugPrint('Error loading save $saveName: $e');
      return null;
    }
  }

  static Future<void> saveSave(SaveData save) async {
    try {
      final dir = await _savesDir;
      final file = File('${dir.path}/${save.saveName}.json');
      file.writeAsStringSync(jsonEncode(save.toJson()), flush: true);
    } catch (e) {
      debugPrint('Error saving "${ save.saveName}": $e');
    }
  }

  static Future<void> deleteSave(String saveName) async {
    final dir = await _savesDir;
    final file = File('${dir.path}/$saveName.json');
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  static Future<bool> saveExists(String saveName) async {
    final dir = await _savesDir;
    final file = File('${dir.path}/$saveName.json');
    return file.existsSync();
  }
}
