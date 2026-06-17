import 'package:flutter/material.dart';

import '../../data/testing_checklist.dart';
import '../../domain/blueprint_editor.dart';
import '../app_theme.dart';
import '../game/settings_screen.dart';
import '../../models/dialogue.dart';
import '../../models/event.dart';
import '../../models/state_flag.dart';
import 'add_dialogue_screen.dart';
import 'add_event_screen.dart';
import 'add_state_flag_screen.dart';
import 'area_graph_screen.dart';
import 'character_relationship_screen.dart';
import 'dialogue_group_screen.dart';

class EditorMain extends StatelessWidget {
  const EditorMain({
    super.key,
    required this.editor,
    required this.onPlay,
    this.onSave,
    this.onBack,
  });

  final BlueprintEditor editor;
  final VoidCallback onPlay;
  final VoidCallback? onSave;
  final VoidCallback? onBack;

  static const _tabs = [
    (icon: Icons.map_outlined, label: 'Areas'),
    (icon: Icons.person_outline, label: 'Personagens'),
    (icon: Icons.toggle_on_outlined, label: 'Gamestates'),
    (icon: Icons.folder_outlined, label: 'Grupos'),
    (icon: Icons.chat_bubble_outline, label: 'Dialogos'),
    (icon: Icons.bolt_outlined, label: 'Eventos'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_stories,
                  size: 16,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Editor de Historia'),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabs
                .map(
                  (t) => Tab(
                    height: 42,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 15),
                        const SizedBox(width: 6),
                        Text(t.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            if (onBack != null) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_outlined, size: 20),
                tooltip: 'Mudar save',
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: 'Definições',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: 10),
            if (onSave != null)
              OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Guardar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Jogar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            AreaGraphScreen(editor: editor),
            CharacterRelationshipScreen(editor: editor),
            _StateFlagTab(editor: editor),
            DialogueGroupScreen(editor: editor),
            _DialogueTab(editor: editor),
            _EventTab(editor: editor),
          ],
        ),
      ),
    );
  }
}


// ---------- State Flags ----------

class _StateFlagTab extends StatelessWidget {
  const _StateFlagTab({required this.editor});
  final BlueprintEditor editor;

  @override
  Widget build(BuildContext context) {
    final items = editor.gamestates.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _EntityList<StateFlag>(
      items: items,
      label: (s) => s.name,
      subtitle: (s) => 'inicial: ${s.value}',
      trailing: (s) => Icon(
        s.value ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 16,
        color: s.value ? Colors.green : Colors.white38,
      ),
      onAdd: () async {
        final result = await Navigator.push<StateFlag>(
          context,
          MaterialPageRoute(builder: (_) => AddStateFlagScreen(editor: editor)),
        );
        if (result != null) {
          editor.addStateFlag(result);
          TestingChecklist.instance.mark('create_gamestate');
        }
      },
      onEdit: (s) async {
        final result = await Navigator.push<StateFlag>(
          context,
          MaterialPageRoute(
            builder: (_) => AddStateFlagScreen(editor: editor, existing: s),
          ),
        );
        if (result != null) editor.updateStateFlag(result);
      },
      onDelete: (s) => _confirmDeleteStateFlag(context, editor, s),
    );
  }
}

// ---------- Dialogues ----------

class _DialogueTab extends StatefulWidget {
  const _DialogueTab({required this.editor});
  final BlueprintEditor editor;

  @override
  State<_DialogueTab> createState() => _DialogueTabState();
}

