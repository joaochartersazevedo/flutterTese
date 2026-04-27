import 'package:flutter/material.dart';

import '../../domain/blueprint_editor.dart';
import '../../models/state_flag.dart';

class AddStateFlagScreen extends StatefulWidget {
  const AddStateFlagScreen({super.key, required this.editor, this.existing});
  final BlueprintEditor editor;
  final StateFlag? existing;

  @override
  State<AddStateFlagScreen> createState() => _AddStateFlagScreenState();
}

class _AddStateFlagScreenState extends State<AddStateFlagScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late bool _value;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _value = widget.existing?.value ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ?? widget.editor.nextStateId();
    Navigator.pop(
      context,
      StateFlag(id: id, name: _name.text.trim(), value: _value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Novo Gamestate' : 'Editar Gamestate')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatorio' : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Valor inicial'),
                value: _value,
                onChanged: (v) => setState(() => _value = v),
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: _submit, child: Text(isNew ? 'Criar' : 'Guardar')),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}
