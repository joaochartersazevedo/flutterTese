import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/dialogue_ai_service.dart';
import '../../data/renpy_asset_resolver.dart';
import '../../domain/blueprint_editor.dart';
import '../../models/character.dart';
import '../../models/dialogue.dart';
import '../../models/emotion.dart';
import '../../models/state_flag.dart';
import '../app_theme.dart';
import '../game/emotion_wheel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Emotion wheel data — matches player_interaction.rpy EMOTION_WHEEL
// ─────────────────────────────────────────────────────────────────────────────

class _EmotionDef {
  const _EmotionDef(this.id, this.name, this.color);
  final int id;
  final String name;
  final Color color;
}

final List<_EmotionDef> _emotions = emotionWheel
    .map((e) => _EmotionDef(e.id, e.label, _hexColorOrWhite(e.color)))
    .toList();

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class AddDialogueScreen extends StatefulWidget {
  const AddDialogueScreen({super.key, required this.editor, this.existing});
  final BlueprintEditor editor;
  final Dialogue? existing;

  @override
  State<AddDialogueScreen> createState() => _AddDialogueScreenState();
}

class _AddDialogueScreenState extends State<AddDialogueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _resolver = RenpyAssetResolver.auto();

  late final TextEditingController _name;
  late final TextEditingController _priority;
  late final TextEditingController _topic;
  late DialogueType _type;
  late bool _singleTrigger;
  late bool _selfRemove;
  late int? _areaId;
  late List<int> _charIds;
  late List<_LineEntry> _lines;
  late Map<int, bool> _preconditions;
  late Map<int, bool> _consequences;
  late Map<int, PlayerEmotionBranch> _playerEmotions;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _priority = TextEditingController(text: '${e?.priority ?? 0}');
    _topic = TextEditingController(text: e?.topic ?? '');
    _type = e?.type ?? DialogueType.chat;
    _singleTrigger = e?.singleTrigger ?? true;
    _selfRemove = e?.selfRemove ?? false;
    _areaId = e?.areaId;
    _charIds = List<int>.from(e?.characterIds ?? []);
    _lines = (e?.lines ?? []).map(_LineEntry.from).toList();
    _preconditions = Map<int, bool>.from(e?.preconditions ?? {});
    _consequences = Map<int, bool>.from(e?.consequences ?? {});
    _playerEmotions = Map<int, PlayerEmotionBranch>.from(e?.playerEmotions ?? {});
  }

  @override
  void dispose() {
    _name.dispose();
    _priority.dispose();
    _topic.dispose();
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ?? widget.editor.nextDialogueId();
    Navigator.pop(
      context,
      Dialogue(
        id: id,
        name: _name.text.trim(),
        type: _type,
        characterIds: List<int>.from(_charIds),
        lines: _lines.map((l) => l.toLine()).toList(),
        singleTrigger: _singleTrigger,
        selfRemove: _selfRemove,
        priority: int.tryParse(_priority.text) ?? 0,
        areaId: _areaId,
        topic: _topic.text.trim().isEmpty ? null : _topic.text.trim(),
        preconditions: Map<int, bool>.from(_preconditions),
        consequences: Map<int, bool>.from(_consequences),
        playerEmotions: Map<int, PlayerEmotionBranch>.from(_playerEmotions),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chars = widget.editor.characters.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final flags = widget.editor.gamestates.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final areas = widget.editor.areas.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final isNew = widget.existing == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Novo Dialogo' : 'Editar Dialogo'),
        actions: [
          _AiKeyButton(),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: Text(isNew ? 'Criar' : 'Guardar'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left panel: metadata ─────────────────────────────────────
            SizedBox(
              width: 340,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _section('Identificação'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nome *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<DialogueType>(
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: DialogueType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(_typeLabel(t)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        suffixIcon: Tooltip(
                          message: 'Maior = aparece primeiro',
                          child: Icon(Icons.info_outline, size: 16),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 20),
                    _section('Personagens'),
                    const SizedBox(height: 10),
                    if (chars.isEmpty)
                      const Text('Sem personagens.',
                          style: TextStyle(color: Colors.orange))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: chars.map((c) {
                          final sel = _charIds.contains(c.id);
                          return FilterChip(
                            label: Text(c.name),
                            selected: sel,
                            onSelected: (v) => setState(() {
                              if (v) { _charIds.add(c.id); }
                              else { _charIds.remove(c.id); }
                            }),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                    if (_type == DialogueType.localized ||
                        _type == DialogueType.playerChat) ...[
                      _section('Localização'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: areas.any((a) => a.id == _areaId) ? _areaId : null,
                        decoration: const InputDecoration(labelText: 'Area'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Qualquer area')),
                          ...areas.map(
                              (a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                        ],
                        onChanged: (v) => setState(() => _areaId = v),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_type == DialogueType.playerChat) ...[
                      _section('Tópico (AI)'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _topic,
                        decoration: const InputDecoration(
                          labelText: 'Assunto da conversa',
                          hintText: 'e.g. the upcoming school exam',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                    ],
                    _section('Opções'),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Single trigger'),
                      subtitle: const Text('Dispara só uma vez'),
                      value: _singleTrigger,
                      onChanged: (v) => setState(() => _singleTrigger = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Auto-remover'),
                      value: _selfRemove,
                      onChanged: (v) => setState(() => _selfRemove = v),
                    ),
                    const SizedBox(height: 20),
                    _ConditionsSection(
                      title: 'Pré-condições',
                      flags: flags,
                      conditions: _preconditions,
                      onChanged: (m) => setState(() => _preconditions = m),
                    ),
                    const SizedBox(height: 16),
                    _ConditionsSection(
                      title: 'Consequências',
                      flags: flags,
                      conditions: _consequences,
                      onChanged: (m) => setState(() => _consequences = m),
                    ),
                  ],
                ),
              ),
            ),

            // ── Right panel: content editor ──────────────────────────────
            Expanded(
              child: _type == DialogueType.playerChat
                  ? _PlayerChatEditor(
                      key: ValueKey(_charIds),
                      charIds: _charIds,
                      chars: chars,
                      topic: _topic.text,
                      playerEmotions: _playerEmotions,
                      resolver: _resolver,
                      onChanged: (map) =>
                          setState(() => _playerEmotions = map),
                      onTopicChange: () => setState(() {}),
                      topicCtrl: _topic,
                    )
                  : _LinesEditor(
                      lines: _lines,
                      chars: chars,
                      charIds: _charIds,
                      resolver: _resolver,
                      topic: _topic.text,
                      onAdd: () =>
                          setState(() => _lines.add(_LineEntry(
                              speakerId: _charIds.firstOrNull ?? 0))),
                      onRemove: (i) {
                        _lines[i].dispose();
                        setState(() => _lines.removeAt(i));
                      },
                      onReorder: (a, b) => setState(() {
                        if (b > a) b--;
                        final item = _lines.removeAt(a);
                        _lines.insert(b, item);
                      }),
                      onChanged: () => setState(() {}),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(DialogueType t) => switch (t) {
        DialogueType.text => 'Text (monólogo)',
        DialogueType.chat => 'Chat (personagens)',
        DialogueType.localized => 'Localized (área fixa)',
        DialogueType.playerChat => 'PlayerChat (AI + emoções)',
      };

  Widget _section(String label) => Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Lines editor (chat / text / localized)
// ─────────────────────────────────────────────────────────────────────────────

class _LinesEditor extends StatelessWidget {
  const _LinesEditor({
    required this.lines,
    required this.chars,
    required this.charIds,
    required this.resolver,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
    required this.onChanged,
    this.topic = '',
  });

  final List<_LineEntry> lines;
  final List<Character> chars;
  final List<int> charIds;
  final RenpyAssetResolver resolver;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int, int) onReorder;
  final VoidCallback onChanged;
  final String topic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Row(
            children: [
              const Text('Linhas de diálogo',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (DialogueAiService.instance.hasApiKey)
                OutlinedButton.icon(
                  onPressed: () => _aiGenerateAll(context),
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Gerar com AI', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Linha', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text('Sem linhas',
                          style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Adicionar linha'),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: lines.length,
                  onReorder: onReorder,
                  itemBuilder: (context, i) => _LineCard(
                    key: ValueKey(lines[i]),
                    line: lines[i],
                    index: i,
                    chars: chars,
                    resolver: resolver,
                    onRemove: () => onRemove(i),
                    onChanged: onChanged,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _aiGenerateAll(BuildContext context) async {
    final charNames = chars
        .where((c) => charIds.contains(c.id))
        .map((c) => c.name)
        .toList();
    if (charNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleciona personagens primeiro.')),
      );
      return;
    }
    try {
      final generated = await DialogueAiService.instance.generateDialogueTree(
        characterNames: charNames,
        topic: topic.isNotEmpty ? topic : 'a conversation',
        numLines: 6,
      );
      for (final entry in generated) {
        final char = chars.firstWhere(
          (c) => c.name.toLowerCase() == entry.speaker.toLowerCase(),
          orElse: () => chars.first,
        );
        lines.add(_LineEntry(
          speakerId: char.id,
          text: entry.text,
        ));
      }
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro AI: $e')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Line card
// ─────────────────────────────────────────────────────────────────────────────

class _LineEntry {
  _LineEntry({required this.speakerId, String text = '', this.emotionId = 0})
      : textCtrl = TextEditingController(text: text);

  factory _LineEntry.from(DialogueLine l) =>
      _LineEntry(speakerId: l.speakerId, text: l.text, emotionId: l.emotionId);

  final TextEditingController textCtrl;
  int speakerId;
  int emotionId;

  DialogueLine toLine() =>
      DialogueLine(speakerId: speakerId, emotionId: emotionId, text: textCtrl.text.trim());

  void dispose() => textCtrl.dispose();
}

class _LineCard extends StatefulWidget {
  const _LineCard({
    super.key,
    required this.line,
    required this.index,
    required this.chars,
    required this.resolver,
    required this.onRemove,
    required this.onChanged,
  });
  final _LineEntry line;
  final int index;
  final List<Character> chars;
  final RenpyAssetResolver resolver;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  bool _generating = false;

  Character? get _speaker => widget.chars.firstWhere(
        (c) => c.id == widget.line.speakerId,
        orElse: () => widget.chars.isEmpty
            ? const Character(id: 0, name: 'Jogador', colorHex: '#009900', portraitPath: '', areaId: 0, bodyPath: '')
            : widget.chars.first,
      );

  @override
  Widget build(BuildContext context) {
    final char = _speaker;
    final charColor = _hexColorOrWhite(char?.colorHex ?? '#ffffff');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceHighlight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                // Line number + drag handle
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Icon(Icons.drag_handle,
                      size: 18, color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
                Text('#${widget.index + 1}',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                // Speaker selector
                Container(
                  width: 3,
                  height: 20,
                  color: charColor,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Expanded(
                  child: DropdownButton<int>(
                    value: widget.chars.any((c) => c.id == widget.line.speakerId)
                        ? widget.line.speakerId
                        : null,
                    hint: const Text('Quem fala',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    items: [
                      if (!widget.chars.any((c) => c.id == 0))
                        const DropdownMenuItem(
                            value: 0,
                            child: Text('Jogador',
                                style: TextStyle(color: Color(0xFF009900)))),
                      ...widget.chars.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          )),
                    ],
                    onChanged: (v) =>
                        setState(() => widget.line.speakerId = v ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.error,
                  onPressed: widget.onRemove,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remover linha',
                ),
              ],
            ),
          ),
          // Emotion picker
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: _EmotionPicker(
              emotionId: widget.line.emotionId,
              onChanged: (e) => setState(() => widget.line.emotionId = e),
            ),
          ),
          // Text field + AI button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.line.textCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Texto',
                      hintText: 'O que diz esta personagem...',
                    ),
                    maxLines: 2,
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
                if (DialogueAiService.instance.hasApiKey) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: _generating
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Tooltip(
                            message: 'Sugerir com AI',
                            child: OutlinedButton(
                              onPressed: _suggestLine,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: const BorderSide(color: AppColors.accent),
                                padding: const EdgeInsets.all(10),
                                minimumSize: Size.zero,
                              ),
                              child: const Icon(Icons.auto_awesome, size: 16),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _suggestLine() async {
    setState(() => _generating = true);
    try {
      final speakerName = widget.chars
              .firstWhere((c) => c.id == widget.line.speakerId,
                  orElse: () => const Character(
                      id: 0, name: 'Jogador', colorHex: '', portraitPath: '', areaId: 0, bodyPath: ''))
              .name;
      final suggestion = await DialogueAiService.instance.suggestLine(
        speakerName: speakerName,
        context: 'Visual novel scene',
        previousLine: widget.line.textCtrl.text,
      );
      widget.line.textCtrl.text = suggestion;
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro AI: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Emotion picker (portrait emotions 0-6 for regular lines)
// ─────────────────────────────────────────────────────────────────────────────

class _EmotionPicker extends StatelessWidget {
  const _EmotionPicker({
    required this.emotionId,
    required this.onChanged,
  });

  final int emotionId;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final current = getEmotion(emotionId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Emoção:',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(width: 8),
            Text(
              current.label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          height: 200,
          child: EmotionWheel(
                    size: 420,
                    selectedEmotionId: emotionId,
            onEmotionSelected: onChanged,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlayerChat editor (emotion wheel + branch editor)
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerChatEditor extends StatefulWidget {
  const _PlayerChatEditor({
    super.key,
    required this.charIds,
    required this.chars,
    required this.topic,
    required this.playerEmotions,
    required this.resolver,
    required this.onChanged,
    required this.onTopicChange,
    required this.topicCtrl,
  });
  final List<int> charIds;
  final List<Character> chars;
  final String topic;
  final Map<int, PlayerEmotionBranch> playerEmotions;
  final RenpyAssetResolver resolver;
  final void Function(Map<int, PlayerEmotionBranch>) onChanged;
  final VoidCallback onTopicChange;
  final TextEditingController topicCtrl;

  @override
  State<_PlayerChatEditor> createState() => _PlayerChatEditorState();
}

class _PlayerChatEditorState extends State<_PlayerChatEditor> {
  int? _selectedEmotionId;
  bool _generating = false;
  String _genStatus = '';

  void _toggleEmotion(int id) {
    final map = Map<int, PlayerEmotionBranch>.from(widget.playerEmotions);
    if (map.containsKey(id)) {
      map.remove(id);
      if (_selectedEmotionId == id) _selectedEmotionId = null;
    } else {
      map[id] = PlayerEmotionBranch(emotionId: id);
      _selectedEmotionId = id;
    }
    widget.onChanged(map);
    setState(() {});
  }

  void _selectEmotion(int id) {
    setState(() => _selectedEmotionId = id);
  }

  void _updateBranch(PlayerEmotionBranch branch) {
    final map = Map<int, PlayerEmotionBranch>.from(widget.playerEmotions);
    map[branch.emotionId] = branch;
    widget.onChanged(map);
  }

  Future<void> _generateAll() async {
    final ids = widget.playerEmotions.keys.toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ativa emoções na roda primeiro.')),
      );
      return;
    }
    final npcId = widget.charIds.firstOrNull;
    final npcName = npcId != null
        ? widget.chars.firstWhere((c) => c.id == npcId, orElse: () => widget.chars.first).name
        : 'NPC';

    setState(() { _generating = true; _genStatus = 'A gerar...'; });
    try {
      final result = await DialogueAiService.instance.generateEmotionBranches(
        emotionIds: ids,
        topic: widget.topicCtrl.text.isNotEmpty ? widget.topicCtrl.text : 'conversa',
        npcName: npcName,
      );
      final map = Map<int, PlayerEmotionBranch>.from(widget.playerEmotions);
      for (final entry in result.entries) {
        map[entry.key] = entry.value;
      }
      widget.onChanged(map);
      setState(() => _genStatus = 'Gerado: ${result.length}/${ids.length} emoções.');
    } catch (e) {
      setState(() => _genStatus = 'Erro: $e');
    } finally {
      setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedEmotionId != null
        ? widget.playerEmotions[_selectedEmotionId]
        : null;
    final selectedDef =
      _selectedEmotionId != null ? _emotions[_selectedEmotionId!] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wheel + controls
        SizedBox(
          width: 460,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Roda de Emoções',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (DialogueAiService.instance.hasApiKey)
                      _generating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton.icon(
                              onPressed: _generateAll,
                              icon: const Icon(Icons.auto_awesome, size: 14),
                              label: const Text('Gerar tudo', style: TextStyle(fontSize: 12)),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                  ],
                ),
                if (_genStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_genStatus,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'Clica numa emoção para ativar/editar. '
                  'Anel interior = fraco, exterior = forte.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 16),
                // The actual wheel
                _EmotionWheel(
                  playerEmotions: widget.playerEmotions,
                  selectedId: _selectedEmotionId,
                  onTap: (id) {
                    if (!widget.playerEmotions.containsKey(id)) {
                      _toggleEmotion(id);
                    } else {
                      _selectEmotion(id);
                    }
                  },
                  onDoubleTap: _toggleEmotion,
                ),
                const SizedBox(height: 12),
                // Legend
                Wrap(
                  spacing: 16,
                  children: [
                    _legendItem(AppColors.primary, 'Ativo'),
                    _legendItem(AppColors.border, 'Inativo'),
                    _legendItem(AppColors.teal, 'Tem texto'),
                  ],
                ),
                const SizedBox(height: 12),
                // Active emotion list
                if (widget.playerEmotions.isNotEmpty) ...[
                  const Text('Ativas:',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: widget.playerEmotions.keys.map((id) {
                      final def = _emotions[id];
                      final hasText = (widget.playerEmotions[id]?.playerLine.isNotEmpty ?? false) ||
                          (widget.playerEmotions[id]?.npcResponse.isNotEmpty ?? false);
                      return ActionChip(
                        label: Text(def.name,
                            style: const TextStyle(fontSize: 11)),
                        avatar: CircleAvatar(
                            backgroundColor: def.color, radius: 5),
                        backgroundColor: hasText
                            ? AppColors.tealDim.withValues(alpha: 0.3)
                            : AppColors.surfaceHighlight,
                        side: BorderSide(
                            color: _selectedEmotionId == id
                                ? AppColors.primary
                                : AppColors.border),
                        onPressed: () => _selectEmotion(id),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Vertical divider
        const VerticalDivider(width: 1, color: AppColors.border),
        // Branch editor panel
        Expanded(
          child: selectedDef != null
              ? _BranchEditor(
                  key: ValueKey(_selectedEmotionId),
                  emotionDef: selectedDef,
                  branch: selected ??
                      PlayerEmotionBranch(emotionId: selectedDef.id),
                  npcName: widget.charIds.isNotEmpty
                      ? widget.chars
                          .firstWhere((c) => c.id == widget.charIds.first,
                              orElse: () => widget.chars.first)
                          .name
                      : 'NPC',
                  topic: widget.topicCtrl.text,
                  onChanged: _updateBranch,
                  onRemove: () => _toggleEmotion(selectedDef.id),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text('Clica numa emoção na roda',
                          style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                          '${widget.playerEmotions.length} emoções ativas',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Emotion wheel widget (circular)
// ─────────────────────────────────────────────────────────────────────────────

class _EmotionWheel extends StatelessWidget {
  const _EmotionWheel({
    required this.playerEmotions,
    required this.selectedId,
    required this.onTap,
    required this.onDoubleTap,
  });

  final Map<int, PlayerEmotionBranch> playerEmotions;
  final int? selectedId;
  final void Function(int) onTap;
  final void Function(int) onDoubleTap;

  static const _size = 560.0;
  static const _cx = _size / 2;
  static const _cy = _size / 2;
  static const _dotRadius = 20.0;
  static const _padding = 26.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          // Background rings
          CustomPaint(
            size: const Size(_size, _size),
            painter: _WheelPainter(scale: (_size / 2) - _dotRadius - _padding),
          ),
          // Emotion dots
          ..._emotions.map((e) {
            final scale = (_size / 2) - _dotRadius - _padding;
            final angle = (2 * math.pi * e.id / _emotions.length) - (math.pi / 2);
            final x = _cx + (math.cos(angle) * scale);
            final y = _cy + (math.sin(angle) * scale);
            final isActive = playerEmotions.containsKey(e.id);
            final isSelected = selectedId == e.id;
            final hasText = isActive &&
                ((playerEmotions[e.id]?.playerLine.isNotEmpty ?? false) ||
                    (playerEmotions[e.id]?.npcResponse.isNotEmpty ?? false));

            return Positioned(
              left: x - _dotRadius,
              top: y - _dotRadius,
              child: Tooltip(
                message: '${e.name}\n'
                    '${isActive ? "Duplo-click para desativar" : "Click para ativar"}',
                child: GestureDetector(
                  onTap: () => onTap(e.id),
                  onDoubleTap: () => onDoubleTap(e.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: _dotRadius * 2,
                    height: _dotRadius * 2,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (hasText
                              ? AppColors.teal.withValues(alpha: 0.9)
                              : AppColors.primary.withValues(alpha: 0.85))
                          : e.color.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : (isActive ? AppColors.primary : e.color),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                    child: Center(
                      child: hasText
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : Text(
                              e.name.substring(0, 2),
                              style: TextStyle(
                                color: isActive ? Colors.white : e.color,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            );
          }),
          // Center label
          Positioned(
            left: _cx - 40,
            top: _cy - 15,
            width: 80,
            child: Text(
              selectedId != null ? _emotions[selectedId!].name : 'Roda',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.scale});

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.stroke;

    // Outer ring guide
    paint.color = AppColors.border;
    paint.strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), scale + 10, paint);

    // Inner ring guide
    canvas.drawCircle(Offset(cx, cy), (scale * 0.6) + 6, paint);

    // Axis lines
    paint.color = AppColors.border.withValues(alpha: 0.4);
    canvas.drawLine(Offset(cx - scale, cy), Offset(cx + scale, cy), paint);
    canvas.drawLine(Offset(cx, cy - scale), Offset(cx, cy + scale), paint);

    // Center dot
    paint.style = PaintingStyle.fill;
    paint.color = AppColors.border;
    canvas.drawCircle(Offset(cx, cy), 4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Branch editor panel (right side of playerChat editor)
// ─────────────────────────────────────────────────────────────────────────────

class _BranchEditor extends StatefulWidget {
  const _BranchEditor({
    super.key,
    required this.emotionDef,
    required this.branch,
    required this.npcName,
    required this.topic,
    required this.onChanged,
    required this.onRemove,
  });
  final _EmotionDef emotionDef;
  final PlayerEmotionBranch branch;
  final String npcName;
  final String topic;
  final void Function(PlayerEmotionBranch) onChanged;
  final VoidCallback onRemove;

  @override
  State<_BranchEditor> createState() => _BranchEditorState();
}

class _BranchEditorState extends State<_BranchEditor> {
  late TextEditingController _playerCtrl;
  late TextEditingController _npcCtrl;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _playerCtrl = TextEditingController(text: widget.branch.playerLine);
    _npcCtrl = TextEditingController(text: widget.branch.npcResponse);
  }

  @override
  void dispose() {
    _playerCtrl.dispose();
    _npcCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onChanged(widget.branch.copyWith(
      playerLine: _playerCtrl.text.trim(),
      npcResponse: _npcCtrl.text.trim(),
    ));
  }

  Future<void> _generateThis() async {
    setState(() => _generating = true);
    try {
      final result = await DialogueAiService.instance.generateEmotionBranches(
        emotionIds: [widget.emotionDef.id],
        topic: widget.topic.isNotEmpty ? widget.topic : 'conversa',
        npcName: widget.npcName,
      );
      final branch = result[widget.emotionDef.id];
      if (branch != null) {
        _playerCtrl.text = branch.playerLine;
        _npcCtrl.text = branch.npcResponse;
        _save();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro AI: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.emotionDef;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emotion header
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: def.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                def.name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                'Posicao no circulo',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const Spacer(),
              if (_generating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (DialogueAiService.instance.hasApiKey)
                FilledButton.icon(
                  onPressed: _generateThis,
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Gerar', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: widget.onRemove,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: const Text('Desativar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Emocoes distribuidas em circulo.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Player line
          const Text('Linha do jogador',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _playerCtrl,
            decoration: InputDecoration(
              hintText: 'O que o jogador diz com emoção "${def.name}"...',
              prefixIcon: const Icon(Icons.person_outline,
                  size: 16, color: AppColors.textMuted),
            ),
            maxLines: 3,
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 20),

          // NPC response
          Text('Resposta de ${widget.npcName}',
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _npcCtrl,
            decoration: InputDecoration(
              hintText: '${widget.npcName} responde...',
              prefixIcon: const Icon(Icons.chat_bubble_outline,
                  size: 16, color: AppColors.textMuted),
            ),
            maxLines: 3,
            onChanged: (_) => _save(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// API key button (AppBar)
// ─────────────────────────────────────────────────────────────────────────────

class _AiKeyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hasKey = DialogueAiService.instance.hasApiKey;
    return Tooltip(
      message: hasKey ? 'AI configurada' : 'Configurar chave AI (OpenRouter)',
      child: IconButton(
        icon: Icon(
          hasKey ? Icons.key : Icons.key_off_outlined,
          size: 18,
          color: hasKey ? AppColors.teal : AppColors.textMuted,
        ),
        onPressed: () => _showKeyDialog(context),
      ),
    );
  }

  void _showKeyDialog(BuildContext context) {
    final ctrl =
        TextEditingController(text: DialogueAiService.instance.apiKey);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chave API OpenRouter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Obtem uma chave em openrouter.ai/keys',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'OPENROUTER_API_KEY'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ou define a variável de ambiente OPENROUTER_API_KEY, '
              'ou coloca no project.json na raiz do projeto.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              DialogueAiService.instance.setApiKey(ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conditions section (reused for preconditions + consequences)
// ─────────────────────────────────────────────────────────────────────────────

class _ConditionsSection extends StatelessWidget {
  const _ConditionsSection({
    required this.title,
    required this.flags,
    required this.conditions,
    required this.onChanged,
  });
  final String title;
  final List<StateFlag> flags;
  final Map<int, bool> conditions;
  final void Function(Map<int, bool>) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            if (flags.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  final unused =
                      flags.where((f) => !conditions.containsKey(f.id)).toList();
                  if (unused.isEmpty) return;
                  final m = Map<int, bool>.from(conditions);
                  m[unused.first.id] = false;
                  onChanged(m);
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        if (conditions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('—',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          )
        else
          ...conditions.entries.map((entry) {
            final flag = flags.firstWhere((f) => f.id == entry.key,
                orElse: () => StateFlag(id: entry.key, name: 'Flag ${entry.key}', value: false));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(flag.name,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  ToggleButtons(
                    isSelected: [entry.value == false, entry.value == true],
                    onPressed: (i) {
                      final m = Map<int, bool>.from(conditions);
                      m[entry.key] = i == 1;
                      onChanged(m);
                    },
                    constraints:
                        const BoxConstraints(minHeight: 26, minWidth: 40),
                    children: const [
                      Text('F', style: TextStyle(fontSize: 11)),
                      Text('T', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () {
                      final m = Map<int, bool>.from(conditions);
                      m.remove(entry.key);
                      onChanged(m);
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _hexColorOrWhite(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return Colors.white;
  }
}
