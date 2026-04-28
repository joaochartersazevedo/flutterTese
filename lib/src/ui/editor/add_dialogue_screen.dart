import 'package:flutter/material.dart';

import '../../domain/blueprint_editor.dart';
import '../../models/character.dart';
import '../../models/dialogue.dart';
import '../../models/emotion.dart';
import '../../models/state_flag.dart';
import '../app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR HELPER
// ─────────────────────────────────────────────────────────────────────────────

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
  late int _priority;
  late Map<int, bool> _preconditions;
  late Map<int, bool> _consequences;

  // ── tree ──────────────────────────────────────────────────────────────────
  late DialogueNode _root;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _selectedCharIds = ex != null ? List.of(ex.characterIds) : [];
    _singleTrigger = ex?.singleTrigger ?? false;
    _selfRemove = ex?.selfRemove ?? false;
    _priority = ex?.priority ?? 0;
    _preconditions = ex != null ? Map.of(ex.preconditions) : {};
    _consequences = ex != null ? Map.of(ex.consequences) : {};
    _root = ex?.parentNode ??
        DialogueNode(line: DialogueLine(speakerId: 0, text: ''));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  List<Character> get _chars => widget.editor.characters.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  List<StateFlag> get _flags => widget.editor.gamestates.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nome obrigatório')));
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
    );
    Navigator.pop(context, d);
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title:
            Text(widget.existing == null ? 'Novo Diálogo' : 'Editar Diálogo'),
        actions: [
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Guardar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                selectedCharIds: _selectedCharIds,
                singleTrigger: _singleTrigger,
                selfRemove: _selfRemove,
                priority: _priority,
                preconditions: _preconditions,
                consequences: _consequences,
                onChanged: (charIds, st, sr, prio, pre, cons) =>
                    setState(() {
                  _selectedCharIds = charIds;
                  _singleTrigger = st;
                  _selfRemove = sr;
                  _priority = prio;
                  _preconditions = pre;
                  _consequences = cons;
                }),
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
                      horizontal: 20, vertical: 10),
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
    required this.selectedCharIds,
    required this.singleTrigger,
    required this.selfRemove,
    required this.priority,
    required this.preconditions,
    required this.consequences,
    required this.onChanged,
  });

  final TextEditingController nameCtrl;
  final List<Character> chars;
  final List<StateFlag> flags;
  final List<int> selectedCharIds;
  final bool singleTrigger;
  final bool selfRemove;
  final int priority;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;
  final void Function(
    List<int>,
    bool,
    bool,
    int,
    Map<int, bool>,
    Map<int, bool>,
  ) onChanged;

  @override
  State<_MetaPanel> createState() => _MetaPanelState();
}

class _MetaPanelState extends State<_MetaPanel> {
  late List<int> _charIds;
  late bool _st, _sr;
  late int _prio;
  late Map<int, bool> _pre, _cons;

  @override
  void initState() {
    super.initState();
    _charIds = List.of(widget.selectedCharIds);
    _st = widget.singleTrigger;
    _sr = widget.selfRemove;
    _prio = widget.priority;
    _pre = Map.of(widget.preconditions);
    _cons = Map.of(widget.consequences);
  }

  void _notify() =>
      widget.onChanged(_charIds, _st, _sr, _prio, _pre, _cons);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Nome'),
        TextField(
          controller: widget.nameCtrl,
          decoration: const InputDecoration(hintText: 'Nome do diálogo'),
        ),
        const SizedBox(height: 16),

        _sectionLabel('Personagens'),
        if (widget.chars.isEmpty)
          const Text('Sem personagens',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.chars.map((c) {
              final sel = _charIds.contains(c.id);
              return FilterChip(
                label:
                    Text(c.name, style: const TextStyle(fontSize: 12)),
                selected: sel,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _charIds.add(c.id);
                    } else {
                      _charIds.remove(c.id);
                    }
                  });
                  _notify();
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 16),

