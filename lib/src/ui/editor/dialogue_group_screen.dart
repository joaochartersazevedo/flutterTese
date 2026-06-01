import 'package:flutter/material.dart';

import '../../domain/blueprint_editor.dart';
import '../../models/dialogue.dart';
import '../../models/dialogue_group.dart';
import '../app_theme.dart';

class DialogueGroupScreen extends StatefulWidget {
  const DialogueGroupScreen({super.key, required this.editor});
  final BlueprintEditor editor;

  @override
  State<DialogueGroupScreen> createState() => _DialogueGroupScreenState();
}

class _DialogueGroupScreenState extends State<DialogueGroupScreen> {
  void _addGroup() async {
    final name = await _nameDialog(context, '');
    if (name == null || name.isEmpty) return;
    widget.editor.addGroup(
      DialogueGroup(id: widget.editor.nextGroupId(), name: name),
    );
  }

  void _editGroup(DialogueGroup g) async {
    final name = await _nameDialog(context, g.name);
    if (name == null || name.isEmpty) return;
    widget.editor.updateGroup(DialogueGroup(id: g.id, name: name));
  }

  Future<void> _manageMembers(DialogueGroup g) async {
    final allDialogues = widget.editor.dialogues.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    await showDialog<void>(
      context: context,
      builder: (ctx) => _MembersDialog(
        group: g,
        dialogues: allDialogues,
        editor: widget.editor,
      ),
    );
    setState(() {}); // refresh card after dialog closes
  }

  void _removeGroup(DialogueGroup g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover grupo?'),
        content: Text(
          'Remover "${g.name}"? Os diálogos associados ficarão sem grupo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm == true) widget.editor.removeGroup(g.id);
  }

  Future<String?> _nameDialog(BuildContext ctx, String initial) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Nome do grupo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: Arco da Ana'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.editor.groups.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final dialogues = widget.editor.dialogues;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Text(
                '${groups.length} grupo${groups.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addGroup,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo Grupo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'Sem grupos',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cria um grupo para encadear diálogos sequencialmente.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: groups.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    final orderedIds = g.orderedDialogueIds;
                    final ordered = orderedIds
                        .map((id) => dialogues[id])
                        .whereType<Dialogue>()
                        .toList();
                    final entryDialogue = ordered.isNotEmpty ? ordered.first : null;
                    final rest = ordered.length > 1 ? ordered.sublist(1) : <Dialogue>[];

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _manageMembers(g),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryDim,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.account_tree_outlined,
                                      size: 16,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          g.name,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          ordered.isEmpty
                                              ? 'Sem diálogos — toca para adicionar'
                                              : '${ordered.length} diálogo${ordered.length == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    color: AppColors.textSecondary,
                                    tooltip: 'Renomear grupo',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _editGroup(g),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    color: AppColors.error,
                                    tooltip: 'Remover grupo',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _removeGroup(g),
                                  ),
                                ],
                              ),
                            ),
                            // Flow preview
                            if (entryDialogue != null) ...[
                              const Divider(height: 1, color: AppColors.border),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                                child: _FlowPreview(
                                  entry: entryDialogue,
                                  rest: rest,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Flow preview widget (entry → d2 → d3 …)
// ---------------------------------------------------------------------------

class _FlowPreview extends StatelessWidget {
  const _FlowPreview({required this.entry, required this.rest});
  final Dialogue entry;
  final List<Dialogue> rest;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 6,
      children: [
        _entryChip(entry),
        for (final d in rest) ...[
          const Icon(Icons.arrow_forward, size: 12, color: AppColors.textMuted),
          _seqChip(d),
        ],
      ],
    );
  }

  Widget _entryChip(Dialogue d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.key_outlined, size: 11, color: AppColors.primaryLight),
          const SizedBox(width: 4),
          Text(
            d.name,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _seqChip(Dialogue d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        d.name,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Members dialog
// ---------------------------------------------------------------------------

class _MembersDialog extends StatefulWidget {
  const _MembersDialog({
    required this.group,
    required this.dialogues,
    required this.editor,
  });

  final DialogueGroup group;
  final List<Dialogue> dialogues;
  final BlueprintEditor editor;

  @override
  State<_MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends State<_MembersDialog> {
  late List<int> _order;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = List.from(
      widget.editor.groups[widget.group.id]?.orderedDialogueIds ?? [],
    );
  }

  Dialogue? _dialogue(int id) => widget.editor.dialogues[id];

  void _toggle(int dialogueId, bool add) {
    if (add) {
      final err = widget.editor.groupJoinError(dialogueId, widget.group.id);
      if (err != null) {
        setState(() => _error = err);
        return;
      }
    }
    setState(() => _error = null);
    widget.editor.setDialogueGroup(dialogueId, add ? widget.group.id : null);
    setState(() {
      _order = List.from(
        widget.editor.groups[widget.group.id]?.orderedDialogueIds ?? [],
      );
    });
  }

  void _reorderSequence(int oldIndex, int newIndex) {
    // Sequence list is _order[1..]. Map back to full order indices.
    final seqOld = oldIndex + 1;
    var seqNew = newIndex + 1;
    if (seqNew > seqOld) seqNew--;
    setState(() {
      final id = _order.removeAt(seqOld);
      _order.insert(seqNew, id);
    });
    widget.editor.reorderGroupDialogues(widget.group.id, _order);
  }

  void _setAsEntry(int dialogueId) {
    final idx = _order.indexOf(dialogueId);
    if (idx <= 0) return;
    setState(() {
      _order.removeAt(idx);
      _order.insert(0, dialogueId);
    });
    widget.editor.reorderGroupDialogues(widget.group.id, _order);
  }

  @override
  Widget build(BuildContext context) {
    final entryId = _order.isNotEmpty ? _order.first : null;
    final entryDialogue = entryId != null ? _dialogue(entryId) : null;
    final seqIds = _order.length > 1 ? _order.sublist(1) : <int>[];
    final seqMembers = seqIds.map(_dialogue).whereType<Dialogue>().toList();
    final nonMembers = widget.dialogues
        .where((d) => !_order.contains(d.id))
        .toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.account_tree_outlined,
              size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.group.name,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              // ── Entry dialogue ──────────────────────────────────
              _sectionLabel('DIÁLOGO DE ENTRADA'),
              const SizedBox(height: 4),
              _entryHint(),
              const SizedBox(height: 8),
              if (entryDialogue != null)
                _EntryCard(
                  dialogue: entryDialogue,
                  onRemove: () => _toggle(entryDialogue.id, false),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.25),
                        style: BorderStyle.solid),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.key_outlined,
                          size: 16, color: AppColors.textMuted),
                      SizedBox(width: 8),
                      Text('Nenhum diálogo de entrada definido',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── Sequence ────────────────────────────────────────
              _sectionLabel('SEQUÊNCIA APÓS ENTRADA'),
              const SizedBox(height: 4),
              _seqHint(seqMembers.isEmpty),
              const SizedBox(height: 8),

              if (seqMembers.isNotEmpty)
                SizedBox(
                  height: (seqMembers.length * 52.0).clamp(52, 240),
                  child: ReorderableListView.builder(
                    itemCount: seqMembers.length,
                    onReorder: _reorderSequence,
                    buildDefaultDragHandles: false,
                    itemBuilder: (_, i) {
                      final d = seqMembers[i];
                      return _SeqTile(
                        key: ValueKey(d.id),
                        dialogue: d,
                        index: i,
                        onSetEntry: () => _setAsEntry(d.id),
                        onRemove: () => _toggle(d.id, false),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),

              // ── Add dialogues ───────────────────────────────────
              if (nonMembers.isNotEmpty) ...[
                _sectionLabel('ADICIONAR AO GRUPO'),
                const SizedBox(height: 6),
                ...nonMembers.map(
                  (d) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.chat_bubble_outline,
                          size: 13, color: AppColors.textMuted),
                    ),
                    title: Text(d.name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: d.areaIds.isNotEmpty
                        ? Text(d.areaIds.map((a) => 'área $a').join(', '),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted))
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          size: 18, color: AppColors.teal),
                      onPressed: () => _toggle(d.id, true),
                      tooltip: 'Adicionar ao grupo',
                    ),
                  ),
                ),
              ],

              if (widget.dialogues.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sem diálogos criados.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.1,
        ),
      );

  Widget _entryHint() => const Text(
        'As precondições deste diálogo controlam quando o grupo dispara. '
        'Arrasta na sequência para promover um diálogo a entrada.',
        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
      );

  Widget _seqHint(bool empty) => Text(
        empty
            ? 'Adiciona mais diálogos ao grupo para definir a sequência.'
            : 'Quando a entrada terminar, dispara o primeiro desta lista cujas '
                'precondições estejam cumpridas — os restantes são ignorados nessa ronda. '
                'Arrasta para definir prioridade.',
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      );
}

