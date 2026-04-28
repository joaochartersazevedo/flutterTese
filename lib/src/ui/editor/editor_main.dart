import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/renpy_asset_resolver.dart';
import '../../domain/blueprint_editor.dart';
import '../app_theme.dart';
import '../../models/area.dart';
import '../../models/character.dart';
import '../../models/connection.dart';
import '../../models/dialogue.dart';
import '../../models/event.dart';
import '../../models/state_flag.dart';
import '../../models/task.dart';
import 'add_area_screen.dart';
import 'add_character_screen.dart';
import 'add_connection_screen.dart';
import 'add_dialogue_screen.dart';
import 'add_event_screen.dart';
import 'add_state_flag_screen.dart';
import 'add_task_screen.dart';

class EditorMain extends StatelessWidget {
  const EditorMain({
    super.key,
    required this.editor,
    required this.onPlay,
    required this.onPlaySeed,
  });

  final BlueprintEditor editor;
  final VoidCallback onPlay;
  final VoidCallback onPlaySeed;

  static const _tabs = [
    (icon: Icons.map_outlined, label: 'Areas'),
    (icon: Icons.link, label: 'Conexoes'),
    (icon: Icons.person_outline, label: 'Personagens'),
    (icon: Icons.toggle_on_outlined, label: 'Gamestates'),
    (icon: Icons.chat_bubble_outline, label: 'Dialogos'),
    (icon: Icons.task_alt, label: 'Tarefas'),
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
            _AreaTab(editor: editor),
            _ConnectionTab(editor: editor),
            _CharacterTab(editor: editor),
            _StateFlagTab(editor: editor),
            _DialogueTab(editor: editor),
            _TaskTab(editor: editor),
            _EventTab(editor: editor),
          ],
        ),
      ),
    );
  }
}

// ---------- Areas ----------

class _AreaTab extends StatelessWidget {
  const _AreaTab({required this.editor});
  final BlueprintEditor editor;

  @override
  Widget build(BuildContext context) {
    final items = editor.areas.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _ImageGrid<Area>(
      items: items,
      onAdd: () async {
        final result = await Navigator.push<Area>(
          context,
          MaterialPageRoute(builder: (_) => AddAreaScreen(editor: editor)),
        );
        if (result != null) editor.addArea(result);
      },
      cardBuilder: (context, area) => _AreaCard(
        area: area,
        onEdit: () async {
          final result = await Navigator.push<Area>(
            context,
            MaterialPageRoute(
              builder: (_) => AddAreaScreen(editor: editor, existing: area),
            ),
          );
          if (result != null) editor.updateArea(result);
        },
        onDelete: () => _confirmDelete(
          context,
          area.name,
          () => editor.removeArea(area.id),
        ),
      ),
    );
  }
}

// ---------- Connections ----------

class _ConnectionTab extends StatelessWidget {
  const _ConnectionTab({required this.editor});
  final BlueprintEditor editor;

  @override
  Widget build(BuildContext context) {
    final items = editor.connections.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _EntityList<Connection>(
      items: items,
      label: (c) {
        final a = editor.areas[c.areaA]?.name ?? 'A${c.areaA}';
        final b = editor.areas[c.areaB]?.name ?? 'A${c.areaB}';
        return '$a ↔ $b';
      },
      subtitle: (c) =>
          '${c.travelMinutes} min${c.locked ? " · bloqueada" : ""}',
      onDelete: (c) => editor.removeConnection(c.id),
      onAdd: () async {
        if (editor.areas.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Precisa de pelo menos 2 areas.')),
          );
          return;
        }
        final result = await Navigator.push<Connection>(
          context,
          MaterialPageRoute(
            builder: (_) => AddConnectionScreen(editor: editor),
          ),
        );
        if (result != null) editor.addConnection(result);
      },
    );
  }
}

// ---------- Characters ----------

class _CharacterTab extends StatelessWidget {
  const _CharacterTab({required this.editor});
  final BlueprintEditor editor;

