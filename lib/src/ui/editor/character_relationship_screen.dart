import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/renpy_asset_resolver.dart';
import '../../domain/blueprint_editor.dart';
import '../../models/character.dart';
import '../app_theme.dart';
import 'add_character_screen.dart';

// ---------------------------------------------------------------------------
// Relationship presets
// ---------------------------------------------------------------------------

const List<(String, Color)> _presets = [
  ('Amigos', Color(0xFF4CAF50)),
  ('Melhores Amigos', Color(0xFF2196F3)),
  ('Casal', Color(0xFFE91E63)),
  ('Inimigos', Color(0xFFF44336)),
];

Color _colorForRelationship(String label) {
  for (final (name, color) in _presets) {
    if (name == label) return color;
  }
  return Colors.white54;
}

Color _hexToColor(String hex) {
  try {
    final s = hex.replaceAll('#', '');
    if (s.length == 6) return Color(int.parse('FF$s', radix: 16));
    if (s.length == 8) return Color(int.parse(s, radix: 16));
  } catch (_) {}
  return AppColors.primary;
}

// ---------------------------------------------------------------------------
// Canvas constants
// ---------------------------------------------------------------------------

const double _canvasSize = 2000;
const double _nodeW = 90.0;
const double _nodeH = 116.0;
const double _nodeHalfDiag = 72.0; // approx half-diagonal for edge clipping

// ---------------------------------------------------------------------------
// CharacterRelationshipScreen  (merged characters + relationships)
// ---------------------------------------------------------------------------

class CharacterRelationshipScreen extends StatefulWidget {
  const CharacterRelationshipScreen({super.key, required this.editor});
  final BlueprintEditor editor;

  @override
  State<CharacterRelationshipScreen> createState() =>
      _CharacterRelationshipScreenState();
}

