import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/dialogue.dart';

const _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
const _defaultModel = 'openrouter/free';

List<String> _candidateDirs() {
  final cwd = Directory.current.path;
  return [cwd, p.normalize(p.join(cwd, '..')), p.normalize(p.join(cwd, '..', '..'))];
}

/// Reads project.json from the Renpy project directory (same pattern as Renpy).
Map<String, dynamic> _loadProjectJson() {
  for (final dir in _candidateDirs()) {
    final f = File(p.join(dir, 'project.json'));
    if (f.existsSync()) {
      try { return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>; } catch (_) {}
    }
  }
  return {};
}

/// Reads OPENROUTER key from a .env file.
/// Supports `OPENROUTER_API_KEY=sk-...` and non-standard `openrouter key: sk-...`.
String _loadDotEnvKey() {
  for (final dir in _candidateDirs()) {
    final f = File(p.join(dir, '.env'));
    if (!f.existsSync()) continue;
    for (final line in f.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#') || trimmed.isEmpty) continue;
      // Standard: KEY=value
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx > 0) {
        final key = trimmed.substring(0, eqIdx).trim().toUpperCase();
        if (key == 'OPENROUTER_API_KEY' || key == 'OPENROUTER_KEY') {
          return trimmed.substring(eqIdx + 1).trim();
        }
      }
      // Non-standard: "openrouter key: value"
      final lc = trimmed.toLowerCase();
      if (lc.startsWith('openrouter')) {
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx > 0) {
          final val = trimmed.substring(colonIdx + 1).trim();
          if (val.isNotEmpty) return val;
        }
      }
    }
  }
  return '';
}

class DialogueAiService {
  DialogueAiService._();
  static final instance = DialogueAiService._();

  String? _apiKeyOverride;

  String get apiKey {
    if (_apiKeyOverride != null && _apiKeyOverride!.isNotEmpty) return _apiKeyOverride!;
    final envKey = Platform.environment['OPENROUTER_API_KEY'] ??
        Platform.environment['OPENROUTER_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;
    final dotEnvKey = _loadDotEnvKey();
    if (dotEnvKey.isNotEmpty) return dotEnvKey;
    final proj = _loadProjectJson();
    return (proj['OPENROUTER_API_KEY'] ?? proj['openrouter_api_key'] ?? proj['api_key'] ?? '') as String;
  }

  void setApiKey(String key) => _apiKeyOverride = key;

  bool get hasApiKey => apiKey.isNotEmpty;

  Future<String> _call(String prompt, {int maxTokens = 200}) async {
    final key = apiKey;
    if (key.isEmpty) throw Exception('API key not set');

    final body = jsonEncode({
      'model': _defaultModel,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a creative assistant generating dialogue for a visual novel. '
              'Respond in idiomatic European Portuguese (Português de Portugal). '
              'Be concise and in-character. No profanity.',
        },
        {'role': 'user', 'content': prompt},
      ],
      'max_tokens': maxTokens,
      'temperature': 0.75,
    });

    final resp = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'http://localhost',
        'X-Title': 'VisualNovelEditor',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = (data['choices'] as List?)?.firstOrNull;
    if (content == null) throw Exception('Empty response');
    return ((content as Map)['message']?['content'] ?? '') as String;
  }

  /// Suggest text for a single dialogue line.
  Future<String> suggestLine({
    required String speakerName,
    required String context,
    String previousLine = '',
  }) async {
    final hist = previousLine.isNotEmpty ? '\nPrevious line: "$previousLine"' : '';
    final prompt =
        'Visual novel character "$speakerName" is speaking.$hist\n'
        'Context: $context\n'
        'Write ONE short dialogue line (max 2 sentences) for $speakerName. '
        'Return only the line text, no quotes, no prefix.';
    return (await _call(prompt, maxTokens: 100)).trim();
  }

  /// Generate a full scripted dialogue given character names and context.
  Future<List<({String speaker, String text})>> generateDialogueTree({
    required List<String> characterNames,
    required String topic,
    required int numLines,
  }) async {
    final chars = characterNames.join(', ');
    final prompt =
        'Write a $numLines-line visual novel dialogue between: $chars.\n'
        'Topic: $topic.\n'
        'Return ONLY a JSON array, no prose:\n'
        '[{"speaker":"Name","text":"line text"}, ...]\n'
        'Keep each line under 30 words.';

    final raw = await _call(prompt, maxTokens: numLines * 60);

    // Extract JSON array from response
    final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(raw);
    if (match == null) throw Exception('No JSON in response');
    final list = jsonDecode(match.group(0)!) as List;
    return list
        .map((e) => (
              speaker: (e as Map)['speaker'] as String? ?? '',
              text: e['text'] as String? ?? '',
            ))
        .toList();
  }

  /// Generate playerChat emotion branches for given emotion IDs.
  Future<Map<int, PlayerEmotionBranch>> generateEmotionBranches({
    required List<int> emotionIds,
    required String topic,
    required String npcName,
  }) async {
    final selected = emotionIds
        .where((id) => id >= 0 && id < _emotionNames.length)
        .map((id) => '"${_emotionNames[id]}"')
        .join(', ');

    final prompt =
        'Visual novel NPC: $npcName. Topic: $topic.\n'
        'For EACH emotion below, write:\n'
        '1. One short player line (first-person, that emotion)\n'
        '2. One NPC response ($npcName)\n'
        'Return ONLY JSON, no prose:\n'
        '{"EmotionName": {"player": "...", "npc": "..."}, ...}\n'
        'Emotions: $selected\n'
        'Each line under 25 words. European Portuguese.';

    final raw = await _call(prompt, maxTokens: emotionIds.length * 80);

    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
    if (match == null) throw Exception('No JSON in response');
    final map = jsonDecode(match.group(0)!) as Map<String, dynamic>;

    final result = <int, PlayerEmotionBranch>{};
    for (var id in emotionIds) {
      if (id < 0 || id >= _emotionNames.length) continue;
      final name = _emotionNames[id];
      final entry = map[name] as Map<String, dynamic>?;
      if (entry == null) continue;
      result[id] = PlayerEmotionBranch(
        emotionId: id,
        playerLine: (entry['player'] as String? ?? '').trim(),
        npcResponse: (entry['npc'] as String? ?? '').trim(),
      );
    }
    return result;
  }
}

/// Emotion names matching EMOTION_WHEEL in player_interaction.rpy (index = emotionId).
const _emotionNames = [
  'Alert', 'Happy', 'Contented', 'Relaxed',
  'Fatigued', 'Sad', 'Upset', 'Nervous',
  'Excited', 'Elated', 'Serene', 'Calm',
  'Lethargic', 'Depressed', 'Angry', 'Tense',
];
