import 'package:flutter/material.dart';

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
    required this.onPlaySeed,
    required this.onLoadSeed,
    this.onBack,
  });

  final BlueprintEditor editor;
  final VoidCallback onPlay;
  final VoidCallback onPlaySeed;
  final VoidCallback onLoadSeed;
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
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: onPlaySeed,
              icon: const Icon(Icons.download_outlined, size: 15),
              label: const Text('Seed'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Jogar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: TabBarView(
          children: [
            AreaGraphScreen(editor: editor, onLoadSeed: onLoadSeed),
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
        if (result != null) editor.addStateFlag(result);
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
      onDelete: (s) => editor.removeStateFlag(s.id),
    );
  }
}

// ---------- Dialogues ----------

class _DialogueTab extends StatelessWidget {
  const _DialogueTab({required this.editor});
  final BlueprintEditor editor;

  @override
  Widget build(BuildContext context) {
    final items = editor.dialogues.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _EntityList<Dialogue>(
      items: items,
      label: (d) => d.name,
      onAdd: () async {
        final result = await Navigator.push<Dialogue>(
          context,
          MaterialPageRoute(builder: (_) => AddDialogueScreen(editor: editor)),
        );
        if (result != null) editor.addDialogue(result);
      },
      onEdit: (d) async {
        final result = await Navigator.push<Dialogue>(
          context,
          MaterialPageRoute(
            builder: (_) => AddDialogueScreen(editor: editor, existing: d),
          ),
        );
        if (result != null) editor.updateDialogue(result);
      },
      onDelete: (d) => editor.removeDialogue(d.id),
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
        if (result != null) editor.addEvent(result);
      },
      onDelete: (e) => editor.removeEvent(e.id),
    );
  }
}

// ---------- Shared helpers ----------

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: onAdd,
        tooltip: 'Adicionar',
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
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
                    'Clica + para adicionar',
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
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

