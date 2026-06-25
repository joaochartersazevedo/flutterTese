import 'dart:io';

import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/area.dart';
import '../../models/character.dart';
import '../../models/connection.dart';
import '../../models/save_data.dart';
import '../app_theme.dart';
import 'dialogue_box.dart';

class GameMain extends StatelessWidget {
  const GameMain({
    super.key,
    required this.engine,
    this.currentSave,
    required this.onExit,
  });

  final GameEngine engine;
  final SaveData? currentSave;
  final Future<void> Function() onExit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) =>
          _GameView(engine: engine, currentSave: currentSave, onExit: onExit),
    );
  }
}

// ---------- Main view ----------

class _GameView extends StatefulWidget {
  const _GameView({
    required this.engine,
    this.currentSave,
    required this.onExit,
  });

  final GameEngine engine;
  final SaveData? currentSave;
  final Future<void> Function() onExit;

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> {
  bool _showDebug = false;

  Future<void> _exitGame() async {
    await widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final area = engine.currentArea;
    final bgFile = File(engine.areaBackgroundAbsolutePath(area));
    final chars = engine.currentCharacters;
    final inDialogue = engine.isInDialogue;
    final currentLine = engine.currentLine;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          if (bgFile.existsSync())
            Image.file(bgFile, fit: BoxFit.cover)
          else
            _GradientBg(area: area),

          // Character sprites — above background, below HUD/dialogue
          if (chars.isNotEmpty)
            Positioned.fill(
              child: _CharacterSprites(
                engine: engine,
                chars: chars,
                activeSpeakerId: inDialogue ? currentLine?.speakerId : null,
              ),
            ),

          // Top vignette for HUD readability
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Colors.transparent],
                stops: [0.0, 0.22],
              ),
            ),
          ),

          // Area name + clock
          Positioned(
            top: 16,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
                Text(
                  engine.formattedTime,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),

          // Debug panel
          if (_showDebug)
            Positioned(
              top: 50,
              left: 8,
              child: _DebugPanel(engine: engine),
            ),

          // Exit + debug toggle buttons
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.bug_report_outlined,
                    color: _showDebug ? Colors.greenAccent : Colors.white38,
                  ),
                  tooltip: 'Debug tags',
                  onPressed: () => setState(() => _showDebug = !_showDebug),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: _exitGame,
                  tooltip: 'Sair',
                ),
              ],
            ),
          ),

          // Navigation (spatial hotspots or card fallback, only when not in dialogue)
          if (!inDialogue)
            Positioned.fill(
              child: _NavigationLayer(engine: engine),
            ),

          // Emotion wheel overlay (playerChat, after prologue exhausted)
          if (inDialogue && engine.emotionModeActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: EmotionDialogueBox(engine: engine),
            ),

          // Dialogue box (regular lines + branch lines)
          if (inDialogue && currentLine != null && !engine.emotionModeActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: DialogueBox(engine: engine),
            ),

          // Game over overlay
          if (engine.isGameOver)
            Positioned.fill(
              child: _GameOverOverlay(onExit: _exitGame),
            ),
        ],
      ),
    );
  }
}

// ---------- Background fallback ----------

class _GradientBg extends StatelessWidget {
  const _GradientBg({required this.area});
  final Area area;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1628), Color(0xFF0D2240)],
        ),
      ),
      child: Center(
        child: Text(
          area.name,
          style: const TextStyle(color: Colors.white12, fontSize: 64),
        ),
      ),
    );
  }
}

// ---------- Character sprites ----------

