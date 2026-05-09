import 'dart:io';

import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/area.dart';
import '../../models/character.dart';
import '../../models/connection.dart';
import '../../models/emotion.dart';
import '../../models/save_data.dart';
import '../app_theme.dart';
import 'emotion_wheel.dart';

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

class _GameView extends StatelessWidget {
  const _GameView({
    required this.engine,
    this.currentSave,
    required this.onExit,
  });

  final GameEngine engine;
  final SaveData? currentSave;
  final Future<void> Function() onExit;

  Future<void> _exitGame() async {
    await onExit();
  }

  @override
  Widget build(BuildContext context) {
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

          // Exit button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: _exitGame,
              tooltip: 'Sair',
            ),
          ),

          // Navigation cards (screen center, only when not in dialogue)
          if (!inDialogue)
            Positioned.fill(
              child: Center(child: _NavigationBar(engine: engine)),
            ),

          // Emotion wheel overlay (playerChat, after prologue exhausted)
          if (inDialogue && engine.emotionModeActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _EmotionDialogueBox(engine: engine),
            ),

          // Dialogue box (regular lines + branch lines)
          if (inDialogue && currentLine != null && !engine.emotionModeActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _DialogueBox(engine: engine),
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

// ---------- Navigation ----------

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.engine});
  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final conns = engine.currentConnections;
    if (conns.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (engine.hasPendingAreaDialogue)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: engine.stayAndChat,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Continuar aqui',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: conns.map((c) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _AreaCard(engine: engine, conn: c),
          )).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

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
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            if (hasThumb)
              Image.file(bgFile, fit: BoxFit.cover)
            else
              Container(color: Colors.white.withValues(alpha: 0.07)),

            // Scrim
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: conn.locked ? 0.75 : 0.6),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),

            // Lock icon
            if (conn.locked)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.lock, color: Colors.white38, size: 16),
              ),

            // Arrow
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

            // Area name
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
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Dialogue box ----------

class _DialogueBox extends StatelessWidget {
  const _DialogueBox({required this.engine});
  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final line = engine.currentLine;
    if (line == null) return const SizedBox.shrink();
    final dialogue = engine.currentDialogue!;

    final speakerName = engine.speakerName(line.speakerId);
    final portraitPath = engine.speakerPortraitPath(
      line.speakerId,
      line.portraitId,
    );
    final portraitFile = portraitPath.isNotEmpty ? File(portraitPath) : null;

    Color speakerColor;
    try {
      final hex = engine.speakerColor(line.speakerId).replaceAll('#', '');
      speakerColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      speakerColor = Colors.white;
    }

    return GestureDetector(
      onTap: engine.advanceLine,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.dialogueBg,
          border: const Border(
            top: BorderSide(color: AppColors.dialogueBorder, width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portrait
            _Portrait(
              file: portraitFile,
              speakerColor: speakerColor,
              speakerName: speakerName,
            ),
            const SizedBox(width: 16),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    speakerName,
                    style: TextStyle(
                      color: speakerColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    line.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Progress dots
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(engine.totalLines, (i) {
                          final active = i == engine.currentLineIndex;
                          return Container(
                            margin: const EdgeInsets.only(right: 4),
                            width: active ? 14 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      Text(
                        dialogue.name,
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: engine.skipDialogue,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Saltar',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: engine.advanceLine,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          engine.currentLineIndex + 1 >= engine.totalLines
                              ? 'Fechar'
                              : 'Continuar',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
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

// ---------- Emotion dialogue box (playerChat) ----------

class _EmotionDialogueBox extends StatefulWidget {
  const _EmotionDialogueBox({required this.engine});
  final GameEngine engine;

  @override
  State<_EmotionDialogueBox> createState() => _EmotionDialogueBoxState();
}

class _EmotionDialogueBoxState extends State<_EmotionDialogueBox> {
  int? _hoveredEmotionId;

  @override
  Widget build(BuildContext context) {
    final choiceNode = widget.engine.currentChoiceNode;
    if (choiceNode == null) return const SizedBox.shrink();

    final dialogue = widget.engine.currentDialogue!;
    final playerId = dialogue.characterIds.firstWhere(
      (id) => id == 0,
      orElse: () => 0,
    );
    final playerName = widget.engine.speakerName(playerId);
    final activeIds = widget.engine.availableEmotionIds;

    final hoveredEmotion =
        _hoveredEmotionId != null ? getEmotion(_hoveredEmotionId!) : null;
    final hoveredLine = _hoveredEmotionId != null
        ? widget.engine.playerLineForEmotion(_hoveredEmotionId!)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogueBg,
        border: const Border(
          top: BorderSide(color: AppColors.dialogueBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Wheel
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$playerName: Escolhe emoção',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              EmotionWheel(
                size: 300,
                hoveredEmotionId: _hoveredEmotionId,
                activeIds: activeIds,
                onEmotionHovered: (id) =>
                    setState(() => _hoveredEmotionId = id),
                onEmotionSelected: (id) {
                  if (activeIds.contains(id)) {
                    widget.engine.selectEmotion(id);
                    setState(() => _hoveredEmotionId = null);
                  }
                },
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Hover preview panel
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: hoveredEmotion != null
                  ? _EmotionPreview(
                      key: ValueKey(_hoveredEmotionId),
                      playerName: playerName,
                      emotion: hoveredEmotion,
                      line: hoveredLine ?? '',
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmotionPreview extends StatelessWidget {
  const _EmotionPreview({
    super.key,
    required this.playerName,
    required this.emotion,
    required this.line,
  });

  final String playerName;
  final CircumplexEmotion emotion;
  final String line;

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse('FF${emotion.color.replaceAll('#', '')}', radix: 16),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                emotion.label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$playerName: $line',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
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

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.file,
    required this.speakerColor,
    required this.speakerName,
  });
  final File? file;
  final Color speakerColor;
  final String speakerName;

  @override
  Widget build(BuildContext context) {
    final hasImage = file != null && file!.existsSync();
    return Container(
      width: 140,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: speakerColor.withValues(alpha: 0.6),
          width: 2,
        ),
        color: hasImage ? null : speakerColor.withValues(alpha: 0.12),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.file(file!, fit: BoxFit.cover)
          : Center(
              child: Text(
                speakerName.isNotEmpty ? speakerName[0] : '?',
                style: TextStyle(
                  color: speakerColor,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}