// ---------------------------------------------------------------------------
// Entry card
// ---------------------------------------------------------------------------

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.dialogue, required this.onRemove});
  final Dialogue dialogue;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryDim,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: const Icon(Icons.key_outlined,
            size: 18, color: AppColors.primaryLight),
        title: Text(
          dialogue.name,
          style: const TextStyle(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: dialogue.areaIds.isNotEmpty
            ? Text(dialogue.areaIds.map((a) => 'área $a').join(', '),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted))
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline,
              size: 16, color: AppColors.error),
          onPressed: onRemove,
          tooltip: 'Remover do grupo',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sequence tile
// ---------------------------------------------------------------------------

class _SeqTile extends StatelessWidget {
  const _SeqTile({
    super.key,
    required this.dialogue,
    required this.index,
    required this.onSetEntry,
    required this.onRemove,
  });
  final Dialogue dialogue;
  final int index;
  final VoidCallback onSetEntry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.drag_handle,
                  size: 16, color: AppColors.textMuted),
            ),
          ),
          Text(
            '${index + 2}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
      title: Text(dialogue.name, style: const TextStyle(fontSize: 13)),
      subtitle: dialogue.areaIds.isNotEmpty
          ? Text(dialogue.areaIds.map((a) => 'área $a').join(', '),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Definir como entrada do grupo',
            child: IconButton(
              icon: const Icon(Icons.key_outlined,
                  size: 15, color: AppColors.primaryLight),
              onPressed: onSetEntry,
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                size: 15, color: AppColors.error),
            onPressed: onRemove,
            tooltip: 'Remover do grupo',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
