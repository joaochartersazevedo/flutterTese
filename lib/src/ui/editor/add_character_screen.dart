import 'package:flutter/material.dart';

import '../../domain/blueprint_editor.dart';
import '../../models/character.dart';
import '../app_theme.dart';
import 'image_picker_field.dart';

class AddCharacterScreen extends StatefulWidget {
  const AddCharacterScreen({super.key, required this.editor, this.existing});
  final BlueprintEditor editor;
  final Character? existing;

  @override
  State<AddCharacterScreen> createState() => _AddCharacterScreenState();
}

class _AddCharacterScreenState extends State<AddCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _color;
  late String _portraitPath;
  late String _bodyPath;
  late int? _areaId;
  late bool _isPlayer;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _color = TextEditingController(text: e?.colorHex ?? '#ffffff');
    _portraitPath = e?.portraitPath ?? '';
    _bodyPath = e?.bodyPath ?? '';
    _areaId = e?.areaId;
    _isPlayer = e?.id == BlueprintEditor.playerId;
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ?? widget.editor.nextCharId();
    Navigator.pop(
      context,
      Character(
        id: id,
        name: _name.text.trim(),
        colorHex: _color.text.trim(),
        portraitPath: _portraitPath,
        areaId: _isPlayer ? 0 : (_areaId ?? 0),
        bodyPath: _bodyPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.editor.areas.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final isNew = widget.existing == null;

    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Novo Personagem' : 'Editar Personagem')),
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
                decoration: const InputDecoration(labelText: 'Nome *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatorio' : null,
              ),
              const SizedBox(height: 16),
              _ColorField(controller: _color),
              const SizedBox(height: 16),
              if (!_isPlayer)
                if (areas.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: areas.any((a) => a.id == _areaId) ? _areaId : null,
                    decoration: const InputDecoration(labelText: 'Area inicial'),
                    items: areas
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _areaId = v),
                  )
                else
                  const Text('Adiciona areas primeiro.', style: TextStyle(color: Colors.orange))
              else
                const Text('Jogador nao precisa area inicial.',
                    style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 24),
              ImagePickerField(
                label: 'Retrato (portrait)',
                subdirectory: 'editor/portraits',
                initialPath: _portraitPath,
                onChanged: (path) => setState(() => _portraitPath = path),
              ),
              const SizedBox(height: 24),
              ImagePickerField(
                label: 'Sprite corpo',
                subdirectory: 'editor/bodies',
                initialPath: _bodyPath,
                onChanged: (path) => setState(() => _bodyPath = path),
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

class _ColorField extends StatefulWidget {
  const _ColorField({required this.controller});
  final TextEditingController controller;

  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  Color _preview = Colors.white;

  @override
  void initState() {
    super.initState();
    _preview = _parse(widget.controller.text);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() => setState(() => _preview = _parse(widget.controller.text));

  Color _parse(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {}
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            decoration: const InputDecoration(
              labelText: 'Cor (hex)',
              hintText: '#11a7ef',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _preview,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
        ),
      ],
    );
  }
}