  @override
  Widget build(BuildContext context) {
    final items = editor.characters.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _ImageGrid<Character>(
      items: items,
      onAdd: () async {
        final result = await Navigator.push<Character>(
          context,
          MaterialPageRoute(builder: (_) => AddCharacterScreen(editor: editor)),
        );
        if (result != null) editor.addCharacter(result);
      },
      cardBuilder: (context, char) => _CharacterCard(
        character: char,
        areaName: char.id == BlueprintEditor.playerId
            ? 'Jogador'
            : (editor.areas[char.areaId]?.name ?? 'Area ${char.areaId}'),
        onEdit: () async {
          final result = await Navigator.push<Character>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddCharacterScreen(editor: editor, existing: char),
            ),
          );
          if (result != null) editor.updateCharacter(result);
        },
        onDelete: char.id == BlueprintEditor.playerId
            ? null
            : () => _confirmDelete(
                context,
                char.name,
                () => editor.removeCharacter(char.id),
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

// ---------- Tasks ----------

class _TaskTab extends StatelessWidget {
  const _TaskTab({required this.editor});
  final BlueprintEditor editor;

  @override
  Widget build(BuildContext context) {
    final items = editor.tasks.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return _EntityList<Task>(
      items: items,
      label: (t) => t.name,
      subtitle: (t) => 'area: ${editor.areas[t.areaId]?.name ?? t.areaId}',
      onAdd: () async {
        final result = await Navigator.push<Task>(
          context,
          MaterialPageRoute(builder: (_) => AddTaskScreen(editor: editor)),
        );
        if (result != null) editor.addTask(result);
      },
      onDelete: (t) => editor.removeTask(t.id),
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

// ---------- Image grid (areas + characters) ----------

class _ImageGrid<T> extends StatelessWidget {
  const _ImageGrid({
    required this.items,
    required this.onAdd,
    required this.cardBuilder,
  });

  final List<T> items;
  final VoidCallback onAdd;
  final Widget Function(BuildContext, T) cardBuilder;

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
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: items
                    .map((item) => cardBuilder(context, item))
                    .toList(),
              ),
            ),
    );
  }
}

// ---------- Area card ----------

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.area,
    required this.onEdit,
    required this.onDelete,
  });

  final Area area;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static final _resolver = RenpyAssetResolver.auto();

  @override
  Widget build(BuildContext context) {
    final absPath = _resolver.resolve(area.backgroundPath);
    final bgFile = area.backgroundPath.isNotEmpty ? File(absPath) : null;
    final hasImage = bgFile != null && bgFile.existsSync();

    return SizedBox(
      width: 200,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Background image — landscape 16:9
            AspectRatio(
              aspectRatio: 16 / 9,
              child: hasImage
                  ? Image.file(bgFile, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surfaceHighlight,
                      child: const Center(
                        child: Icon(
                          Icons.landscape_outlined,
                          size: 32,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          area.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (area.locked)
                        const Icon(
                          Icons.lock,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID ${area.id} · ${area.connectionIds.length} conexões',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        color: AppColors.textSecondary,
                        onPressed: onEdit,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Editar',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 15),
                        color: AppColors.error,
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Character card ----------

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.areaName,
    required this.onEdit,
    this.onDelete,
  });

  final Character character;
  final String areaName;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  static final _resolver = RenpyAssetResolver.auto();

  @override
  Widget build(BuildContext context) {
    final absPath = _resolver.resolve(character.portraitPath);
    final portraitFile = character.portraitPath.isNotEmpty
        ? File(absPath)
        : null;
    final hasPortrait = portraitFile != null && portraitFile.existsSync();
    final charColor = _hexColor(character.colorHex);

    return SizedBox(
      width: 160,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portrait — 1:1 square
            AspectRatio(
              aspectRatio: 1,
              child: hasPortrait
                  ? Image.file(portraitFile, fit: BoxFit.cover)
                  : Container(
                      color: charColor.withValues(alpha: 0.15),
                      child: Center(
                        child: Text(
                          character.name.isNotEmpty ? character.name[0] : '?',
                          style: TextStyle(
                            color: charColor,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
            // Color accent bar
            Container(height: 3, color: charColor),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: charColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          areaName,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        color: AppColors.textSecondary,
                        onPressed: onEdit,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Editar',
                      ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 15),
                          color: AppColors.error,
                          onPressed: onDelete,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Eliminar',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

Color _hexColor(String hex) {
  try {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}