        _sectionLabel('Opções'),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Disparo único',
              style: TextStyle(fontSize: 13)),
          value: _st,
          onChanged: (v) {
            setState(() => _st = v);
            _notify();
          },
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Remover após disparar',
              style: TextStyle(fontSize: 13)),
          value: _sr,
          onChanged: (v) {
            setState(() => _sr = v);
            _notify();
          },
        ),
        const SizedBox(height: 12),

        _sectionLabel('Prioridade'),
        Row(
          children: [
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
              width: 28,
              child: Text('$_prio',
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),

        if (widget.flags.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionLabel('Pré-condições'),
          ...widget.flags.map((f) => _FlagRow(
                name: f.name,
                value: _pre[f.id],
                onChanged: (v) {
                  setState(() {
                    if (v == null) {
                      _pre.remove(f.id);
                    } else {
                      _pre[f.id] = v;
                    }
                  });
                  _notify();
                },
              )),
          const SizedBox(height: 16),
          _sectionLabel('Consequências'),
          ...widget.flags.map((f) => _FlagRow(
                name: f.name,
                value: _cons[f.id],
                onChanged: (v) {
                  setState(() {
                    if (v == null) {
                      _cons.remove(f.id);
                    } else {
                      _cons[f.id] = v;
                    }
                  });
                  _notify();
                },
              )),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// FLAG ROW  (tri-state toggle: null = any, true = must-be-true, false = must-be-false)
// ─────────────────────────────────────────────────────────────────────────────

class _FlagRow extends StatelessWidget {
  const _FlagRow({
    required this.name,
    required this.value,
    required this.onChanged,
  });

  final String name;
  final bool? value;
  final void Function(bool?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(name, style: const TextStyle(fontSize: 12))),
          ToggleButtons(
            isSelected: [value == true, value == null, value == false],
            onPressed: (i) =>
                onChanged(i == 0 ? true : i == 2 ? false : null),
            borderRadius: BorderRadius.circular(6),
            constraints:
                const BoxConstraints(minHeight: 28, minWidth: 36),
            children: const [
              Icon(Icons.check, size: 13, color: Colors.green),
              Icon(Icons.remove, size: 13),
              Icon(Icons.close, size: 13, color: Colors.red),
            ],
          ),
        ],
      ),
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
    required this.onChanged,
    this.onRemoveSelf,
    this.emotionId,
  });

  final DialogueNode root;
  final List<Character> chars;
  final VoidCallback onChanged;
  final VoidCallback? onRemoveSelf;
  final int? emotionId;

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

    _branchKeys.removeWhere(
        (k, _) => !sortedEntries.any((e) => e.key == k));
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
            onChanged: widget.onChanged,
            onRemoveSelf: widget.onRemoveSelf,
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
                                parentChoiceNode: widget.root,
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
                    line: DialogueLine(speakerId: 0, text: ''));
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
    required this.parentChoiceNode,
    required this.onChanged,
  });

  final int emotionId;
  final DialogueNode branchRoot;
  final List<Character> chars;
  final DialogueNode parentChoiceNode;
  final VoidCallback onChanged;

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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
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
                  child: Icon(Icons.close,
                      size: 12,
                      color: color.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _TreeView(
            root: branchRoot,
            chars: chars,
            onChanged: onChanged,
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
    final available =
        emotionWheel.where((e) => !existing.contains(e.id)).toList();
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
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          label:
              Text('+ ${e.label}', style: const TextStyle(fontSize: 11)),
          onPressed: () {
            node.children ??= {};
            node.children![e.id] = DialogueNode(
                line: DialogueLine(speakerId: 0, text: ''));
            onChanged();
          },
          backgroundColor: color.withValues(alpha: 0.07),
          side:
              BorderSide(color: color.withValues(alpha: 0.35)),
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
    required this.onChanged,
    this.onRemoveSelf,
  });

  final DialogueNode node;
  final List<Character> chars;
  final VoidCallback onChanged;
  final VoidCallback? onRemoveSelf;

  @override
  State<_NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<_NodeCard> {
  late final TextEditingController _textCtrl;

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
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10)),
                border: Border(
                    left:
                        BorderSide(color: accentColor, width: 3)),
              ),
              child: Row(
                children: [
                  Icon(
                    isLine
                        ? Icons.chat_bubble_outline
                        : Icons.alt_route,
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
                        child: Icon(Icons.swap_horiz,
                            size: 14,
                            color: AppColors.textMuted),
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
                          child: Icon(Icons.delete_outline,
                              size: 14, color: AppColors.error),
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
          ],
        ),
      ),
    );
  }

  Widget _lineBody() {
    final validChars = widget.chars;
    final speakerId = widget.node.line?.speakerId ?? 0;
    final resolvedId =
        validChars.any((c) => c.id == speakerId)
            ? speakerId
            : validChars.isNotEmpty
                ? validChars.first.id
                : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (validChars.isNotEmpty)
          DropdownButtonFormField<int>(
            value: resolvedId,
            decoration: const InputDecoration(
              labelText: 'Personagem',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: validChars
                .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name,
                        style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) {
              setState(() {
                widget.node.line ??=
                    DialogueLine(speakerId: 0, text: '');
                widget.node.line!.speakerId = v ?? 0;
              });
              widget.onChanged();
            },
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _textCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Texto do diálogo…',
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: (v) {
            widget.node.line ??=
                DialogueLine(speakerId: 0, text: '');
            widget.node.line!.text = v;
            widget.onChanged();
          },
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
          .map((id) => Chip(
                label: Text(_emotionName(id),
                    style: const TextStyle(fontSize: 11)),
                avatar: CircleAvatar(
                    backgroundColor: _emotionColor(id),
                    radius: 5),
                padding: EdgeInsets.zero,
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
              ))
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
          ..style = PaintingStyle.fill);
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
          paint);
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
  const _AddNodeButtons({
    required this.onAddLine,
    required this.onAddChoice,
  });

  final VoidCallback onAddLine;
  final VoidCallback onAddChoice;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _btn(Icons.chat_bubble_outline, 'Fala', AppColors.primary,
              onAddLine),
          const SizedBox(width: 8),
          _btn(Icons.alt_route, 'Escolha', AppColors.accent,
              onAddChoice),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String label, Color color,
      VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 13),
      label:
          Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
