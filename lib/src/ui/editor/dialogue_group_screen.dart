import 'package:flutter/material.dart';

import '../../domain/blueprint_editor.dart';
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
    final result = await showDialog<String>(
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
    ctrl.dispose();
    return result;
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
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addGroup,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo Grupo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                      const Icon(
                        Icons.folder_outlined,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
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
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    final members = dialogues.values
                        .where((d) => d.groupId == g.id)
                        .toList()
                      ..sort((a, b) => a.priority.compareTo(b.priority));
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryDim,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.folder_outlined,
                                size: 18,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            title: Text(
                              g.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${members.length} diálogo${members.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  color: AppColors.textSecondary,
                                  tooltip: 'Renomear',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _editGroup(g),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  color: AppColors.error,
                                  tooltip: 'Remover',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _removeGroup(g),
                                ),
                              ],
                            ),
                          ),
                          if (members.isNotEmpty) ...[
                            const Divider(height: 1, color: AppColors.border),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: members
                                    .map(
                                      (d) => Chip(
                                        label: Text(
                                          d.name,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        avatar: const Icon(
                                          Icons.chat_bubble_outline,
                                          size: 12,
                                          color: AppColors.textMuted,
                                        ),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
