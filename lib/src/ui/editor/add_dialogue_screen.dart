import 'package:flutter/material.dart';

import '../../data/dialogue_ai_service.dart';
import '../../domain/blueprint_editor.dart';
import '../../models/area.dart';
import '../../models/character.dart';
import '../../models/dialogue.dart';
import '../../models/dialogue_group.dart';
import '../../models/emotion.dart';
import '../../models/state_flag.dart';
import '../app_theme.dart';
import '../game/settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR HELPER
// ─────────────────────────────────────────────────────────────────────────────

void _showError(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Erro AI'),
      content: SelectableText(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}

Color _hex(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return Colors.white;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMOTION HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _emotionName(int id) =>
    emotionWheel.where((e) => e.id == id).firstOrNull?.label ?? 'E$id';

Color _emotionColor(int id) {
  final e = emotionWheel.where((e) => e.id == id).firstOrNull;
  return e != null ? _hex(e.color) : Colors.white;
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD DIALOGUE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AddDialogueScreen extends StatefulWidget {
  const AddDialogueScreen({super.key, required this.editor, this.existing});

  final BlueprintEditor editor;
  final Dialogue? existing;

  @override
  State<AddDialogueScreen> createState() => _AddDialogueScreenState();
}

class _AddDialogueScreenState extends State<AddDialogueScreen> {
  // ── metadata ──────────────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late List<int> _selectedCharIds;
  late bool _singleTrigger;
  late bool _selfRemove;
  late bool _isEnding;
  late int _priority;
  late Map<int, bool> _preconditions;
  late Map<int, bool> _consequences;
  int? _groupId;
  int? _areaId;

  // ── tree ──────────────────────────────────────────────────────────────────
  late DialogueNode _root;
  int _activeSpeakerId = 0;

  bool _generating = false;
  String _genStatus = '';

  Future<void> _generateFullDialogue() async {
    if (!DialogueAiService.instance.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura a chave AI primeiro')),
      );
      return;
    }
    final allChars = _chars;
    final params = await showDialog<_GenFullParams>(
      context: context,
      builder: (_) => _GenerateFullDialogueDialog(
        chars: allChars,
        preselectedCharIds: _selectedCharIds,
      ),
    );
    if (params == null || !mounted) return;

    final selectedChars = params.selectedCharIds.isEmpty
        ? allChars
        : allChars.where((c) => params.selectedCharIds.contains(c.id)).toList();

    setState(() {
      _generating = true;
      _genStatus = 'A gerar…';
    });
    try {
      final charNames = selectedChars.isEmpty
          ? ['NPC']
          : selectedChars.map((c) => c.name).toList();
      final lines = await DialogueAiService.instance.generateDialogueTree(
        characterNames: charNames,
        topic: params.topic,
        numLines: params.numLines,
        characters: allChars,
      );
      final nameToId = {
        for (final c in selectedChars) c.name.toLowerCase(): c.id,
      };
      final npcNodes = lines.map((l) {
        final id =
            nameToId[l.speaker.toLowerCase()] ??
            (selectedChars.isNotEmpty ? selectedChars.first.id : 0);
        return DialogueNode(
          line: DialogueLine(speakerId: id, text: l.text),
        );
      }).toList();

      // If emotions selected: fetch player lines and interleave choice nodes.
      final List<DialogueNode> allNodes;
      if (params.selectedEmotionIds.isNotEmpty && npcNodes.isNotEmpty) {
        setState(() => _genStatus = 'A gerar emoções…');
        final npcName = selectedChars.isNotEmpty
            ? selectedChars.first.name
            : 'NPC';
        final emotionChoices = await DialogueAiService.instance
            .generatePlayerLines(
              emotionIds: params.selectedEmotionIds,
              topic: params.topic,
              npcName: npcName,
            );
        allNodes = [];
        for (var i = 0; i < npcNodes.length; i++) {
          allNodes.add(npcNodes[i]);
          // Insert choice node after every NPC line except the last.
          if (i < npcNodes.length - 1) {
            allNodes.add(
              DialogueNode(
                choice: DialogueChoice(choices: Map.from(emotionChoices)),
              ),
            );
          }
        }
      } else {
        allNodes = npcNodes;
      }

      for (var i = 0; i < allNodes.length - 1; i++) {
        allNodes[i].nextNode = allNodes[i + 1];
      }
      setState(() {
        _root = allNodes.isNotEmpty
            ? allNodes.first
            : DialogueNode(line: DialogueLine(speakerId: 0, text: ''));
        _genStatus = 'Gerado: ${lines.length} linhas.';
        _generating = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _genStatus = 'Erro — ver detalhes';
          _generating = false;
        });
        _showError(context, '$e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _selectedCharIds = ex != null ? List.of(ex.characterIds) : [];
    _singleTrigger = ex?.singleTrigger ?? false;
    _selfRemove = ex?.selfRemove ?? false;
    _isEnding = ex?.isEnding ?? false;
    _priority = ex?.priority ?? 0;
    _preconditions = ex != null ? Map.of(ex.preconditions) : {};
    _consequences = ex != null ? Map.of(ex.consequences) : {};
    _groupId = ex?.groupId;
    _areaId = ex?.areaId;
    _root =
        ex?.parentNode ??
        DialogueNode(line: DialogueLine(speakerId: 0, text: ''));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  List<Character> get _chars =>
      widget.editor.characters.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  List<StateFlag> get _flags =>
      widget.editor.gamestates.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nome obrigatório')));
      return;
    }
    final id = widget.existing?.id ?? widget.editor.nextDialogueId();
    final d = Dialogue(
      id: id,
      name: _nameCtrl.text.trim(),
      characterIds: _selectedCharIds,
      parentNode: _root,
      singleTrigger: _singleTrigger,
      preconditions: _preconditions,
      consequences: _consequences,
      selfRemove: _selfRemove,
      priority: _priority,
      areaId: _areaId,
      isEnding: _isEnding,
      groupId: _groupId,
    );
    Navigator.pop(context, d);
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Novo Diálogo' : 'Editar Diálogo',
        ),
        actions: [
          if (_genStatus.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _genStatus,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Definições',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          _AiKeyButton(),
          const SizedBox(width: 4),
          _generating
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Tooltip(
                  message: 'Gerar diálogo com AI',
                  child: OutlinedButton.icon(
                    onPressed: _generateFullDialogue,
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('Gerar', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Guardar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT — metadata form
          SizedBox(
            width: 300,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: _MetaPanel(
                nameCtrl: _nameCtrl,
                chars: _chars,
                flags: _flags,
                groups: widget.editor.groups.values.toList()
                  ..sort((a, b) => a.id.compareTo(b.id)),
                selectedCharIds: _selectedCharIds,
                singleTrigger: _singleTrigger,
                selfRemove: _selfRemove,
                isEnding: _isEnding,
                priority: _priority,
                preconditions: _preconditions,
                consequences: _consequences,
                groupId: _groupId,
                areaId: _areaId,
                areas: widget.editor.areas.values.toList()
                  ..sort((a, b) => a.id.compareTo(b.id)),
                activeSpeakerId: _activeSpeakerId,
                onChanged: (charIds, st, sr, ending, prio, pre, cons, gId, aId) =>
                    setState(() {
                  _selectedCharIds = charIds;
                  _singleTrigger = st;
                  _selfRemove = sr;
                  _isEnding = ending;
                  _priority = prio;
                  _preconditions = pre;
                  _consequences = cons;
                  _groupId = gId;
                  _areaId = aId;
                }),
                onActiveSpeakerChanged: (id) =>
                    setState(() => _activeSpeakerId = id),
              ),
            ),
          ),

          // RIGHT — tree
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  color: AppColors.surface,
                  child: Text(
                    'Árvore de diálogo',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(500),
                    minScale: 0.3,
                    maxScale: 2.0,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _TreeView(
                        root: _root,
                        chars: _chars,
                        flags: _flags,
                        activeSpeakerId: _activeSpeakerId,
                        onChanged: _refresh,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// META PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _MetaPanel extends StatefulWidget {
  const _MetaPanel({
    required this.nameCtrl,
    required this.chars,
    required this.flags,
    required this.groups,
    required this.areas,
    required this.selectedCharIds,
    required this.singleTrigger,
    required this.selfRemove,
    required this.isEnding,
    required this.priority,
    required this.preconditions,
    required this.consequences,
    required this.groupId,
    required this.areaId,
    required this.activeSpeakerId,
    required this.onChanged,
    required this.onActiveSpeakerChanged,
  });

  final TextEditingController nameCtrl;
  final List<Character> chars;
  final List<StateFlag> flags;
  final List<DialogueGroup> groups;
  final List<Area> areas;
  final List<int> selectedCharIds;
  final bool singleTrigger;
  final bool selfRemove;
  final bool isEnding;
  final int priority;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;
  final int? groupId;
  final int? areaId;
  final int activeSpeakerId;
  final void Function(
    List<int>,
    bool,
    bool,
    bool,
    int,
    Map<int, bool>,
    Map<int, bool>,
    int?,
    int?,
  )
  onChanged;
  final void Function(int speakerId) onActiveSpeakerChanged;

  @override
  State<_MetaPanel> createState() => _MetaPanelState();
}

class _MetaPanelState extends State<_MetaPanel> {
  late List<int> _charIds;
  late bool _st, _sr, _ending;
  late int _prio;
  late Map<int, bool> _pre, _cons;
  int? _groupId;
  int? _areaId;

  @override
  void initState() {
    super.initState();
    _charIds = List.of(widget.selectedCharIds);
    _st = widget.singleTrigger;
    _sr = widget.selfRemove;
    _ending = widget.isEnding;
    _prio = widget.priority;
    _pre = Map.of(widget.preconditions);
    _cons = Map.of(widget.consequences);
    _groupId = widget.groupId;
    _areaId = widget.areaId;
  }

  void _notify() =>
      widget.onChanged(_charIds, _st, _sr, _ending, _prio, _pre, _cons, _groupId, _areaId);

  void _addFlagCondition(Map<int, bool> map, bool defaultVal) {
    final available = widget.flags.where((f) => !map.containsKey(f.id)).toList();
    if (available.isEmpty) return;
    showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Escolher flag'),
        children: available
            .map((f) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, f.id),
                  child: Text(f.name),
                ))
            .toList(),
      ),
    ).then((id) {
      if (id == null) return;
      setState(() => map[id] = defaultVal);
      _notify();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // ── Name ────────────────────────────────────────────────────────────
        _SectionHeader(icon: Icons.title_outlined, label: 'Nome'),
        TextField(
          controller: widget.nameCtrl,
          decoration: const InputDecoration(hintText: 'Nome do diálogo'),
        ),
        const SizedBox(height: 16),

        // ── Characters ──────────────────────────────────────────────────────
        _SectionHeader(icon: Icons.people_outline, label: 'Personagens'),
        if (widget.chars.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Sem personagens',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          )
        else
          Column(
            children: widget.chars.map((c) {
              final inDialogue = _charIds.contains(c.id);
              final isActiveSpeaker = widget.activeSpeakerId == c.id;
              final charColor = _hex(c.colorHex);
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    if (inDialogue) {
                      _charIds.remove(c.id);
                    } else {
                      _charIds.add(c.id);
                    }
                  });
                  _notify();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: inDialogue
                        ? charColor.withValues(alpha: 0.08)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: inDialogue ? charColor.withValues(alpha: 0.35) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: charColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: inDialogue
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: inDialogue
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      // Active speaker toggle
                      Tooltip(
                        message: isActiveSpeaker
                            ? 'Narrador ativo'
                            : 'Definir como narrador',
                        child: GestureDetector(
                          onTap: () => widget.onActiveSpeakerChanged(c.id),
                          child: Icon(
                            isActiveSpeaker
                                ? Icons.mic
                                : Icons.mic_none_outlined,
                            size: 15,
                            color: isActiveSpeaker
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        inDialogue
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank,
                        size: 15,
                        color: inDialogue ? charColor : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),

        // ── Area restriction ────────────────────────────────────────────────
        if (widget.areas.isNotEmpty) ...[
          _SectionHeader(icon: Icons.map_outlined, label: 'Área'),
          DropdownButtonFormField<int?>(
            value: _areaId,
            decoration: const InputDecoration(
              hintText: 'Qualquer área',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Qualquer área', style: TextStyle(fontSize: 13)),
              ),
              ...widget.areas.map(
                (a) => DropdownMenuItem<int?>(
                  value: a.id,
                  child: Text(a.name, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() => _areaId = v);
              _notify();
            },
          ),
          const SizedBox(height: 16),
        ],

        // ── Group ────────────────────────────────────────────────────────────
        if (widget.groups.isNotEmpty) ...[
          _SectionHeader(icon: Icons.account_tree_outlined, label: 'Grupo'),
          DropdownButtonFormField<int?>(
            value: _groupId,
            decoration: const InputDecoration(
              hintText: 'Sem grupo',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Sem grupo', style: TextStyle(fontSize: 13)),
              ),
              ...widget.groups.map(
                (g) => DropdownMenuItem<int?>(
                  value: g.id,
                  child: Text(g.name, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() => _groupId = v);
              _notify();
            },
          ),
          const SizedBox(height: 16),
        ],

        // ── Options (collapsible) ────────────────────────────────────────────
        _CollapsibleSection(
          icon: Icons.tune_outlined,
          label: 'Opções',
          badge: [if (_st) 'único', if (_sr) 'auto-remove', if (_ending) 'fim', if (_prio > 0) 'P$_prio']
              .join(' · '),
          child: Column(
            children: [
              _OptionRow(
                label: 'Disparo único',
                value: _st,
                onChanged: (v) { setState(() => _st = v); _notify(); },
              ),
              _OptionRow(
                label: 'Remover após disparar',
                value: _sr,
                onChanged: (v) { setState(() => _sr = v); _notify(); },
              ),
              _OptionRow(
                label: 'Diálogo de fim',
                subtitle: 'Termina o jogo ao concluir',
                value: _ending,
                onChanged: (v) { setState(() => _ending = v); _notify(); },
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'Prioridade',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: Slider(
                      value: _prio.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: '$_prio',
                      onChanged: (v) {
                        setState(() => _prio = v.round());
                        _notify();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$_prio',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Preconditions ────────────────────────────────────────────────────
        if (widget.flags.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CollapsibleSection(
            icon: Icons.lock_outline,
            label: 'Pré-condições',
            badge: _pre.isEmpty ? '' : '${_pre.length}',
            badgeColor: AppColors.warning,
            child: _FlagChipEditor(
              flags: widget.flags,
              values: _pre,
              emptyHint: 'Sem condições — dispara sempre',
              onAdd: () => _addFlagCondition(_pre, true),
              onRemove: (id) {
                setState(() => _pre.remove(id));
                _notify();
              },
              onToggle: (id, v) {
                setState(() => _pre[id] = v);
                _notify();
              },
            ),
          ),
          const SizedBox(height: 12),
          _CollapsibleSection(
            icon: Icons.output_outlined,
            label: 'Consequências',
            badge: _cons.isEmpty ? '' : '${_cons.length}',
            badgeColor: AppColors.success,
            child: _FlagChipEditor(
              flags: widget.flags,
              values: _cons,
              emptyHint: 'Sem consequências',
              onAdd: () => _addFlagCondition(_cons, true),
              onRemove: (id) {
                setState(() => _cons.remove(id));
                _notify();
              },
              onToggle: (id, v) {
                setState(() => _cons[id] = v);
                _notify();
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// META PANEL HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.icon,
    required this.label,
    required this.child,
    this.badge = '',
    this.badgeColor,
    this.initiallyExpanded = true,
  });
  final IconData icon;
  final String label;
  final Widget child;
  final String badge;
  final Color? badgeColor;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(widget.icon, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  widget.label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
                if (widget.badge.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: (widget.badgeColor ?? AppColors.primary).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: widget.badgeColor ?? AppColors.primaryLight,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 6),
          widget.child,
        ],
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String label;
  final String? subtitle;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 11))
          : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _FlagChipEditor extends StatelessWidget {
  const _FlagChipEditor({
    required this.flags,
    required this.values,
    required this.emptyHint,
    required this.onAdd,
    required this.onRemove,
    required this.onToggle,
  });
  final List<StateFlag> flags;
  final Map<int, bool> values;
  final String emptyHint;
  final VoidCallback onAdd;
  final void Function(int id) onRemove;
  final void Function(int id, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final active = values.entries.toList();
    final flagName = {for (final f in flags) f.id: f.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              emptyHint,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: active.map((e) {
              final name = flagName[e.key] ?? 'Flag ${e.key}';
              final isTrue = e.value;
              return GestureDetector(
                onTap: () => onToggle(e.key, !isTrue),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTrue
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isTrue
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTrue ? Icons.check : Icons.close,
                        size: 11,
                        color: isTrue ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          color: isTrue ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => onRemove(e.key),
                        child: Icon(
                          Icons.close,
                          size: 10,
                          color: isTrue
                              ? AppColors.success.withValues(alpha: 0.7)
                              : AppColors.error.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 4),
        if (values.length < flags.length)
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 13),
            label: const Text('Adicionar', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TREE VIEW  (recursive)
// ─────────────────────────────────────────────────────────────────────────────

class _TreeView extends StatefulWidget {
  const _TreeView({
    required this.root,
    required this.chars,
    required this.flags,
    required this.onChanged,
    this.onRemoveSelf,
    this.emotionId,
    this.previousLines = const <String>[],
    this.rootLockedSpeakerId,
    this.activeSpeakerId = 0,
  });

  final DialogueNode root;
  final List<Character> chars;
  final List<StateFlag> flags;
  final VoidCallback onChanged;
  final VoidCallback? onRemoveSelf;
  final int? emotionId;
  final List<String> previousLines;
  /// If set, root NodeCard speaker is locked (no dropdown).
  final int? rootLockedSpeakerId;
  final int activeSpeakerId;

  @override
  State<_TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<_TreeView> {
  final _rowKey = GlobalKey();
  final Map<int, GlobalKey> _branchKeys = {};
  List<double> _branchCenters = [];

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _doMeasure();
    });
  }

  void _doMeasure() {
    final rowCtx = _rowKey.currentContext;
    if (rowCtx == null) return;
    final rowBox = rowCtx.findRenderObject() as RenderBox;

    final measures = <MapEntry<int, double>>[];
    for (final entry in _branchKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox;
      final local = rowBox.globalToLocal(box.localToGlobal(Offset.zero));
      measures.add(MapEntry(entry.key, local.dx + box.size.width / 2));
    }
    measures.sort((a, b) => a.key.compareTo(b.key));

    final centers = measures.map((e) => e.value).toList();
    if (mounted && !_listEq(centers, _branchCenters)) {
      setState(() => _branchCenters = centers);
    }
  }

  static bool _listEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final sortedEntries =
        widget.root.isChoice && (widget.root.children ?? {}).isNotEmpty
        ? (widget.root.children!.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
        : <MapEntry<int, DialogueNode>>[];

    _branchKeys.removeWhere((k, _) => !sortedEntries.any((e) => e.key == k));
    for (final entry in sortedEntries) {
      _branchKeys.putIfAbsent(entry.key, () => GlobalKey());
    }

    if (sortedEntries.isNotEmpty) _scheduleMeasure();

    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Node card ──────────────────────────────────────────────────
          _NodeCard(
            node: widget.root,
            chars: widget.chars,
            flags: widget.flags,
            previousLines: widget.previousLines,
            onChanged: widget.onChanged,
            onRemoveSelf: widget.onRemoveSelf,
            lockedSpeakerId: widget.rootLockedSpeakerId,
            emotionId: widget.emotionId,
          ),

          // ── Choice branches (side-by-side) ─────────────────────────────
          if (widget.root.isChoice) ...[
            const SizedBox(height: 8),
            _AddBranchBar(node: widget.root, onChanged: widget.onChanged),
            if (sortedEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Stack(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 28),
                      Row(
                        key: _rowKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < sortedEntries.length; i++) ...[
                            Container(
                              key: _branchKeys[sortedEntries[i].key],
                              child: _BranchColumn(
                                emotionId: sortedEntries[i].key,
                                branchRoot: sortedEntries[i].value,
                                chars: widget.chars,
                                flags: widget.flags,
                                parentChoiceNode: widget.root,
                                previousLines: widget.previousLines,
                                activeSpeakerId: widget.activeSpeakerId,
                                onChanged: widget.onChanged,
                              ),
                            ),
                            if (i < sortedEntries.length - 1)
                              const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 24,
                    child: CustomPaint(
                      painter: _ForkPainter(branchCenters: _branchCenters),
                    ),
                  ),
                ],
              ),
            ],
          ],

          // ── Linear next-node ───────────────────────────────────────────
          if (widget.root.nextNode != null) ...[
            _Connector(),
            _TreeView(
              root: widget.root.nextNode!,
              chars: widget.chars,
              flags: widget.flags,
              activeSpeakerId: widget.activeSpeakerId,
              previousLines: [
                ...widget.previousLines,
                if (widget.root.line != null) widget.root.line!.text,
              ],
              onChanged: widget.onChanged,
              onRemoveSelf: () {
                widget.root.nextNode = widget.root.nextNode!.nextNode;
                widget.onChanged();
              },
            ),
          ] else if (!widget.root.isChoice) ...[
            _Connector(),
            _AddNodeButtons(
              onAddLine: () {
                widget.root.nextNode = DialogueNode(
                  line: DialogueLine(
                      speakerId: widget.activeSpeakerId, text: ''),
                );
                widget.onChanged();
              },
              onAddChoice: () {
                widget.root.nextNode = DialogueNode(choice: DialogueChoice());
                widget.onChanged();
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRANCH COLUMN
// ─────────────────────────────────────────────────────────────────────────────

class _BranchColumn extends StatelessWidget {
  const _BranchColumn({
    required this.emotionId,
    required this.branchRoot,
    required this.chars,
    required this.flags,
    required this.parentChoiceNode,
    required this.onChanged,
    this.previousLines = const <String>[],
    this.activeSpeakerId = 0,
  });

  final int emotionId;
  final DialogueNode branchRoot;
  final List<Character> chars;
  final List<StateFlag> flags;
  final DialogueNode parentChoiceNode;
  final VoidCallback onChanged;
  final List<String> previousLines;
  final int activeSpeakerId;

  @override
  Widget build(BuildContext context) {
    final color = _emotionColor(emotionId);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
        ),
      ),
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emotion label chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _emotionName(emotionId),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    parentChoiceNode.children?.remove(emotionId);
                    onChanged();
                  },
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Player line label — first node of every branch is always the player speaking
          if (branchRoot.isLine && branchRoot.line!.speakerId == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 11, color: Color(0xFF00CC44)),
                  const SizedBox(width: 4),
                  Text(
                    'linha do jogador',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          _TreeView(
            root: branchRoot,
            chars: chars,
            flags: flags,
            activeSpeakerId: activeSpeakerId,
            previousLines: previousLines,
            onChanged: onChanged,
            rootLockedSpeakerId:
                (branchRoot.isLine && branchRoot.line!.speakerId == 0) ? 0 : null,
            onRemoveSelf: () {
              parentChoiceNode.children?.remove(emotionId);
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD BRANCH BAR
// ─────────────────────────────────────────────────────────────────────────────

class _AddBranchBar extends StatelessWidget {
  const _AddBranchBar({required this.node, required this.onChanged});

  final DialogueNode node;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final existing = node.children?.keys.toSet() ?? {};
    final available = emotionWheel
        .where((e) => !existing.contains(e.id))
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: available.map((e) {
        final color = _hex(e.color);
        return ActionChip(
          avatar: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          label: Text('+ ${e.label}', style: const TextStyle(fontSize: 11)),
          onPressed: () {
            node.choice ??= DialogueChoice();
            node.choice!.choices.putIfAbsent(e.id, () => '');
            node.children ??= {};
            node.children![e.id] = DialogueNode(
              line: DialogueLine(speakerId: 0, text: ''),
            );
            onChanged();
          },
          backgroundColor: color.withValues(alpha: 0.07),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NODE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NodeCard extends StatefulWidget {
  const _NodeCard({
    required this.node,
    required this.chars,
    required this.flags,
    required this.onChanged,
    this.onRemoveSelf,
    this.previousLines = const <String>[],
    this.lockedSpeakerId,
    this.emotionId,
  });

  final DialogueNode node;
  final List<Character> chars;
  final List<StateFlag> flags;
  final VoidCallback onChanged;
  final VoidCallback? onRemoveSelf;
  final List<String> previousLines;
  /// When set, speaker is fixed — dropdown hidden, shows read-only label.
  final int? lockedSpeakerId;
  /// Emotion context for AI line generation (branch emotion).
  final int? emotionId;

  @override
  State<_NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<_NodeCard> {
  late final TextEditingController _textCtrl;
  bool _suggestingLine = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.node.line?.text ?? '');
  }

  @override
  void didUpdateWidget(covariant _NodeCard old) {
    super.didUpdateWidget(old);
    final newText = widget.node.line?.text ?? '';
    if (_textCtrl.text != newText) _textCtrl.text = newText;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Character _speaker() {
    final id = widget.node.line?.speakerId ?? 0;
    if (id == 0) {
      return const Character(
        id: 0,
        name: 'Jogador',
        colorHex: '#00cc44',
        portraitPath: '',
        areaId: 0,
        bodyPath: '',
      );
    }
    return widget.chars.firstWhere(
      (c) => c.id == id,
      orElse: () => widget.chars.isNotEmpty
          ? widget.chars.first
          : const Character(
              id: 0,
              name: 'NPC',
              colorHex: '#ffffff',
              portraitPath: '',
              areaId: 0,
              bodyPath: '',
            ),
    );
  }

  void _toggleType() {
    if (widget.node.isLine) {
      widget.node.line = null;
      widget.node.choice = DialogueChoice();
    } else {
      widget.node.choice = null;
      widget.node.children = null;
      widget.node.line = DialogueLine(speakerId: 0, text: '');
    }
    widget.onChanged();
  }

  Future<void> _suggestLine() async {
    if (!DialogueAiService.instance.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura a chave AI primeiro')),
      );
      return;
    }
    final ctxCtrl = TextEditingController(text: _textCtrl.text);
    final userCtx = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Sugerir linha com AI'),
        content: TextField(
          controller: ctxCtrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Contexto / pista',
            hintText: 'ex: fala sobre o exame de amanhã',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dlgCtx, ctxCtrl.text.trim()),
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
    if (userCtx == null || !mounted) return;

    setState(() => _suggestingLine = true);
    try {
      final speaker = _speaker();
      final history = widget.previousLines.isNotEmpty
          ? widget.previousLines.join('\n')
          : _textCtrl.text;
      final emotionLabel = widget.emotionId != null
          ? _emotionName(widget.emotionId!)
          : null;
      final contextWithEmotion = [
        if (emotionLabel != null) 'Express the emotion: $emotionLabel.',
        if (userCtx.isNotEmpty) userCtx,
        if (userCtx.isEmpty && emotionLabel == null) 'conversa geral',
      ].join(' ');
      final suggested = await DialogueAiService.instance.suggestLine(
        speakerName: speaker.name,
        context: contextWithEmotion,
        previousLine: history,
        speaker: speaker,
        allChars: widget.chars,
      );
      if (!mounted) return;
      if (suggested.isEmpty) {
        setState(() => _suggestingLine = false);
        _showError(context, 'AI devolveu resposta vazia. Verifica a chave e o modelo.');
        return;
      }
      setState(() {
        _textCtrl.text = suggested;
        widget.node.line ??= DialogueLine(speakerId: 0, text: '');
        widget.node.line!.text = suggested;
        _suggestingLine = false;
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => _suggestingLine = false);
        _showError(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLine = widget.node.isLine;
    final Color accentColor = isLine
        ? _hex(_speaker().colorHex)
        : AppColors.accent;

    return SizedBox(
      width: 320,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLine
                ? AppColors.border
                : AppColors.accent.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                border: Border(left: BorderSide(color: accentColor, width: 3)),
              ),
              child: Row(
                children: [
                  Icon(
                    isLine ? Icons.chat_bubble_outline : Icons.alt_route,
                    size: 13,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLine ? 'FALA' : 'ESCOLHA',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: isLine
                        ? 'Converter em escolha'
                        : 'Converter em fala',
                    child: InkWell(
                      onTap: _toggleType,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onRemoveSelf != null) ...[
                    const SizedBox(width: 2),
                    Tooltip(
                      message: 'Remover nó',
                      child: InkWell(
                        onTap: widget.onRemoveSelf,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(10),
              child: isLine ? _lineBody() : _choiceBody(),
            ),

            // Branch consequences — only on leaf line nodes
            if (isLine &&
                widget.node.nextNode == null &&
                widget.flags.isNotEmpty)
              _BranchFlagsSection(
                node: widget.node,
                flags: widget.flags,
                onChanged: widget.onChanged,
              ),
          ],
        ),
      ),
    );
  }

  Widget _lineBody() {
    final validChars = widget.chars;
    final speakerId = widget.node.line?.speakerId ?? 0;
    final resolvedId = validChars.any((c) => c.id == speakerId)
        ? speakerId
        : validChars.isNotEmpty
        ? validChars.first.id
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.lockedSpeakerId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.lock, size: 12, color: Colors.white38),
                const SizedBox(width: 6),
                Text(
                  validChars
                          .where((c) => c.id == widget.lockedSpeakerId)
                          .firstOrNull
                          ?.name ??
                      'Jogador',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          )
        else if (validChars.isNotEmpty)
          DropdownButtonFormField<int>(
            value: resolvedId,
            decoration: const InputDecoration(
              labelText: 'Personagem',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: validChars
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                widget.node.line ??= DialogueLine(speakerId: 0, text: '');
                widget.node.line!.speakerId = v ?? 0;
              });
              widget.onChanged();
            },
          ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Texto do diálogo…',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) {
                    widget.node.line ??= DialogueLine(speakerId: 0, text: '');
                    widget.node.line!.text = v;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Sugerir com AI',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: _suggestingLine ? null : _suggestLine,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: _suggestingLine
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              )
                            : const Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: AppColors.accent,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_suggestingLine) ...[
                const SizedBox(width: 6),
                const Text(
                  'A pensar…',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceBody() {
    final active = widget.node.children?.keys ?? [];
    if (active.isEmpty) {
      return const Text(
        'Sem ramos definidos.\nUsa os chips abaixo para adicionar emoções.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: active
          .map(
            (id) => Chip(
              label: Text(
                _emotionName(id),
                style: const TextStyle(fontSize: 11),
              ),
              avatar: CircleAvatar(
                backgroundColor: _emotionColor(id),
                radius: 5,
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONNECTOR  (thin vertical line between successive nodes)
// ─────────────────────────────────────────────────────────────────────────────

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 24,
      child: CustomPaint(painter: _VLinePainter()),
    );
  }
}

class _VLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1.5,
    );
    // Arrow tip
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx, size.height)
      ..lineTo(cx - 5, size.height - 7)
      ..lineTo(cx + 5, size.height - 7)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ForkPainter extends CustomPainter {
  const _ForkPainter({required this.branchCenters});

  final List<double> branchCenters;

  @override
  void paint(Canvas canvas, Size size) {
    if (branchCenters.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5;

    final parentCx = size.width / 2;
    final midY = size.height * 0.5;

    canvas.drawLine(Offset(parentCx, 0), Offset(parentCx, midY), paint);

    if (branchCenters.length == 1) {
      canvas.drawLine(
        Offset(branchCenters.first, midY),
        Offset(branchCenters.first, size.height),
        paint,
      );
      return;
    }

    canvas.drawLine(
      Offset(branchCenters.first, midY),
      Offset(branchCenters.last, midY),
      paint,
    );
    for (final cx in branchCenters) {
      canvas.drawLine(Offset(cx, midY), Offset(cx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForkPainter old) {
    if (old.branchCenters.length != branchCenters.length) return true;
    for (var i = 0; i < branchCenters.length; i++) {
      if (old.branchCenters[i] != branchCenters[i]) return true;
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD NODE BUTTONS
// ─────────────────────────────────────────────────────────────────────────────

class _AddNodeButtons extends StatelessWidget {
  const _AddNodeButtons({required this.onAddLine, required this.onAddChoice});

  final VoidCallback onAddLine;
  final VoidCallback onAddChoice;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _btn(Icons.chat_bubble_outline, 'Fala', AppColors.primary, onAddLine),
          const SizedBox(width: 8),
          _btn(Icons.alt_route, 'Escolha', AppColors.accent, onAddChoice),
        ],
      ),
    );
  }

  Widget _btn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 13),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRANCH FLAGS SECTION  (shown on leaf line nodes inside _NodeCard)
// ─────────────────────────────────────────────────────────────────────────────

class _BranchFlagsSection extends StatefulWidget {
  const _BranchFlagsSection({
    required this.node,
    required this.flags,
    required this.onChanged,
  });

  final DialogueNode node;
  final List<StateFlag> flags;
  final VoidCallback onChanged;

  @override
  State<_BranchFlagsSection> createState() => _BranchFlagsSectionState();
}

class _BranchFlagsSectionState extends State<_BranchFlagsSection> {
  @override
  Widget build(BuildContext context) {
    final cons = widget.node.branchConsequences;
    final unused = widget.flags.where((f) => !cons.containsKey(f.id)).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 12, color: AppColors.teal),
              const SizedBox(width: 4),
              const Text(
                'FLAGS DO RAMO',
                style: TextStyle(
                  color: AppColors.teal,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              if (unused.isNotEmpty)
                PopupMenuButton<int>(
                  tooltip: 'Adicionar flag',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add, size: 14, color: AppColors.teal),
                  onSelected: (id) {
                    setState(() => widget.node.branchConsequences[id] = true);
                    widget.onChanged();
                  },
                  itemBuilder: (_) => unused
                      .map(
                        (f) => PopupMenuItem(
                          value: f.id,
                          child: Text(
                            f.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
          if (cons.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Sem flags neste ramo.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            )
          else
            ...cons.entries.map((entry) {
              final flag = widget.flags.firstWhere(
                (f) => f.id == entry.key,
                orElse: () => StateFlag(
                  id: entry.key,
                  name: 'Flag ${entry.key}',
                  value: false,
                ),
              );
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        flag.name,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ToggleButtons(
                      isSelected: [!entry.value, entry.value],
                      onPressed: (i) {
                        setState(
                          () => widget.node.branchConsequences[entry.key] =
                              i == 1,
                        );
                        widget.onChanged();
                      },
                      constraints: const BoxConstraints(
                        minHeight: 24,
                        minWidth: 36,
                      ),
                      children: const [
                        Text('OFF', style: TextStyle(fontSize: 9)),
                        Text('ON', style: TextStyle(fontSize: 9)),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        setState(
                          () =>
                              widget.node.branchConsequences.remove(entry.key),
                        );
                        widget.onChanged();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI KEY BUTTON
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
    final ctrl = TextEditingController(text: DialogueAiService.instance.apiKey);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chave API OpenRouter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Obtém uma chave em openrouter.ai/keys',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'OPENROUTER_API_KEY',
              ),
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
// GENERATE FULL DIALOGUE DIALOG + PARAMS
// ─────────────────────────────────────────────────────────────────────────────

class _GenFullParams {
  const _GenFullParams({
    required this.topic,
    required this.numLines,
    required this.selectedCharIds,
    required this.selectedEmotionIds,
  });
  final String topic;
  final int numLines;
  final List<int> selectedCharIds;
  final List<int> selectedEmotionIds;
}

class _GenerateFullDialogueDialog extends StatefulWidget {
  const _GenerateFullDialogueDialog({
    required this.chars,
    required this.preselectedCharIds,
  });
  final List<Character> chars;
  final List<int> preselectedCharIds;

  @override
  State<_GenerateFullDialogueDialog> createState() =>
      _GenerateFullDialogueDialogState();
}

class _GenerateFullDialogueDialogState
    extends State<_GenerateFullDialogueDialog> {
  final _topicCtrl = TextEditingController();
  int _numLines = 4;
  late Set<int> _selCharIds;
  late Set<int> _selEmotionIds;

  @override
  void initState() {
    super.initState();
    _selCharIds = widget.preselectedCharIds.isNotEmpty
        ? Set.of(widget.preselectedCharIds)
        : widget.chars.map((c) => c.id).toSet();
    _selEmotionIds = emotionWheel.map((e) => e.id).toSet();
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gerar Diálogo com AI'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── char selection ────────────────────────────────────────────
              const Text(
                'Personagens',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              if (widget.chars.isEmpty)
                const Text(
                  'Sem personagens no diálogo',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.chars.map((c) {
                    final sel = _selCharIds.contains(c.id);
                    return FilterChip(
                      label: Text(c.name, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selCharIds.add(c.id);
                        } else {
                          _selCharIds.remove(c.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              // ── topic ─────────────────────────────────────────────────────
              TextField(
                controller: _topicCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tópico da conversa',
                  hintText: 'ex: próximo exame, amizade, segredo',
                ),
              ),
              const SizedBox(height: 16),
              // ── num lines ─────────────────────────────────────────────────
              Row(
                children: [
                  const Text('Linhas NPC:', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _numLines.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$_numLines',
                      onChanged: (v) => setState(() => _numLines = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$_numLines',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── emotion selection ─────────────────────────────────────────
              const Text(
                'Emoções do jogador (deixar vazio = sem escolha)',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              _EmotionSelectionGrid(
                selected: _selEmotionIds,
                onToggle: (id) => setState(() {
                  if (_selEmotionIds.contains(id)) {
                    _selEmotionIds.remove(id);
                  } else {
                    _selEmotionIds.add(id);
                  }
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (_topicCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Escreve um tópico para a conversa.')),
              );
              return;
            }
            Navigator.pop(
              context,
              _GenFullParams(
                topic: _topicCtrl.text.trim(),
                numLines: _numLines,
                selectedCharIds: _selCharIds.toList(),
                selectedEmotionIds: _selEmotionIds.toList(),
              ),
            );
          },
          icon: const Icon(Icons.auto_awesome, size: 14),
          label: const Text('Gerar'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMOTION SELECTION GRID (3×3)
// ─────────────────────────────────────────────────────────────────────────────

class _EmotionSelectionGrid extends StatelessWidget {
  const _EmotionSelectionGrid({required this.selected, required this.onToggle});
  final Set<int> selected;
  final void Function(int id) onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 3.2,
      children: emotionWheel.map((e) {
        final sel = selected.contains(e.id);
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onToggle(e.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              color: sel
                  ? _emotionColor(e.id).withOpacity(0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: sel
                    ? _emotionColor(e.id)
                    : AppColors.textMuted.withOpacity(0.3),
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Text(
              e.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: sel ? _emotionColor(e.id) : AppColors.textMuted,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