class _CharacterRelationshipScreenState
    extends State<CharacterRelationshipScreen>
    with TickerProviderStateMixin {
  final Map<int, Offset> _positions = {};
  int? _selectedId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static final _resolver = RenpyAssetResolver.auto();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _arrangeInCircle();
    widget.editor.addListener(_onEditorChanged);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.editor.removeListener(_onEditorChanged);
    super.dispose();
  }

  void _onEditorChanged() {
    const center = Offset(_canvasSize / 2, _canvasSize / 2);
    for (final id in widget.editor.characters.keys) {
      if (!_positions.containsKey(id)) {
        final angle = math.Random(id).nextDouble() * math.pi * 2;
        _positions[id] =
            center + Offset(math.cos(angle), math.sin(angle)) * 200;
      }
    }
    _positions.removeWhere(
        (id, _) => !widget.editor.characters.containsKey(id));
    setState(() {});
  }

  void _arrangeInCircle() {
    final ids = widget.editor.characters.keys.toList();
    if (ids.isEmpty) return;
    const center = Offset(_canvasSize / 2, _canvasSize / 2);
    const radius = 320.0;
    for (var i = 0; i < ids.length; i++) {
      final angle = (2 * math.pi * i / ids.length) - math.pi / 2;
      _positions[ids[i]] =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    }
  }

  // ── interaction ────────────────────────────────────────────────────────────

  void _onNodeTap(int id) {
    setState(() {
      if (_selectedId == null) {
        _selectedId = id;
      } else if (_selectedId == id) {
        _selectedId = null;
      } else {
        final src = _selectedId!;
        _selectedId = null;
        _showRelationshipDialog(src, id);
      }
    });
  }

  void _onNodeDrag(int id, DragUpdateDetails d) {
    setState(() {
      final cur =
          _positions[id] ?? const Offset(_canvasSize / 2, _canvasSize / 2);
      _positions[id] = Offset(
        (cur.dx + d.delta.dx).clamp(_nodeW / 2, _canvasSize - _nodeW / 2),
        (cur.dy + d.delta.dy).clamp(_nodeH / 2, _canvasSize - _nodeH / 2),
      );
    });
  }

  void _showRelationshipDialog(int idA, int idB) {
    final a = widget.editor.characters[idA];
    final b = widget.editor.characters[idB];
    if (a == null || b == null) return;
    final existing = a.relationships[idB] ?? b.relationships[idA];

    showDialog<void>(
      context: context,
      builder: (ctx) => _RelationshipDialog(
        charA: a,
        charB: b,
        existing: existing,
        onSet: (rel) {
          _setRelationship(idA, idB, rel);
          Navigator.of(ctx).pop();
        },
        onClear: () {
          _clearRelationship(idA, idB);
          Navigator.of(ctx).pop();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _setRelationship(int idA, int idB, String label) {
    final a = widget.editor.characters[idA];
    final b = widget.editor.characters[idB];
    if (a == null || b == null) return;
    widget.editor
      ..updateCharacter(
          a.copyWith(relationships: Map.of(a.relationships)..[idB] = label))
      ..updateCharacter(
          b.copyWith(relationships: Map.of(b.relationships)..[idA] = label));
  }

  void _clearRelationship(int idA, int idB) {
    final a = widget.editor.characters[idA];
    final b = widget.editor.characters[idB];
    if (a == null || b == null) return;
    widget.editor
      ..updateCharacter(
          a.copyWith(relationships: Map.of(a.relationships)..remove(idB)))
      ..updateCharacter(
          b.copyWith(relationships: Map.of(b.relationships)..remove(idA)));
  }

  List<(int, int, String)> _buildEdges() {
    final seen = <String>{};
    final edges = <(int, int, String)>[];
    for (final char in widget.editor.characters.values) {
      for (final e in char.relationships.entries) {
        if (!widget.editor.characters.containsKey(e.key)) continue;
        final key =
            char.id < e.key ? '${char.id}-${e.key}' : '${e.key}-${char.id}';
        if (seen.add(key)) edges.add((char.id, e.key, e.value));
      }
    }
    return edges;
  }

  // ── character CRUD helpers ─────────────────────────────────────────────────

  Future<void> _addCharacter() async {
    final result = await Navigator.push<Character>(
      context,
      MaterialPageRoute(
          builder: (_) => AddCharacterScreen(editor: widget.editor)),
    );
    if (result != null) widget.editor.addCharacter(result);
  }

  Future<void> _editCharacter(Character char) async {
    final result = await Navigator.push<Character>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AddCharacterScreen(editor: widget.editor, existing: char)),
    );
    if (result != null) widget.editor.updateCharacter(result);
  }

  void _deleteCharacter(BuildContext ctx, Character char) {
    showDialog<void>(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Remover personagem'),
        content: Text('Remover "${char.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () {
              widget.editor.removeCharacter(char.id);
              Navigator.pop(dlgCtx);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.editor,
      builder: (context, _) {
        final chars = widget.editor.characters;
        final edges = _buildEdges();
        return Row(
          children: [
            // ── Left sidebar: character list ──────────────────────────────
            Container(
              width: 220,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border:
                    Border(right: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: AppColors.border, width: 1)),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'PERSONAGENS',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          color: AppColors.accent,
                          tooltip: 'Adicionar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _addCharacter,
                        ),
                      ],
                    ),
                  ),
                  // List
                  Expanded(
                    child: chars.isEmpty
                        ? const Center(
                            child: Text(
                              'Sem personagens',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            children: chars.values
                                .toList()
                                .map((c) => _SidebarCharItem(
                                      character: c,
                                      resolver: _resolver,
                                      isPlayer:
                                          c.id == BlueprintEditor.playerId,
                                      areaName: c.id == BlueprintEditor.playerId
                                          ? 'Jogador'
                                          : (widget.editor.areas[c.areaId]
                                                  ?.name ??
                                              'Area ${c.areaId}'),
                                      onEdit: () => _editCharacter(c),
                                      onDelete: c.id == BlueprintEditor.playerId
                                          ? null
                                          : () => _deleteCharacter(context, c),
                                    ))
                                .toList(),
                          ),
                  ),
                  // Reorganise button
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: OutlinedButton.icon(
                      onPressed: () => setState(_arrangeInCircle),
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Reorganizar',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Right: graph canvas ───────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(200),
                    minScale: 0.25,
                    maxScale: 3.0,
                    child: SizedBox(
                      width: _canvasSize,
                      height: _canvasSize,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, _) => Stack(
                          children: [
                            Positioned.fill(
                                child: Container(color: AppColors.bg)),
                            Positioned.fill(
                                child: CustomPaint(painter: _GridPainter())),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _EdgePainter(
                                  edges: edges,
                                  positions: _positions,
                                  selectedId: _selectedId,
                                ),
                              ),
                            ),
                            for (final char in chars.values)
                              _buildNode(char),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Hint strip
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _HintBar(
                        selectedId: _selectedId, characters: chars),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNode(Character char) {
    final pos = _positions[char.id] ??
        const Offset(_canvasSize / 2, _canvasSize / 2);
    final isSelected = _selectedId == char.id;
    final isCandidate = _selectedId != null && _selectedId != char.id;
    final charColor = _hexToColor(char.colorHex);

    final portraitAbs = _resolver.resolve(char.portraitPath);
    final portraitFile =
        char.portraitPath.isNotEmpty ? File(portraitAbs) : null;
    final hasPortrait = portraitFile != null && portraitFile.existsSync();

    return Positioned(
      left: pos.dx - _nodeW / 2,
      top: pos.dy - _nodeH / 2,
      child: GestureDetector(
        onTap: () => _onNodeTap(char.id),
        onPanUpdate: (d) => _onNodeDrag(char.id, d),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Pulsing ring around card
            if (isCandidate)
              Positioned(
                left: -10 - _pulseAnim.value * 4,
                top: -10 - _pulseAnim.value * 4,
                width: _nodeW + 20 + _pulseAnim.value * 8,
                height: _nodeH + 20 + _pulseAnim.value * 8,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary
                          .withValues(alpha: 0.3 + _pulseAnim.value * 0.4),
                      width: 2,
                    ),
                  ),
                ),
              ),
            // Card node
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _nodeW,
              height: _nodeH,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : isCandidate
                          ? AppColors.primary
                          : AppColors.border,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Portrait area
                  SizedBox(
                    height: 72,
                    child: hasPortrait
                        ? Image.file(portraitFile,
                            fit: BoxFit.cover, width: _nodeW)
                        : Container(
                            color: charColor.withValues(alpha: 0.15),
                            child: Center(
                              child: Text(
                                char.name.isNotEmpty
                                    ? char.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: charColor,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Color accent bar
                  Container(height: 3, color: charColor),
                  // Name
                  Expanded(
                    child: Container(
                      color: AppColors.surfaceElevated,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Center(
                        child: Text(
                          char.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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

// ---------------------------------------------------------------------------
// Sidebar character item
// ---------------------------------------------------------------------------

class _SidebarCharItem extends StatelessWidget {
  const _SidebarCharItem({
    required this.character,
    required this.resolver,
    required this.isPlayer,
    required this.areaName,
    required this.onEdit,
    this.onDelete,
  });

  final Character character;
  final RenpyAssetResolver resolver;
  final bool isPlayer;
  final String areaName;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final charColor = _hexToColor(character.colorHex);
    final portraitAbs = resolver.resolve(character.portraitPath);
    final portraitFile =
        character.portraitPath.isNotEmpty ? File(portraitAbs) : null;
    final hasPortrait = portraitFile != null && portraitFile.existsSync();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Portrait thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(7),
              bottomLeft: Radius.circular(7),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: hasPortrait
                  ? Image.file(portraitFile, fit: BoxFit.cover)
                  : Container(
                      color: charColor.withValues(alpha: 0.18),
                      child: Center(
                        child: Text(
                          character.name.isNotEmpty
                              ? character.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: charColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          // Color strip
          Container(width: 3, height: 44, color: charColor),
          const SizedBox(width: 8),
          // Name + area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  character.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  areaName,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Edit / delete
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 15),
            color: AppColors.textSecondary,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: 'Editar',
            onPressed: onEdit,
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 15),
              color: AppColors.error,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              tooltip: 'Remover',
              onPressed: onDelete,
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edge painter
// ---------------------------------------------------------------------------

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.edges,
    required this.positions,
    required this.selectedId,
  });

  final List<(int, int, String)> edges;
  final Map<int, Offset> positions;
  final int? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (idA, idB, label) in edges) {
      final posA = positions[idA];
      final posB = positions[idB];
      if (posA == null || posB == null) continue;
      final color = _colorForRelationship(label);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(posA, posB, paint);
      _drawLabel(canvas,
          label, Offset((posA.dx + posB.dx) / 2, (posA.dy + posB.dy) / 2),
          color);
    }

    if (selectedId != null) {
      final src = positions[selectedId!];
      if (src != null) {
        _drawDashedLine(canvas, src,
            const Offset(_canvasSize / 2, _canvasSize / 2),
            AppColors.accent.withValues(alpha: 0.6));
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center, Color lineColor) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: lineColor == Colors.white54 ? Colors.white70 : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 6.0;
    const padV = 3.0;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: center,
          width: tp.width + padH * 2,
          height: tp.height + padV * 2),
      const Radius.circular(4),
    );
    canvas.drawRRect(
        bgRect,
        Paint()
          ..color = AppColors.surfaceElevated.withValues(alpha: 0.92)
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        bgRect,
        Paint()
          ..color = lineColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    tp.paint(canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final ux = dx / dist;
    final uy = dy / dist;
    double t = _nodeHalfDiag + 4;
    bool draw = true;
    while (t < dist - _nodeHalfDiag) {
      final end = math.min(t + (draw ? 8.0 : 5.0), dist - _nodeHalfDiag);
      if (draw) {
        canvas.drawLine(Offset(from.dx + ux * t, from.dy + uy * t),
            Offset(from.dx + ux * end, from.dy + uy * end), paint);
      }
      t = end;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.edges != edges ||
      old.positions != positions ||
      old.selectedId != selectedId;
}

// ---------------------------------------------------------------------------
// Grid dot painter
// ---------------------------------------------------------------------------

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.25)
      ..strokeCap = StrokeCap.round;
    for (double x = 40; x < size.width; x += 40) {
      for (double y = 40; y < size.height; y += 40) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ---------------------------------------------------------------------------
// Hint bar
// ---------------------------------------------------------------------------

class _HintBar extends StatelessWidget {
  const _HintBar({required this.selectedId, required this.characters});
  final int? selectedId;
  final Map<int, Character> characters;

  @override
  Widget build(BuildContext context) {
    final text = selectedId == null
        ? 'Toca num personagem para selecionar'
        : '${characters[selectedId]?.name ?? ''} selecionado — toca noutro para criar relação';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selectedId == null ? Icons.touch_app : Icons.link,
            size: 15,
            color: selectedId == null ? AppColors.textSecondary : AppColors.accent,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selectedId == null
                    ? AppColors.textSecondary
                    : AppColors.accentLight,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Relationship dialog
// ---------------------------------------------------------------------------

class _RelationshipDialog extends StatefulWidget {
  const _RelationshipDialog({
    required this.charA,
    required this.charB,
    required this.existing,
    required this.onSet,
    required this.onClear,
    required this.onCancel,
  });
  final Character charA;
  final Character charB;
  final String? existing;
  final void Function(String) onSet;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  @override
  State<_RelationshipDialog> createState() => _RelationshipDialogState();
}

class _RelationshipDialogState extends State<_RelationshipDialog> {
  late final TextEditingController _ctrl;
  String? _activePreset;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _activePreset = ex != null && _presets.any((p) => p.$1 == ex) ? ex : null;
    _ctrl = TextEditingController(text: ex ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.charA.name} ↔ ${widget.charB.name}'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TIPO DE RELAÇÃO',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, color) in _presets)
                  _PresetChip(
                    label: label,
                    color: color,
                    selected: _activePreset == label,
                    onTap: () => setState(() {
                      _activePreset = label;
                      _ctrl.text = label;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Personalizada',
                hintText: 'Ex: rival, mentor…',
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => setState(() {
                _activePreset = _presets.any((p) => p.$1 == v) ? v : null;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
        if (widget.existing != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: widget.onClear,
            child: const Text('Remover'),
          ),
        FilledButton(
          onPressed: () {
            final v = _ctrl.text.trim();
            if (v.isNotEmpty) widget.onSet(v);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Preset chip
// ---------------------------------------------------------------------------

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.22)
              : AppColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
