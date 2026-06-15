import 'package:flutter/material.dart';

import '../../domain/blueprint_editor.dart';
import '../../models/area.dart';
import 'image_picker_field.dart';

class AddAreaScreen extends StatefulWidget {
  const AddAreaScreen({super.key, required this.editor, this.existing});
  final BlueprintEditor editor;
  final Area? existing;

  @override
  State<AddAreaScreen> createState() => _AddAreaScreenState();
}

class _AddAreaScreenState extends State<AddAreaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _bgPath;
  late bool _locked;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _bgPath = e?.backgroundPath ?? '';
    _locked = e?.locked ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ?? widget.editor.nextAreaId();
    Navigator.pop(
      context,
      Area(
        id: id,
        name: _name.text.trim(),
        backgroundPath: _bgPath,
        connectionIds: widget.existing?.connectionIds ?? [],
        locked: _locked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Nova Area' : 'Editar Area')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nome da area *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatorio' : null,
                  ),
                  const SizedBox(height: 24),
                  ImagePickerField(
                    label: 'Imagem de fundo',
                    subdirectory: 'areas',
                    initialPath: _bgPath,
                    onChanged: (path) => setState(() => _bgPath = path),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Bloqueada'),
                    value: _locked,
                    onChanged: (v) => setState(() => _locked = v),
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
