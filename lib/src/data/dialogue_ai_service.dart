import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'app_preferences.dart';
import '../models/character.dart';

const _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
const _defaultModel = 'openrouter/owl-alpha';

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

  bool get hasApiKey =>
      AppPreferences.ollamaEnabled || apiKey.isNotEmpty;

  Future<String> _call(String prompt, {int maxTokens = 200}) async {
    final useOllama = AppPreferences.ollamaEnabled;
    final backend = useOllama ? 'Ollama (${AppPreferences.ollamaHost})' : 'OpenRouter';

    final String url;
    final Map<String, String> headers;
    final String model;

    if (useOllama) {
      final host = AppPreferences.ollamaHost.trimRight().replaceAll(RegExp(r'/$'), '');
      if (host.isEmpty) {
        throw Exception(
          'Ollama está ativado mas não tem host configurado. '
          'Define o endereço do servidor Ollama nas Definições.',
        );
      }
      url = '$host/v1/chat/completions';
      headers = {'Content-Type': 'application/json'};
      model = AppPreferences.ollamaModel;
    } else {
      final key = apiKey;
      if (key.isEmpty) {
        throw Exception(
          'Chave da API OpenRouter não configurada. '
          'Define OPENROUTER_API_KEY nas Definições, num ficheiro .env, ou no project.json.',
        );
      }
      url = _openRouterUrl;
      headers = {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'http://localhost',
        'X-Title': 'VisualNovelEditor',
      };
      model = _defaultModel;
    }

    final body = jsonEncode({
      'model': model,
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

    http.Response resp;
    try {
      final respFuture = http.post(Uri.parse(url), headers: headers, body: body);
      resp = useOllama
          ? await respFuture
          : await respFuture.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception(
        '$backend não respondeu a tempo (>30s) a $url. '
        'Verifica a ligação à internet ou se o modelo "$model" está disponível.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Não foi possível ligar a $backend em $url (${e.message}). '
        'Verifica o endereço/porta e se o servidor está a correr.',
      );
    } on http.ClientException catch (e) {
      throw Exception('Falha de rede a contactar $backend em $url: ${e.message}');
    }

    if (resp.statusCode != 200) {
      final reason = switch (resp.statusCode) {
        401 || 403 => 'Chave/credenciais da API inválidas ou sem permissão.',
        404 => 'Modelo "$model" não encontrado em $backend.',
        429 => 'Limite de pedidos excedido (rate limit) em $backend. Espera um pouco e tenta de novo.',
        >= 500 => '$backend teve um erro interno.',
        _ => 'Pedido rejeitado por $backend.',
      };
      throw Exception(
        '$reason\nHTTP ${resp.statusCode} ($backend, modelo "$model").\nResposta: ${resp.body}',
      );
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
        'Resposta de $backend não é JSON válido: $e\nResposta recebida: ${resp.body}',
      );
    }

    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      final err = data['error'];
      throw Exception(
        err != null
            ? '$backend devolveu um erro: $err'
            : '$backend não devolveu nenhuma escolha (choices). Resposta completa: ${resp.body}',
      );
    }

    final text = (choices.first as Map?)?['message']?['content'];
    if (text == null) {
      throw Exception(
        '$backend devolveu uma resposta sem texto (message.content em falta). '
        'Escolha recebida: ${choices.first}',
      );
    }

    return (text as String).trim();
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
        ? '\nDialogue so far:\n$previousLine'
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
        'Character: $speakerName.$personalityLine$relLine\n'
        'Context: $context\n'
        '$hist'
        'Reply with ONLY the spoken line for $speakerName (1-2 sentences, European Portuguese, no quotes, no labels):';
    return (await _call(prompt, maxTokens: 100)).trim();
  }

  /// Generate player lines for each emotion in a playerChat choice node.
  /// Returns emotionId → player line text (one short line per emotion).
  Future<Map<int, String>> generatePlayerLines({
    required List<int> emotionIds,
    required String topic,
    required String npcName,
    String previousLine = '',
    Character? npc,
    List<Character> allChars = const [],
  }) async {
    final selected = emotionIds
        .where((id) => id >= 0 && id < _emotionNames.length)
        .map((id) => '"${_emotionNames[id]}"')
        .join(', ');

    final hist = previousLine.isNotEmpty
        ? '\nDialogue so far:\n$previousLine'
        : '';
    final personalityCtx = npc != null ? _personalityContext(npc) : '';
    final relCtx = npc != null ? _relationshipsContext(npc, allChars) : '';
    final personalityLine = personalityCtx.isNotEmpty
        ? '\nNPC personality: $personalityCtx'
        : '';
    final relLine = relCtx.isNotEmpty ? '\nNPC relationships: $relCtx' : '';

    final prompt =
        'Visual novel. NPC: $npcName.$personalityLine$relLine\n'
        'Topic: $topic.$hist\n'
        'For EACH emotion below, write ONE short first-person player line '
        'reacting to the NPC while expressing that emotion.\n'
        'Return ONLY JSON, no prose:\n'
        '{"EmotionName": "player line text", ...}\n'
        'Emotions: $selected\n'
        'Each line under 20 words. European Portuguese. (PT-PT)';

    final raw = await _call(prompt, maxTokens: emotionIds.length * 40);

    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
    if (match == null) {
      throw Exception(
        'A AI não devolveu um objeto JSON com as linhas dos jogador.\n'
        'Resposta crua recebida: "$raw"',
      );
    }
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
        'JSON das linhas do jogador inválido: $e\nTexto extraído: "${match.group(0)}"',
      );
    }

    final result = <int, String>{};
    for (final id in emotionIds) {
      if (id < 0 || id >= _emotionNames.length) continue;
      final name = _emotionNames[id];
      final text = (map[name] as String? ?? '').trim();
      if (text.isNotEmpty) result[id] = text;
    }
    if (result.isEmpty) {
      throw Exception(
        'A AI devolveu JSON válido mas sem nenhuma das emoções pedidas ($selected).\n'
        'Chaves recebidas: ${map.keys.join(", ")}',
      );
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

/// Emotion names for AI prompts (index = emotionId, matches emotionWheel in emotion.dart).
const _emotionNames = [
  'Furioso',       // 0 — θ=315°
  'Nervoso',       // 1 — θ=270°
  'Alegre',        // 2 — θ=45°
  'Triste',        // 3 — θ=225°
  'Animado',       // 4 — θ=67.5°
  'Enojado',       // 5 — θ=337.5°
  'Calmo',         // 6 — θ=157.5°
  'Contente',      // 7 — θ=112.5°
  'Surpreso',      // 8 — θ=0°
  'Entusiasmado',  // 9 — θ=22.5°
  'Prazer',        // 10 — θ=90°
  'Satisfeito',    // 11 — θ=135°
  'Ansioso',       // 12 — θ=292.5°
  'Aliviado',      // 13 — θ=180°
  'Entediado',     // 14 — θ=202.5°
  'Envergonhado',  // 15 — θ=247.5°
];
