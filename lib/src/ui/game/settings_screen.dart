import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../data/app_preferences.dart';
import '../../data/dialogue_ai_service.dart';
import '../app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKey;
  late final TextEditingController _imagesRoot;
  late final TextEditingController _ollamaHost;
  late final TextEditingController _ollamaModel;
  bool _keyVisible = false;
  bool _saved = false;
  bool _ollamaEnabled = false;
  String? _ollamaTestResult;
  bool _ollamaTesting = false;

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController(text: AppPreferences.apiKey);
    _imagesRoot = TextEditingController(text: AppPreferences.imagesRoot);
    _ollamaHost = TextEditingController(text: AppPreferences.ollamaHost);
    _ollamaModel = TextEditingController(text: AppPreferences.ollamaModel);
    _ollamaEnabled = AppPreferences.ollamaEnabled;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _imagesRoot.dispose();
    _ollamaHost.dispose();
    _ollamaModel.dispose();
    super.dispose();
  }

  void _save() {
    final key = _apiKey.text.trim();
    final root = _imagesRoot.text.trim();

    AppPreferences.setApiKey(key);
    AppPreferences.setImagesRoot(root);
    AppPreferences.setOllamaEnabled(_ollamaEnabled);
    AppPreferences.setOllamaHost(_ollamaHost.text.trim());
    AppPreferences.setOllamaModel(_ollamaModel.text.trim());
    DialogueAiService.instance.setApiKey(key);

    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Definições guardadas.')),
    );
  }

  Future<void> _testOllama() async {
    setState(() {
      _ollamaTesting = true;
      _ollamaTestResult = null;
    });
    try {
      final host = _ollamaHost.text.trim().replaceAll(RegExp(r'/$'), '');
      final resp = await http
          .get(Uri.parse('$host/api/tags'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final models = (data['models'] as List?)
                ?.map((m) => (m as Map)['name'] as String? ?? '')
                .where((n) => n.isNotEmpty)
                .toList() ??
            [];
        setState(() => _ollamaTestResult =
            models.isEmpty ? 'Ligado — sem modelos instalados' : 'Modelos: ${models.join(', ')}');
      } else {
        setState(() => _ollamaTestResult = 'Erro HTTP ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _ollamaTestResult = 'Falhou: $e');
    } finally {
      setState(() => _ollamaTesting = false);
    }
  }

  bool _rootValid() {
    final root = _imagesRoot.text.trim();
    return root.isEmpty || Directory(root).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            children: [
              // ── API Key ─────────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.vpn_key_outlined,
                title: 'Chave API (OpenRouter)',
                subtitle:
                    'Necessária para geração de diálogos com IA. '
                    'Obtém em openrouter.ai → Keys.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKey,
                obscureText: !_keyVisible,
                onChanged: (_) => setState(() => _saved = false),
                decoration: InputDecoration(
                  labelText: 'OPENROUTER_API_KEY',
                  hintText: 'sk-or-...',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _keyVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _keyVisible = !_keyVisible),
                    tooltip: _keyVisible ? 'Ocultar' : 'Mostrar',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _KeyStatus(apiKey: _apiKey.text.trim()),

              const SizedBox(height: 32),

              // ── Images root ──────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.folder_outlined,
                title: 'Pasta de imagens',
                subtitle:
                    'Caminho absoluto para a pasta images/ do projeto Ren\'Py. '
                    'Exemplo: /home/user/Tese/game/images',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _imagesRoot,
                onChanged: (_) => setState(() => _saved = false),
                decoration: InputDecoration(
                  labelText: 'Caminho da pasta images/',
                  hintText: '/caminho/para/Tese/game/images',
                  errorText: _imagesRoot.text.isNotEmpty && !_rootValid()
                      ? 'Pasta não encontrada'
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              if (_imagesRoot.text.isNotEmpty && _rootValid())
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 14, color: AppColors.teal),
                    const SizedBox(width: 6),
                    Text(
                      'Pasta encontrada',
                      style: const TextStyle(
                          color: AppColors.teal, fontSize: 12),
                    ),
                  ],
                ),

              const SizedBox(height: 32),

              // ── Ollama ──────────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.computer_outlined,
                title: 'Ollama (local)',
                subtitle:
                    'Usa um modelo local via Ollama em vez da API OpenRouter. '
                    'Requer Ollama instalado e a correr.',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _ollamaEnabled,
                onChanged: (v) => setState(() {
                  _ollamaEnabled = v;
                  _saved = false;
                }),
                title: const Text('Usar Ollama', style: TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
              ),
              if (_ollamaEnabled) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _ollamaHost,
                  onChanged: (_) => setState(() => _saved = false),
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: 'http://localhost:11434',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ollamaModel,
                  onChanged: (_) => setState(() => _saved = false),
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    hintText: 'gemma3:4b',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _ollamaTesting ? null : _testOllama,
                      icon: _ollamaTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering_outlined, size: 16),
                      label: const Text('Testar ligação'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    if (_ollamaTestResult != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _ollamaTestResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _ollamaTestResult!.startsWith('Falhou') ||
                                    _ollamaTestResult!.startsWith('Erro')
                                ? AppColors.error
                                : AppColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // ── Save ────────────────────────────────────────────────────
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Guardar definições'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _saved ? AppColors.teal : AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ── Info ─────────────────────────────────────────────────────
              Text(
                'As definições são guardadas em tese_prefs.json na pasta do programa. '
                'Sem chave API os diálogos devem ser criados manualmente no editor.',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}

class _KeyStatus extends StatelessWidget {
  const _KeyStatus({required this.apiKey});
  final String apiKey;

  @override
  Widget build(BuildContext context) {
    if (apiKey.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 14, color: AppColors.textMuted),
          SizedBox(width: 6),
          Text('Sem chave — geração IA desativada',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.check_circle_outline,
            size: 14, color: AppColors.teal),
        const SizedBox(width: 6),
        Text(
          'Chave configurada (${apiKey.length} caracteres)',
          style: const TextStyle(color: AppColors.teal, fontSize: 12),
        ),
      ],
    );
  }
}
