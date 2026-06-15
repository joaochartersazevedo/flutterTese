import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/renpy_asset_resolver.dart';
import '../../data/testing_checklist.dart';
import '../../domain/blueprint_editor.dart';
import '../../models/area.dart';
import '../../models/connection.dart';
import '../app_theme.dart';
import 'add_area_screen.dart';

// ---------------------------------------------------------------------------
// Canvas constants
// ---------------------------------------------------------------------------

const double _canvasSize = 2000;
const double _nodeW = 140.0;
const double _nodeH = 110.0;
const double _nodeHalfDiag = 88.0;

// ---------------------------------------------------------------------------
// AreaGraphScreen
// ---------------------------------------------------------------------------

class AreaGraphScreen extends StatefulWidget {
  const AreaGraphScreen({
    super.key,
    required this.editor,
  });
  final BlueprintEditor editor;

  @override
  State<AreaGraphScreen> createState() => _AreaGraphScreenState();
}

class _AreaGraphScreenState extends State<AreaGraphScreen>
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
    for (final id in widget.editor.areas.keys) {
      if (!_positions.containsKey(id)) {
        final angle = math.Random(id).nextDouble() * math.pi * 2;
        _positions[id] =
            center + Offset(math.cos(angle), math.sin(angle)) * 200;
      }
    }
    _positions.removeWhere((id, _) => !widget.editor.areas.containsKey(id));
    setState(() {});
  }

  void _arrangeInCircle() {
    final ids = widget.editor.areas.keys.toList();
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
        _showConnectionDialog(src, id);
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

  Connection? _findConnection(int idA, int idB) {
    for (final c in widget.editor.connections.values) {
      if ((c.areaA == idA && c.areaB == idB) ||
          (c.areaA == idB && c.areaB == idA)) { return c; }
    }
    return null;
  }

  void _showConnectionDialog(int idA, int idB) {
    final a = widget.editor.areas[idA];
    final b = widget.editor.areas[idB];
    if (a == null || b == null) return;
    final existing = _findConnection(idA, idB);

    showDialog<void>(
      context: context,
      builder: (ctx) => _ConnectionDialog(
        areaA: a,
        areaB: b,
        existing: existing,
        onSet: (conn) {
          if (existing != null) {
            widget.editor.removeConnection(existing.id);
          }
          widget.editor.addConnection(conn);
          TestingChecklist.instance.mark('create_connection');
          Navigator.of(ctx).pop();
        },
        onClear: existing == null
            ? null
            : () {
                widget.editor.removeConnection(existing.id);
                Navigator.of(ctx).pop();
              },
        onCancel: () => Navigator.of(ctx).pop(),
        nextId: () => widget.editor.nextConnectionId(),
      ),
    );
  }

  // ── edges ─────────────────────────────────────────────────────────────────

  List<(int, int, Connection)> _buildEdges() {
    final edges = <(int, int, Connection)>[];
    for (final conn in widget.editor.connections.values) {
      if (widget.editor.areas.containsKey(conn.areaA) &&
          widget.editor.areas.containsKey(conn.areaB)) {
        edges.add((conn.areaA, conn.areaB, conn));
      }
    }
    return edges;
  }

  // ── area CRUD helpers ──────────────────────────────────────────────────────

  Future<void> _addArea() async {
    final result = await Navigator.push<Area>(
      context,
      MaterialPageRoute(builder: (_) => AddAreaScreen(editor: widget.editor)),
    );
    if (result != null) {
      widget.editor.addArea(result);
      TestingChecklist.instance.mark('create_area');
    }
  }

  Future<void> _editArea(Area area) async {
    final result = await Navigator.push<Area>(
      context,
      MaterialPageRoute(
          builder: (_) => AddAreaScreen(editor: widget.editor, existing: area)),
    );
    if (result != null) {
      widget.editor.updateArea(result);
      TestingChecklist.instance.mark('edit_area');
    }
  }

  void _deleteArea(BuildContext ctx, Area area) {
    final affectedDialogues = widget.editor.dialoguesForArea(area.id);
    final affectedChars = widget.editor.charactersInArea(area.id);
    final hasImpact = affectedDialogues.isNotEmpty || affectedChars.isNotEmpty;

    if (!hasImpact) {
      showDialog<void>(
        context: ctx,
        builder: (dlgCtx) => AlertDialog(
          title: const Text('Remover área'),
          content: Text('Remover "${area.name}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                widget.editor.removeArea(area.id);
                TestingChecklist.instance.mark('delete_entity');
                Navigator.pop(dlgCtx);
              },
              child: const Text('Remover'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog<void>(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
            const SizedBox(width: 8),
            const Text('Remover área'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (affectedDialogues.isNotEmpty) ...[
              Text(
                '${affectedDialogues.length} diálogo${affectedDialogues.length == 1 ? '' : 's'} referencia${affectedDialogues.length == 1 ? '' : 'm'} esta área:',
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: affectedDialogues
                        .map((d) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline,
                                      size: 13, color: AppColors.textMuted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(d.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (affectedChars.isNotEmpty) ...[
              Text(
                '${affectedChars.length} personagem${affectedChars.length == 1 ? '' : 'ns'} está${affectedChars.length == 1 ? '' : 'o'} nesta área:',
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: affectedChars
                        .map((c) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline,
                                      size: 13, color: AppColors.textMuted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(c.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'Escolhe como remover:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancelar')),
          if (affectedDialogues.isNotEmpty)
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
              onPressed: () {
                Navigator.pop(dlgCtx);
                _confirmSmartDeleteArea(ctx, area, affectedDialogues.length);
              },
              child: const Text('Limpar referências'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dlgCtx);
              _confirmBruteDeleteArea(ctx, area, affectedDialogues.length, affectedChars.length);
            },
            child: const Text('Eliminar tudo'),
          ),
        ],
      ),
    );
  }

  void _confirmSmartDeleteArea(BuildContext ctx, Area area, int dialogueCount) {
    showDialog<void>(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Confirmar remoção'),
        content: Text(
          'Remove a área "${area.name}" e limpa a referência em $dialogueCount diálogo${dialogueCount == 1 ? '' : 's'}.\n\nOs diálogos ficam intactos.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () {
              widget.editor.removeAreaFromDialogues(area.id);
              widget.editor.removeArea(area.id);
              TestingChecklist.instance.mark('delete_entity');
              Navigator.pop(dlgCtx);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _confirmBruteDeleteArea(
      BuildContext ctx, Area area, int dialogueCount, int charCount) {
    final parts = <String>[];
    if (dialogueCount > 0) {
      parts.add('$dialogueCount diálogo${dialogueCount == 1 ? '' : 's'}');
    }
    if (charCount > 0) {
      parts.add('$charCount personagem${charCount == 1 ? '' : 'ns'} ficam sem área');
    }
    final detail = parts.join(' e ');

    showDialog<void>(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: AppColors.error, size: 22),
            const SizedBox(width: 8),
            const Text('Eliminar tudo'),
          ],
        ),
        content: Text(
          'Elimina a área "${area.name}" e $detail.\n\nEsta ação é irreversível.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              widget.editor.removeAreaBrute(area.id);
              TestingChecklist.instance.mark('delete_entity');
              Navigator.pop(dlgCtx);
            },
            child: const Text('Eliminar tudo'),
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
        final areas = widget.editor.areas;
        final edges = _buildEdges();
        return Row(
          children: [
            // ── Left sidebar ─────────────────────────────────────────────
            Container(
              width: 220,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                    right: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: AppColors.border, width: 1)),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'AREAS',
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
                          onPressed: _addArea,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: areas.isEmpty
                        ? _EmptySidebar(onAdd: _addArea)
                        : ListView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            children: areas.values
                                .toList()
                                .map((a) => _SidebarAreaItem(
                                      area: a,
                                      resolver: _resolver,
                                      connectionCount: a.connectionIds.length,
                                      isStarting: widget.editor.startingAreaId == a.id,
                                      onEdit: () => _editArea(a),
                                      onDelete: () => _deleteArea(context, a),
                                      onSetStarting: () {
                                        widget.editor.setStartingArea(a.id);
                                        TestingChecklist.instance.mark('set_starting_area');
                                      },
                                    ))
                                .toList(),
                          ),
                  ),
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
                                painter: _AreaEdgePainter(
                                  edges: edges,
                                  positions: _positions,
                                  selectedId: _selectedId,
                                ),
                              ),
                            ),
                            for (final area in areas.values)
                              _buildNode(area),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _HintBar(
                        selectedId: _selectedId, areas: areas),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNode(Area area) {
    final pos = _positions[area.id] ??
        const Offset(_canvasSize / 2, _canvasSize / 2);
    final isSelected = _selectedId == area.id;
    final isCandidate = _selectedId != null && _selectedId != area.id;

    final absPath = _resolver.resolve(area.backgroundPath);
    final bgFile = area.backgroundPath.isNotEmpty ? File(absPath) : null;
    final hasImage = bgFile != null && bgFile.existsSync();

    return Positioned(
      left: pos.dx - _nodeW / 2,
      top: pos.dy - _nodeH / 2,
      child: GestureDetector(
        onTap: () => _onNodeTap(area.id),
        onPanUpdate: (d) => _onNodeDrag(area.id, d),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
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
                  // Background image — landscape
                  Expanded(
                    child: hasImage
                        ? Image.file(bgFile, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.surfaceHighlight,
                            child: const Center(
                              child: Icon(
                                Icons.landscape_outlined,
                                size: 28,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                  ),
                  // Name bar
                  Container(
                    color: AppColors.surfaceElevated,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            area.name,
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
                        if (area.locked)
                          const Icon(Icons.lock,
                              size: 10, color: AppColors.textMuted),
                      ],
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
// Sidebar area item
// ---------------------------------------------------------------------------

class _SidebarAreaItem extends StatelessWidget {
  const _SidebarAreaItem({
    required this.area,
    required this.resolver,
    required this.connectionCount,
    required this.isStarting,
    required this.onEdit,
    required this.onDelete,
    required this.onSetStarting,
  });

  final Area area;
  final RenpyAssetResolver resolver;
  final int connectionCount;
  final bool isStarting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetStarting;

  @override
  Widget build(BuildContext context) {
    final absPath = resolver.resolve(area.backgroundPath);
    final bgFile = area.backgroundPath.isNotEmpty ? File(absPath) : null;
    final hasImage = bgFile != null && bgFile.existsSync();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(7),
              bottomLeft: Radius.circular(7),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: hasImage
                  ? Image.file(bgFile, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surfaceHighlight,
                      child: const Center(
                        child: Icon(Icons.landscape_outlined,
                            size: 20, color: AppColors.textMuted),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  area.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${isStarting ? "início · " : ""}$connectionCount conexões${area.locked ? " · bloqueada" : ""}',
                  style: TextStyle(
                    color: isStarting ? AppColors.teal : AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: isStarting ? 'Área inicial' : 'Definir como inicial',
            child: IconButton(
              icon: Icon(
                isStarting ? Icons.home : Icons.home_outlined,
                size: 15,
              ),
              color: isStarting ? AppColors.teal : AppColors.textMuted,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: isStarting ? null : onSetStarting,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 15),
            color: AppColors.textSecondary,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: 'Editar',
            onPressed: onEdit,
          ),
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

class _AreaEdgePainter extends CustomPainter {
  const _AreaEdgePainter({
    required this.edges,
    required this.positions,
    required this.selectedId,
  });

  final List<(int, int, Connection)> edges;
  final Map<int, Offset> positions;
  final int? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (idA, idB, conn) in edges) {
      final posA = positions[idA];
      final posB = positions[idB];
      if (posA == null || posB == null) continue;

      final color = conn.locked ? const Color(0xFFF44336) : AppColors.teal;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(posA, posB, paint);

      final label = conn.locked ? '🔒' : '';
      _drawLabel(canvas, label,
          Offset((posA.dx + posB.dx) / 2, (posA.dy + posB.dy) / 2), color);
    }

    if (selectedId != null) {
      final src = positions[selectedId!];
      if (src != null) {
        _drawDashedLine(
            canvas,
            src,
            const Offset(_canvasSize / 2, _canvasSize / 2),
            AppColors.accent.withValues(alpha: 0.6));
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center, Color lineColor) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
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
  bool shouldRepaint(covariant _AreaEdgePainter old) =>
      old.edges != edges ||
      old.positions != positions ||
      old.selectedId != selectedId;
}

// ---------------------------------------------------------------------------
// Grid painter
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
  const _HintBar({required this.selectedId, required this.areas});
  final int? selectedId;
  final Map<int, Area> areas;

  @override
  Widget build(BuildContext context) {
    final text = selectedId == null
        ? 'Toca numa area para selecionar'
        : '${areas[selectedId]?.name ?? ''} selecionada — toca noutra para criar/editar conexao';
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
            color: selectedId == null
                ? AppColors.textSecondary
                : AppColors.accent,
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
// Connection dialog
// ---------------------------------------------------------------------------

class _ConnectionDialog extends StatefulWidget {
  const _ConnectionDialog({
    required this.areaA,
    required this.areaB,
    required this.existing,
    required this.onSet,
    required this.onClear,
    required this.onCancel,
    required this.nextId,
  });

  final Area areaA;
  final Area areaB;
  final Connection? existing;
  final void Function(Connection) onSet;
  final VoidCallback? onClear;
  final VoidCallback onCancel;
  final int Function() nextId;

  @override
  State<_ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<_ConnectionDialog> {
  late final TextEditingController _label;
  late bool _locked;
  Offset? _hotA; // normalized 0–1
  Offset? _hotB;

  static final _resolver = RenpyAssetResolver.auto();

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _label = TextEditingController(text: ex?.label ?? '');
    _locked = ex?.locked ?? false;
    if (ex != null) {
      if (ex.hasHotspotA) _hotA = Offset(ex.hotspotAx!, ex.hotspotAy!);
      if (ex.hasHotspotB) _hotB = Offset(ex.hotspotBx!, ex.hotspotBy!);
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final id = widget.existing?.id ?? widget.nextId();
    widget.onSet(Connection(
      id: id,
      areaA: widget.areaA.id,
      areaB: widget.areaB.id,
      locked: _locked,
      label: _label.text.trim(),
      hotspotAx: _hotA?.dx,
      hotspotAy: _hotA?.dy,
      hotspotBx: _hotB?.dx,
      hotspotBy: _hotB?.dy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.areaA.name} ↔ ${widget.areaB.name}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(
                    labelText: 'Etiqueta do hotspot',
                    hintText: 'Ex: Escadas, Porta…'),
              ),
              SwitchListTile(
                value: _locked,
                onChanged: (v) => setState(() => _locked = v),
                title: const Text('Bloqueada', style: TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              const Text(
                'POSIÇÃO DO HOTSPOT',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toca nas imagens para colocar o ponto de entrada em cada area.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _HotspotPlacer(
                      area: widget.areaA,
                      resolver: _resolver,
                      position: _hotA,
                      onPlaced: (p) => setState(() => _hotA = p),
                      onCleared: () => setState(() => _hotA = null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HotspotPlacer(
                      area: widget.areaB,
                      resolver: _resolver,
                      position: _hotB,
                      onPlaced: (p) => setState(() => _hotB = p),
                      onCleared: () => setState(() => _hotB = null),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
        if (widget.onClear != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: widget.onClear,
            child: const Text('Remover'),
          ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hotspot placer widget
// ---------------------------------------------------------------------------

class _HotspotPlacer extends StatelessWidget {
  const _HotspotPlacer({
    required this.area,
    required this.resolver,
    required this.position,
    required this.onPlaced,
    required this.onCleared,
  });

  final Area area;
  final RenpyAssetResolver resolver;
  final Offset? position;
  final void Function(Offset normalized) onPlaced;
  final VoidCallback onCleared;

  static const double _h = 120.0;

  void _openFullScreen(BuildContext context) {
    final absPath = resolver.resolve(area.backgroundPath);
    final bgFile = area.backgroundPath.isNotEmpty ? File(absPath) : null;
    final hasImage = bgFile != null && bgFile.existsSync();
    Offset? localPos = position;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        area.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (localPos != null)
                      TextButton(
                        onPressed: () {
                          setS(() => localPos = null);
                          onCleared();
                        },
                        child: const Text(
                          'Limpar',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    return GestureDetector(
                      onTapUp: (d) {
                        final nx =
                            (d.localPosition.dx / w).clamp(0.0, 1.0);
                        final ny =
                            (d.localPosition.dy / h).clamp(0.0, 1.0);
                        final p = Offset(nx, ny);
                        setS(() => localPos = p);
                        onPlaced(p);
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasImage)
                            Image.file(bgFile, fit: BoxFit.cover)
                          else
                            Container(
                              color: Colors.white12,
                              child: const Center(
                                child: Icon(Icons.landscape_outlined,
                                    size: 48, color: Colors.white38),
                              ),
                            ),
                          CustomPaint(painter: _CrosshairPainter()),
                          if (localPos != null)
                            Positioned(
                              left: localPos!.dx * w - 12,
                              top: localPos!.dy * h - 12,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.teal.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.place,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  localPos != null
                      ? 'Hotspot: (${(localPos!.dx * 100).toStringAsFixed(0)}%, ${(localPos!.dy * 100).toStringAsFixed(0)}%)'
                      : 'Clica na imagem para colocar o hotspot',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final absPath = resolver.resolve(area.backgroundPath);
    final bgFile = area.backgroundPath.isNotEmpty ? File(absPath) : null;
    final hasImage = bgFile != null && bgFile.existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                area.name,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),

                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => _openFullScreen(context),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.open_in_full,
                    size: 14, color: AppColors.textMuted),
              ),
            ),
            if (position != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onCleared,
                child: const Icon(Icons.close, size: 14,
                    color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: _h,
            decoration: BoxDecoration(
              color: AppColors.surfaceHighlight,
              border: Border.all(
                color: position != null
                    ? AppColors.teal
                    : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                final h = _h;
                return GestureDetector(
                  onTapUp: (d) {
                    final nx = (d.localPosition.dx / w).clamp(0.0, 1.0);
                    final ny = (d.localPosition.dy / h).clamp(0.0, 1.0);
                    onPlaced(Offset(nx, ny));
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasImage)
                        Image.file(bgFile, fit: BoxFit.cover)
                      else
                        const Center(
                          child: Icon(Icons.landscape_outlined,
                              size: 24, color: AppColors.textMuted),
                        ),
                      // grid hint
                      CustomPaint(painter: _CrosshairPainter()),
                      if (position != null)
                        Positioned(
                          left: position!.dx * w - 10,
                          top: position!.dy * h - 10,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: const Icon(Icons.place,
                                size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          position != null
              ? '(${(position!.dx * 100).toStringAsFixed(0)}%, ${(position!.dy * 100).toStringAsFixed(0)}%)'
              : 'Sem hotspot',
          style: TextStyle(
            color: position != null
                ? AppColors.teal
                : AppColors.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty sidebar state
// ---------------------------------------------------------------------------

class _EmptySidebar extends StatelessWidget {
  const _EmptySidebar({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 10),
          const Text(
            'Sem areas',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cria uma area para começar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Nova area', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += size.width / 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += size.height / 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