class _CharacterSprites extends StatelessWidget {
  const _CharacterSprites({
    required this.engine,
    required this.chars,
    this.activeSpeakerId,
  });
  final GameEngine engine;
  final List<Character> chars;
  final int? activeSpeakerId;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final spriteH = screenH * 0.82;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chars.map((c) {
          final bodyFile = File(engine.resolveAsset(c.bodyPath));
          final isSpeaking = activeSpeakerId == null || c.id == activeSpeakerId;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isSpeaking ? 1.0 : 0.4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: bodyFile.existsSync()
                  ? Image.file(bodyFile, height: spriteH, fit: BoxFit.contain)
                  : _CharPlaceholder(name: c.name, colorHex: c.colorHex, height: spriteH * 0.6),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CharPlaceholder extends StatelessWidget {
  const _CharPlaceholder({required this.name, required this.colorHex, this.height = 330});
  final String name;
  final String colorHex;
  final double height;

  @override
  Widget build(BuildContext context) {
    Color col;
    try {
      col = Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      col = Colors.grey;
    }
    return Container(
      width: 110,
      height: height,
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.2),
        border: Border.all(color: col.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(name, style: TextStyle(color: col, fontSize: 12)),
      ),
    );
  }
}

// ---------- Navigation layer (spatial hotspots + fallback cards) ----------

class _NavigationLayer extends StatelessWidget {
  const _NavigationLayer({required this.engine});
  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final conns = engine.currentConnections;
    if (conns.isEmpty) return const SizedBox.shrink();

    final currentAreaId = engine.currentArea.id;
    final spatial = conns.where((c) => c.hotspotForArea(currentAreaId) != null).toList();
    final cardFallback = conns.where((c) => c.hotspotForArea(currentAreaId) == null).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Spatial hotspots
        for (final conn in spatial)
          _SpatialHotspot(engine: engine, conn: conn, currentAreaId: currentAreaId),

        // "Stay and chat" button + fallback cards at bottom
        if (engine.hasPendingAreaDialogue || cardFallback.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (engine.hasPendingAreaDialogue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: engine.stayAndChat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Continuar aqui',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (cardFallback.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: cardFallback
                        .map((c) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child:
                                  _AreaCard(engine: engine, conn: c),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------- Spatial hotspot ----------

class _SpatialHotspot extends StatefulWidget {
  const _SpatialHotspot({
    required this.engine,
    required this.conn,
    required this.currentAreaId,
  });
  final GameEngine engine;
  final Connection conn;
  final int currentAreaId;

  @override
  State<_SpatialHotspot> createState() => _SpatialHotspotState();
}

class _SpatialHotspotState extends State<_SpatialHotspot>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conn = widget.conn;
    final hot = conn.hotspotForArea(widget.currentAreaId)!;
    final destId = conn.destinationFor(widget.currentAreaId);
    final dest = widget.engine.allAreas
        .where((a) => a.id == destId)
        .firstOrNull;
    final label = conn.label.isNotEmpty
        ? conn.label
        : (dest?.name ?? 'Area $destId');

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = hot.dx * w;
        final cy = hot.dy * h;

        return AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            final ringSize = 44.0 + _pulseAnim.value * 16;
            return Stack(
              children: [
                // Pulsing ring
                if (!conn.locked)
                  Positioned(
                    left: cx - ringSize / 2,
                    top: cy - ringSize / 2,
                    child: IgnorePointer(
                      child: Container(
                        width: ringSize,
                        height: ringSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(
                                alpha: 0.25 - _pulseAnim.value * 0.2),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Main hotspot button
                Positioned(
                  left: cx - 22,
                  top: cy - 22,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hovered = true),
                    onExit: (_) => setState(() => _hovered = false),
                    child: GestureDetector(
                      onTap: conn.locked
                          ? null
                          : () => widget.engine.travelThrough(conn.id),
                      child: AnimatedScale(
                        scale: _hovered ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: conn.locked
                                ? Colors.black.withValues(alpha: 0.55)
                                : Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: conn.locked
                                  ? Colors.white24
                                  : Colors.white60,
                              width: 1.5,
                            ),
                            boxShadow: conn.locked
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    )
                                  ],
                          ),
                          child: Icon(
                            conn.locked
                                ? Icons.lock
                                : Icons.arrow_forward_rounded,
                            color: conn.locked
                                ? Colors.white24
                                : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Label tooltip below
                Positioned(
                  left: cx - 60,
                  top: cy + 26,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: conn.locked
                              ? Colors.white38
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------- Fallback area card ----------

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.engine, required this.conn});
  final GameEngine engine;
  final Connection conn;

  static const double _cardW = 160;
  static const double _cardH = 280;

  @override
  Widget build(BuildContext context) {
    final destId = conn.destinationFor(engine.currentArea.id);
    final dest = engine.allAreas.where((a) => a.id == destId).firstOrNull;
    final destName = dest?.name ?? 'Area $destId';
    final bgPath = dest != null ? engine.areaBackgroundAbsolutePath(dest) : '';
    final bgFile = bgPath.isNotEmpty ? File(bgPath) : null;
    final hasThumb = bgFile != null && bgFile.existsSync();

    return GestureDetector(
      onTap: conn.locked ? null : () => engine.travelThrough(conn.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: _cardW,
        height: _cardH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: conn.locked ? Colors.white12 : Colors.white38,
            width: 1.5,
          ),
          boxShadow: conn.locked
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasThumb)
              Image.file(bgFile, fit: BoxFit.cover)
            else
              Container(color: Colors.white.withValues(alpha: 0.07)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black
                        .withValues(alpha: conn.locked ? 0.75 : 0.6),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            if (conn.locked)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.lock, color: Colors.white38, size: 16),
              ),
            if (!conn.locked)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 18,
                ),
              ),
            Positioned(
              bottom: 10,
              left: 8,
              right: 8,
              child: Text(
                destName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: conn.locked ? Colors.white38 : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 6)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Debug panel ----------

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.engine});
  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final active = engine.activeGameStates;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220, maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TAGS ATIVAS',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          if (active.isEmpty)
            const Text(
              'Nenhuma',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: active
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Game over ----------

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.onExit});
  final Future<void> Function() onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'FIM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w800,
                letterSpacing: 12,
              ),
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: onExit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text('Sair', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

