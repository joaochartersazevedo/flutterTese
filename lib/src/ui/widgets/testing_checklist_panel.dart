import 'package:flutter/material.dart';

import '../../data/testing_checklist.dart';

/// Wraps [child] with a floating checklist button + side panel when the
/// testing checklist is enabled (Settings > Modo de teste). No-op otherwise.
class TestingChecklistOverlay extends StatefulWidget {
  const TestingChecklistOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<TestingChecklistOverlay> createState() => _TestingChecklistOverlayState();
}

class _TestingChecklistOverlayState extends State<TestingChecklistOverlay> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final checklist = TestingChecklist.instance;
    return ListenableBuilder(
      listenable: checklist,
      builder: (context, _) {
        if (!checklist.enabled) return widget.child;
        return Stack(
          children: [
            widget.child,
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'testing_checklist_fab',
                tooltip: 'Checklist de testes',
                onPressed: () => setState(() => _open = !_open),
                child: Text('${checklist.doneCount}/${checklist.totalCount}'),
              ),
            ),
            if (_open)
              Positioned(
                right: 16,
                bottom: 88,
                width: 340,
                height: 480,
                child: _ChecklistPanel(
                  checklist: checklist,
                  onClose: () => setState(() => _open = false),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChecklistPanel extends StatelessWidget {
  const _ChecklistPanel({required this.checklist, required this.onClose});
  final TestingChecklist checklist;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<ChecklistItem>>{};
    for (final item in TestingChecklist.items) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Checklist de testes (${checklist.doneCount}/${checklist.totalCount})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Reiniciar checklist',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: checklist.reset,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                for (final entry in byCategory.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  for (final item in entry.value)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: checklist.isDone(item.id),
                      onChanged: null,
                      title: Text(item.label, style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
