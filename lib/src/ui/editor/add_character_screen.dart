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

const _bigFiveTraits = [
  ('extroverted', 'Extrovertido', 'Introvertido', 'Extrovertido'),
  ('friendly',    'Amigável',     'Hostil',        'Amigável'),
  ('responsible', 'Responsável',  'Irresponsável', 'Responsável'),
  ('anxious',     'Ansioso',      'Calmo',         'Ansioso'),
  ('creative',    'Criativo',     'Convencional',  'Criativo'),
];

class _AddCharacterScreenState extends State<AddCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _color;
  late String _portraitPath;
  late String _bodyPath;
  late int? _areaId;
  late bool _isPlayer;
  late Map<String, int> _personality;
  late Map<int, String> _relationships;

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
    _personality = Map.of(e?.personality ?? {
      for (final t in _bigFiveTraits) t.$1: 1,
    });
    _relationships = Map.of(e?.relationships ?? {});
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
        personality: Map.of(_personality),
        relationships: Map.of(_relationships),
      ),
    );
  }

  Future<void> _addRelationship() async {
    final otherChars = widget.editor.characters.values
        .where((c) => c.id != (widget.existing?.id ?? -1) && !_relationships.containsKey(c.id))
        .toList();
    if (otherChars.isEmpty) return;

    int? selectedId = otherChars.first.id;
    final descCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateInner) => AlertDialog(
          title: const Text('Adicionar relação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedId,
                decoration: const InputDecoration(labelText: 'Personagem'),
                items: otherChars
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setStateInner(() => selectedId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'ex: melhor amigo, rival, namorado',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Adicionar')),
          ],
        ),
      ),
    );
    final desc = descCtrl.text.trim();
    descCtrl.dispose();
    if (result == true && selectedId != null && desc.isNotEmpty) {
      setState(() => _relationships[selectedId!] = desc);
    }
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
              const SizedBox(height: 28),
              // ── Personality ───────────────────────────────────────────────
              Text('Personalidade', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              for (final t in _bigFiveTraits) ...[
                _TraitSlider(
                  label: t.$2,
                  lowLabel: t.$3,
                  highLabel: t.$4,
                  value: _personality[t.$1] ?? 1,
                  onChanged: (v) => setState(() => _personality[t.$1] = v),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 20),
              // ── Relationships ─────────────────────────────────────────────
              Row(
                children: [
                  Text('Relações', style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addRelationship,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Adicionar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              if (_relationships.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sem relações definidas.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                )
              else
                for (final entry in _relationships.entries) ...[
                  _RelationshipRow(
                    charName: widget.editor.characters[entry.key]?.name ?? '#${entry.key}',
                    description: entry.value,
                    onDelete: () => setState(() => _relationships.remove(entry.key)),
                  ),
                ],
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

// ─── Trait Slider ─────────────────────────────────────────────────────────────

class _TraitSlider extends StatelessWidget {
  const _TraitSlider({
    required this.label,
    required this.lowLabel,
    required this.highLabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String lowLabel;
  final String highLabel;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Text(lowLabel, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 2,
            divisions: 2,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Text(highLabel, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}

// ─── Relationship Row ─────────────────────────────────────────────────────────

class _RelationshipRow extends StatelessWidget {
  const _RelationshipRow({
    required this.charName,
    required this.description,
    required this.onDelete,
  });

  final String charName;
  final String description;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(charName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          const Text('—', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(description,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
