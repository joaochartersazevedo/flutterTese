import 'package:flutter/material.dart';
import '../../domain/blueprint_editor.dart';
import '../../models/connection.dart';

class AddConnectionScreen extends StatefulWidget {
  const AddConnectionScreen({super.key, required this.editor});
  final BlueprintEditor editor;

  @override
  State<AddConnectionScreen> createState() => _AddConnectionScreenState();
}

class _AddConnectionScreenState extends State<AddConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _areaA;
  int? _areaB;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_areaA == null || _areaB == null || _areaA == _areaB) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleciona duas areas diferentes.')),
      );
      return;
    }
    final id = widget.editor.nextConnectionId();
    Navigator.pop(
      context,
      Connection(
        id: id,
        areaA: _areaA!,
        areaB: _areaB!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.editor.areas.values.toList()..sort((a, b) => a.id.compareTo(b.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Nova Conexao')),
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
              DropdownButtonFormField<int>(
                value: _areaA,
                decoration: const InputDecoration(labelText: 'Area A *'),
                items: areas
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _areaA = v),
                validator: (v) => v == null ? 'Obrigatorio' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _areaB,
                decoration: const InputDecoration(labelText: 'Area B *'),
                items: areas
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _areaB = v),
                validator: (v) => v == null ? 'Obrigatorio' : null,
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: _submit, child: const Text('Criar')),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}
