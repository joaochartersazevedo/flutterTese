import 'package:flutter/material.dart';

import '../../data/save_file_service.dart';
import '../../models/save_data.dart';
import '../app_theme.dart';
import 'settings_screen.dart';

class SaveSelectionScreen extends StatefulWidget {
  const SaveSelectionScreen({
    super.key,
    required this.onSaveSelected,
    this.startingAreaId = 1,
  });
  final Future<void> Function(SaveData saveData) onSaveSelected;
  final int startingAreaId;

  @override
  State<SaveSelectionScreen> createState() => _SaveSelectionScreenState();
}

class _SaveSelectionScreenState extends State<SaveSelectionScreen> {
  late Future<List<SaveData>> _savesFuture;
  final _ctrl = TextEditingController();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _savesFuture = SaveFileService.listSaves();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _savesFuture = SaveFileService.listSaves();
      });

  Future<void> _createAndLoad() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome não pode estar vazio.')),
      );
      return;
    }
    if (await SaveFileService.saveExists(name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" já existe.')),
        );
      }
      return;
    }

    setState(() => _creating = true);
    final save = SaveData(
      saveName: name,
      timestamp: DateTime.now(),
      currentAreaId: widget.startingAreaId,
      elapsedMinutes: 0,
      minutesSincePopulate: 0,
      log: [],
      gameFlags: {},
      characterPositions: {},
    );
    await SaveFileService.saveSave(save);
    if (!mounted) return;
    setState(() => _creating = false);
    _ctrl.clear();
    await widget.onSaveSelected(save);
  }

  Future<void> _deleteSave(SaveData save) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar save?'),
        content: Text('Eliminar "${save.saveName}"? Esta ação é irreversível.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SaveFileService.deleteSave(save.saveName);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Saves'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Definições',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Save list ──────────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<SaveData>>(
              future: _savesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar saves: ${snap.error}',
                      style:
                          const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  );
                }
                final saves = snap.data ?? [];
                if (saves.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save_outlined,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Sem saves',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Cria um novo save para começar.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  itemCount: saves.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final save = saves[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDim,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.save_outlined,
                              size: 18, color: AppColors.primaryLight),
                        ),
                        title: Text(
                          save.displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          save.displayTime,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              color: AppColors.error,
                              tooltip: 'Eliminar',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _deleteSave(save),
                            ),
                          ],
                        ),
                        onTap: () => widget.onSaveSelected(save),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ── New save form ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Nome do novo save…',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _createAndLoad(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _creating ? null : _createAndLoad,
                  icon: _creating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, size: 16),
                  label: const Text('Criar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
