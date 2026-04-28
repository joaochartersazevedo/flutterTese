import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/character.dart';


const _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
const _defaultModel = 'openrouter/free';

List<String> _candidateDirs() {
  final cwd = Directory.current.path;
  return [
    cwd,
    p.normalize(p.join(cwd, '..')),
    p.normalize(p.join(cwd, '..', '..')),
  ];
}

/// Reads project.json from the Renpy project directory (same pattern as Renpy).
Map<String, dynamic> _loadProjectJson() {
  for (final dir in _candidateDirs()) {
    final f = File(p.join(dir, 'project.json'));
    if (f.existsSync()) {
      try {
        return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {}
    }
  }
  return {};
}

/// Reads OPENROUTER key from a .env file.
/// Supports JSON format, `OPENROUTER_API_KEY=sk-...`, and non-standard `openrouter key: sk-...`.
String _loadDotEnvKey() {
  for (final dir in _candidateDirs()) {
    final f = File(p.join(dir, '.env'));
    if (!f.existsSync()) continue;
    try {
      // Try JSON format first
      final content = f.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final key =
          (data['OPENROUTER_API_KEY'] ?? data['openrouter_api_key'] ?? '')
              as String;
      if (key.isNotEmpty) return key;
    } catch (_) {
      // Not JSON, try line-by-line parsing
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
  }
  return '';
}

class DialogueAiService {
  DialogueAiService._();
  static final instance = DialogueAiService._();

  String? _apiKeyOverride;

  String get apiKey {
    if (_apiKeyOverride != null && _apiKeyOverride!.isNotEmpty) {
      return _apiKeyOverride!;
    }
    final envKey =
        Platform.environment['OPENROUTER_API_KEY'] ??
        Platform.environment['OPENROUTER_KEY'];
    if (envKey != null && envKey.isNotEmpty) return envKey;
    final dotEnvKey = _loadDotEnvKey();
    if (dotEnvKey.isNotEmpty) return dotEnvKey;
    final proj = _loadProjectJson();
    return (proj['OPENROUTER_API_KEY'] ??
            proj['openrouter_api_key'] ??
            proj['api_key'] ??
            '')
        as String;
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

    final resp = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'http://localhost',
            'X-Title': 'VisualNovelEditor',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

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
    Character? speaker,
    List<Character> allChars = const [],
  }) async {
    final hist = previousLine.isNotEmpty
        ? '\nPrevious line: "$previousLine"'
        : '';
    final personalityCtx = speaker != null ? _personalityContext(speaker) : '';
    final relCtx = speaker != null ? _relationshipsContext(speaker, allChars) : '';
    final personalityLine = personalityCtx.isNotEmpty
        ? '\nPersonality: $personalityCtx'
        : '';
    final relLine = relCtx.isNotEmpty
        ? '\nRelationships: $relCtx'
        : '';
    final prompt =
        'Visual novel character "$speakerName" is speaking.$hist$personalityLine$relLine\n'
        'Context: $context\n'
        'Write ONE short dialogue line (max 2 sentences) for $speakerName. '
        'Return only the line text, no quotes, no prefix.';
    return (await _call(prompt, maxTokens: 100)).trim();
  }

  /// Generate a single line from a custom prompt (emotion responses, context-aware).
  Future<String> generateLine(String prompt) async {
    return (await _call(prompt, maxTokens: 150)).trim();
  }

  /// Generate a full scripted dialogue given character names and context.
  Future<List<({String speaker, String text})>> generateDialogueTree({
    required List<String> characterNames,
    required String topic,
    required int numLines,
    List<Character> characters = const [],
  }) async {
    final chars = characterNames.join(', ');
    final charContext = _buildCharacterContext(
      characters.where((c) => characterNames.contains(c.name)).toList(),
      characters,
    );
    final charContextLine = charContext.isNotEmpty ? '\n$charContext' : '';
    final prompt =
        'Write a $numLines-line visual novel dialogue between: $chars.\n'
        'Topic: $topic.$charContextLine\n'
        'Return ONLY a JSON array, no prose:\n'
        '[{"speaker":"Name","text":"line text"}, ...]\n'
        'Keep each line under 30 words.';

    final raw = await _call(prompt, maxTokens: numLines * 60);

    // Extract JSON array from response
    final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(raw);
    if (match == null) throw Exception('No JSON in response');
    final list = jsonDecode(match.group(0)!) as List;
    return list
        .map(
          (e) => (
            speaker: (e as Map)['speaker'] as String? ?? '',
            text: e['text'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// Generate player lines for each emotion in a playerChat choice node.
  /// Returns emotionId → player line text (one short line per emotion).
  Future<Map<int, String>> generatePlayerLines({
    required List<int> emotionIds,
    required String topic,
    required String npcName,
  }) async {
    final selected = emotionIds
        .where((id) => id >= 0 && id < _emotionNames.length)
        .map((id) => '"${_emotionNames[id]}"')
        .join(', ');

    final prompt =
        'Visual novel. NPC: $npcName. Topic: $topic.\n'
        'For EACH emotion below, write ONE short first-person player line '
        'expressing that emotion.\n'
        'Return ONLY JSON, no prose:\n'
        '{"EmotionName": "player line text", ...}\n'
        'Emotions: $selected\n'
        'Each line under 20 words. European Portuguese. (PT-PT)';

    final raw = await _call(prompt, maxTokens: emotionIds.length * 40);

    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
    if (match == null) throw Exception('No JSON in response');
    final map = jsonDecode(match.group(0)!) as Map<String, dynamic>;

    final result = <int, String>{};
    for (final id in emotionIds) {
      if (id < 0 || id >= _emotionNames.length) continue;
      final name = _emotionNames[id];
      final text = (map[name] as String? ?? '').trim();
      if (text.isNotEmpty) result[id] = text;
    }
    return result;
  }
}

// ─── Personality / relationship helpers ──────────────────────────────────────

const _traitDescriptions = <String, List<String?>>{
  'extroverted': ['very introverted', null, 'very extroverted'],
  'friendly':    ['hostile/unfriendly', null, 'very friendly and agreeable'],
  'responsible': ['irresponsible and careless', null, 'very responsible and conscientious'],
  'anxious':     ['very calm and emotionally stable', null, 'very anxious and neurotic'],
  'creative':    ['conventional and closed-minded', null, 'very creative and open to experience'],
};

String _personalityContext(Character c) {
  if (c.personality.isEmpty) return '';
  final parts = <String>[];
  for (final entry in c.personality.entries) {
    if (entry.value == 1) continue;
    final desc = _traitDescriptions[entry.key]?[entry.value];
    if (desc != null) parts.add(desc);
  }
  return parts.join(', ');
}

String _relationshipsContext(Character speaker, List<Character> allChars) {
  if (speaker.relationships.isEmpty) return '';
  final parts = <String>[];
  for (final entry in speaker.relationships.entries) {
    final other = allChars.where((c) => c.id == entry.key).firstOrNull;
    final name = other?.name ?? 'character#${entry.key}';
    parts.add('$name: ${entry.value}');
  }
  return parts.join('; ');
}

String _buildCharacterContext(List<Character> subjects, List<Character> allChars) {
  final lines = <String>[];
  for (final c in subjects) {
    final p = _personalityContext(c);
    final r = _relationshipsContext(c, allChars);
    if (p.isEmpty && r.isEmpty) continue;
    final parts = [if (p.isNotEmpty) 'personality: $p', if (r.isNotEmpty) 'relationships: $r'];
    lines.add('${c.name} — ${parts.join('; ')}');
  }
  if (lines.isEmpty) return '';
  return 'Character context:\n${lines.join('\n')}';
}

/// Emotion names for AI prompts (index = emotionId, matches emotionWheel in emotion.dart).
const _emotionNames = [
  'Furioso', // 0
  'Nervoso', // 1
  'Alegre', // 2
  'Triste', // 3
  'Animado', // 4
  'Enojado', // 5
  'Calmo', // 6
  'Contente', // 7
];