class _DialogueTabState extends State<_DialogueTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor({Dialogue? existing}) async {
    final result = await Navigator.push<Dialogue>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDialogueScreen(editor: widget.editor, existing: existing),
      ),
    );
    if (result == null) return;
    if (existing != null) {
      widget.editor.updateDialogue(result);
      TestingChecklist.instance.mark('edit_dialogue');
    } else {
      widget.editor.addDialogue(result);
      TestingChecklist.instance.mark('create_dialogue');
    }
  }

  void _delete(Dialogue d) {
    _confirmDelete(context, d.name, () {
      widget.editor.removeDialogue(d.id);
      TestingChecklist.instance.mark('delete_entity');
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.editor.dialogues.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final filtered = _query.isEmpty
        ? all
        : all.where((d) => d.name.toLowerCase().contains(_query)).toList();

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _search,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar diálogos…',
                      prefixIcon: const Icon(Icons.search, size: 16,
                          color: AppColors.textMuted),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 14),
                              color: AppColors.textMuted,
                              onPressed: () => _search.clear(),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${filtered.length}/${all.length}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        // ── List ────────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty ? 'Sem diálogos' : 'Sem resultados',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _query.isEmpty
                            ? 'Clica "Novo" para criar o primeiro diálogo.'
                            : 'Tenta outro termo de pesquisa.',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _DialogueCard(
                    dialogue: filtered[i],
                    editor: widget.editor,
                    onEdit: () => _openEditor(existing: filtered[i]),
                    onDelete: () => _delete(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DialogueCard extends StatelessWidget {
  const _DialogueCard({
    required this.dialogue,
    required this.editor,
    required this.onEdit,
    required this.onDelete,
  });

  final Dialogue dialogue;
  final BlueprintEditor editor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = dialogue;

    // Resolve metadata
    final areaName = d.areaIds.isEmpty
        ? null
        : d.areaIds
            .map((id) => editor.areas[id]?.name ?? 'área $id')
            .join(', ');
    final group = d.groupId != null ? editor.groups[d.groupId] : null;
    final isEntry = group != null &&
        group.orderedDialogueIds.isNotEmpty &&
        group.orderedDialogueIds.first == d.id;
    final charCount = d.characterIds.length;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: d.isEnding
                ? AppColors.accent.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left icon
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 12),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: d.isEnding
                      ? AppColors.accent.withOpacity(0.15)
                      : AppColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: d.isEnding
                        ? AppColors.accent.withOpacity(0.35)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  d.isEnding
                      ? Icons.flag_outlined
                      : Icons.chat_bubble_outline,
                  size: 16,
                  color: d.isEnding
                      ? AppColors.accentLight
                      : AppColors.textSecondary,
                ),
              ),
            ),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Tags row
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      if (areaName != null)
                        _TagBadge(
                          icon: Icons.map_outlined,
                          label: 'Área: $areaName',
                          color: AppColors.teal,
                          dimColor: AppColors.tealDim.withOpacity(0.3),
                        ),
                      if (group != null)
                        _TagBadge(
                          icon: isEntry ? Icons.key_outlined : Icons.account_tree_outlined,
                          label: isEntry
                              ? 'Entrada: ${group.name}'
                              : 'Grupo: ${group.name}',
                          color: AppColors.primaryLight,
                          dimColor: AppColors.primaryDim,
                        ),
                      if (d.singleTrigger)
                        const _TagBadge(
                          icon: Icons.looks_one_outlined,
                          label: 'Disparo único',
                          color: Color(0xFFA78BFA),
                          dimColor: Color(0xFF1E1040),
                        ),
                      if (d.isEnding)
                        _TagBadge(
                          icon: Icons.flag_outlined,
                          label: 'Fim do jogo',
                          color: AppColors.accentLight,
                          dimColor: AppColors.accent.withOpacity(0.15),
                        ),
                      if (d.priority != 0)
                        _TagBadge(
                          icon: Icons.low_priority,
                          label: 'Prioridade ${d.priority}',
                          color: const Color(0xFFFB923C),
                          dimColor: const Color(0xFF431407),
                        ),
                      if (d.topic != null)
                        _TagBadge(
                          icon: Icons.label_outline,
                          label: d.topic!,
                          color: const Color(0xFF94A3B8),
                          dimColor: const Color(0xFF1E293B),
                        ),
                      if (charCount > 0)
                        _TagBadge(
                          icon: Icons.people_outline,
                          label: '$charCount personagem${charCount == 1 ? '' : 'ns'}',
                          color: AppColors.success,
                          dimColor: AppColors.success.withOpacity(0.12),
                        ),
                    ],
                  ),
                  // Preconditions
                  if (d.preconditions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _FlagRow(
                      prefix: 'Requer',
                      prefixIcon: Icons.lock_outline,
                      prefixColor: AppColors.warning,
                      flags: d.preconditions,
                      gamestates: editor.gamestates,
                    ),
                  ],
                  // Consequences
                  if (d.consequences.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _FlagRow(
                      prefix: 'Define',
                      prefixIcon: Icons.output_outlined,
                      prefixColor: AppColors.success,
                      flags: d.consequences,
                      gamestates: editor.gamestates,
                      isOutput: true,
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  color: AppColors.textSecondary,
                  tooltip: 'Editar',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 15),
                  color: AppColors.error,
                  tooltip: 'Eliminar',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({
    required this.label,
    required this.color,
    required this.dimColor,
    this.icon,
  });

  final String label;
  final Color color;
  final Color dimColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: dimColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Events ----------

class _EventTab extends StatelessWidget {
  const _EventTab({required this.editor});
  final BlueprintEditor editor;

  @override
  Widget build(BuildContext context) {
    final items = editor.events.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _EntityList<Event>(
      items: items,
      label: (e) => e.name,
      subtitle: (e) => e.type.name,
      onAdd: () async {
        final result = await Navigator.push<Event>(
          context,
          MaterialPageRoute(builder: (_) => AddEventScreen(editor: editor)),
        );
        if (result != null) {
          editor.addEvent(result);
          TestingChecklist.instance.mark('create_event');
        }
      },
      onEdit: (e) async {
        final result = await Navigator.push<Event>(
          context,
          MaterialPageRoute(
            builder: (_) => AddEventScreen(editor: editor, existing: e),
          ),
        );
        if (result != null) {
          editor.removeEvent(e.id);
          editor.addEvent(result);
          TestingChecklist.instance.mark('edit_event');
        }
      },
      onDelete: (e) {
        editor.removeEvent(e.id);
        TestingChecklist.instance.mark('delete_entity');
      },
    );
  }
}

// ---------- Shared helpers ----------

void _confirmDeleteStateFlag(
    BuildContext context, BlueprintEditor editor, StateFlag flag) {
  final affected = editor.dialoguesForStateFlag(flag.id);
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: affected.isEmpty
          ? const Text('Eliminar gamestate?')
          : Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 22),
                const SizedBox(width: 8),
                const Text('Eliminar gamestate?'),
              ],
            ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Eliminar "${flag.name}"?'),
          if (affected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Esta flag é usada em ${affected.length} diálogo${affected.length == 1 ? '' : 's'} (precondições/consequências). Será removida de todos automaticamente.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: affected
                      .map((d) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(d.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: affected.isEmpty ? null : AppColors.warning),
          onPressed: () {
            Navigator.pop(context);
            editor.removeStateFlagClean(flag.id);
            TestingChecklist.instance.mark('delete_entity');
          },
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}

void _confirmDelete(BuildContext context, String name, VoidCallback onConfirm) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Eliminar?'),
      content: Text('Eliminar "$name"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}

// ---------- Generic list widget ----------

class _EntityList<T> extends StatelessWidget {
  const _EntityList({
    required this.items,
    required this.label,
    required this.onAdd,
    required this.onDelete,
    this.subtitle,
    this.trailing,
    this.onEdit,
  });

  final List<T> items;
  final String Function(T) label;
  final String Function(T)? subtitle;
  final Widget? Function(T)? trailing;
  final VoidCallback onAdd;
  final void Function(T) onDelete;
  final void Function(T)? onEdit;

  static const double _cardWidth = 260;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Text(
                '${items.length}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sem entradas',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Clica em "Novo" para adicionar',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = (constraints.maxWidth - 40)
                        .clamp(200.0, _cardWidth)
                        .toDouble();
                    final textScale = MediaQuery.textScaleFactorOf(context);
                    final rowHeight = 104 * textScale;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: maxWidth,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: rowHeight,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final t = trailing?.call(item);
                        return _EntityCard(
                          label: label(item),
                          subtitle: subtitle?.call(item),
                          trailing: t,
                          onEdit: onEdit != null ? () => onEdit!(item) : null,
                          onDelete: () => _confirmDelete(
                            context,
                            label(item),
                            () => onDelete(item),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------- Entity card ----------

class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.label,
    required this.onDelete,
    this.subtitle,
    this.trailing,
    this.onEdit,
  });

  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: AppColors.textSecondary,
                onPressed: onEdit,
                tooltip: 'Editar',
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              color: AppColors.error,
              onPressed: onDelete,
              tooltip: 'Eliminar',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Flag row ----------

class _FlagRow extends StatelessWidget {
  const _FlagRow({
    required this.prefix,
    required this.prefixIcon,
    required this.prefixColor,
    required this.flags,
    required this.gamestates,
    this.isOutput = false,
  });

  final String prefix;
  final IconData prefixIcon;
  final Color prefixColor;
  final Map<int, bool> flags;
  final Map<int, StateFlag> gamestates;
  final bool isOutput;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(prefixIcon, size: 11, color: prefixColor),
              const SizedBox(width: 3),
              Text(
                '$prefix:',
                style: TextStyle(
                  fontSize: 10,
                  color: prefixColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 3,
            children: flags.entries.map((e) {
              final name = gamestates[e.key]?.name ?? 'flag#${e.key}';
              final on = e.value;
              final color = on ? AppColors.success : AppColors.error;
              final dimColor = on
                  ? AppColors.success.withOpacity(0.10)
                  : AppColors.error.withOpacity(0.10);
              final valueIcon = isOutput
                  ? (on ? Icons.arrow_circle_up_outlined : Icons.arrow_circle_down_outlined)
                  : (on ? Icons.check_circle_outline : Icons.cancel_outlined);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: dimColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(valueIcon, size: 11, color: color),
                    const SizedBox(width: 3),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

