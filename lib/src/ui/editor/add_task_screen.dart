import 'package:flutter/material.dart';
import '../../domain/blueprint_editor.dart';
import '../../models/state_flag.dart';
import '../../models/task.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key, required this.editor, this.existing});
  final BlueprintEditor editor;
  final Task? existing;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late int? _areaId;
  late bool _singleTrigger;
  late Map<int, bool> _preconditions;
  late Map<int, bool> _consequences;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _areaId = e?.areaId;
    _singleTrigger = e?.singleTrigger ?? true;
    _preconditions = Map<int, bool>.from(e?.preconditions ?? {});
    _consequences = Map<int, bool>.from(e?.consequences ?? {});
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ?? widget.editor.nextTaskId();
    Navigator.pop(
      context,
      Task(
        id: id,
        name: _name.text.trim(),
        session: 1,
        section: 1,
        areaId: _areaId ?? 0,
        singleTrigger: _singleTrigger,
        preconditions: Map<int, bool>.from(_preconditions),
        consequences: Map<int, bool>.from(_consequences),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.editor.areas.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final flags = widget.editor.gamestates.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final isNew = widget.existing == null;

    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Nova Tarefa' : 'Editar Tarefa')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatorio' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: areas.any((a) => a.id == _areaId) ? _areaId : null,
              decoration: const InputDecoration(labelText: 'Area'),
              items: areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
              onChanged: (v) => setState(() => _areaId = v),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Single trigger'),
              value: _singleTrigger,
              onChanged: (v) => setState(() => _singleTrigger = v),
            ),
            const SizedBox(height: 16),
            _ConditionsSection(
              title: 'Precondições',
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
            const SizedBox(height: 32),
            FilledButton(onPressed: _submit, child: Text(isNew ? 'Criar' : 'Guardar')),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

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
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (flags.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  final unused = flags.where((f) => !conditions.containsKey(f.id)).toList();
                  if (unused.isEmpty) return;
                  final newConds = Map<int, bool>.from(conditions);
                  newConds[unused.first.id] = false;
                  onChanged(newConds);
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar'),
              ),
          ],
        ),
        if (conditions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Nenhuma.', style: TextStyle(color: Colors.white38)),
          )
        else
          ...conditions.entries.map((entry) {
            final flag = flags.where((f) => f.id == entry.key).firstOrNull;
            final name = flag?.name ?? 'Flag ${entry.key}';
            return ListTile(
              dense: true,
              title: Text(name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToggleButtons(
                    isSelected: [entry.value == false, entry.value == true],
                    onPressed: (i) {
                      final newConds = Map<int, bool>.from(conditions);
                      newConds[entry.key] = i == 1;
                      onChanged(newConds);
                    },
                    children: const [Text('false'), Text('true')],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      final newConds = Map<int, bool>.from(conditions);
                      newConds.remove(entry.key);
                      onChanged(newConds);
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
