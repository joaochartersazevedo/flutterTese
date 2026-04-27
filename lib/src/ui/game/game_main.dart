import 'dart:io';

import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/area.dart';
import '../../models/character.dart';
import '../../models/connection.dart';
import '../../models/task.dart';
import '../app_theme.dart';

class GameMain extends StatelessWidget {
  const GameMain({super.key, required this.engine, required this.onExit});
  final GameEngine engine;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) => _GameView(engine: engine, onExit: onExit),
    );
  }
}

// ---------- Main view ----------

class _GameView extends StatelessWidget {
  const _GameView({required this.engine, required this.onExit});
  final GameEngine engine;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final area = engine.currentArea;
    final bgFile = File(engine.areaBackgroundAbsolutePath(area));
    final chars = engine.currentCharacters;
    final inDialogue = engine.isInDialogue;
    final currentLine = engine.currentLine;
    final activeTasks = engine.activeTasks;

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

          // Darkening overlay
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0xDD000000)],
              ),
            ),
          ),

          // Character sprites — always visible, dimmed when not speaking
          if (chars.isNotEmpty)
            Positioned(
              bottom: inDialogue ? 200 : 100,
              left: 0,
              right: 0,
              child: _CharacterSprites(
                engine: engine,
                chars: chars,
                activeSpeakerId: inDialogue ? (currentLine?.speakerId) : null,
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
              onPressed: onExit,
              tooltip: 'Sair',
            ),
          ),

          // Active tasks panel (top-right, below exit)
          if (activeTasks.isNotEmpty && !inDialogue)
            Positioned(
              top: 52,
              right: 12,
              child: _TasksPanel(tasks: activeTasks, engine: engine),
            ),

          // Navigation bar (bottom, when not in dialogue)
          if (!inDialogue)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _NavigationBar(engine: engine),
            ),

          // Dialogue trigger buttons (right side, when not in dialogue)
          if (!inDialogue)
            _AreaDialogueButtons(engine: engine),

          // Dialogue box (bottom overlay)
          if (inDialogue && currentLine != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _DialogueBox(engine: engine),
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
        child: Text(area.name,
            style: const TextStyle(color: Colors.white12, fontSize: 64)),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: chars.map((c) {
        final bodyFile = File(engine.resolveAsset(c.bodyPath));
        final isSpeaking = activeSpeakerId == null || c.id == activeSpeakerId;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isSpeaking ? 1.0 : 0.35,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: bodyFile.existsSync()
                ? Image.file(bodyFile, height: 320, fit: BoxFit.contain)
                : _CharPlaceholder(name: c.name, colorHex: c.colorHex),
          ),
        );
      }).toList(),
    );
  }
}

class _CharPlaceholder extends StatelessWidget {
  const _CharPlaceholder({required this.name, required this.colorHex});
  final String name;
  final String colorHex;

  @override
  Widget build(BuildContext context) {
    Color col;
    try {
      col = Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      col = Colors.grey;
    }
    return Container(
      width: 80,
      height: 220,
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.2),
        border: Border.all(color: col.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text(name, style: TextStyle(color: col, fontSize: 12))),
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
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: conns.map((c) => _ConnButton(engine: engine, conn: c)).toList(),
    );
  }
}

class _ConnButton extends StatelessWidget {
  const _ConnButton({required this.engine, required this.conn});
  final GameEngine engine;
  final Connection conn;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: conn.locked ? null : () => engine.travelThrough(conn.id),
      style: FilledButton.styleFrom(
        backgroundColor: conn.locked
            ? Colors.white10
            : AppColors.primary.withValues(alpha: 0.25),
        foregroundColor: conn.locked ? Colors.white38 : Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(conn.locked ? Icons.lock : Icons.arrow_forward, size: 14),
          const SizedBox(width: 6),
          Text(engine.connectionLabel(conn)),
        ],
      ),
    );
  }
}

// ---------- Dialogue trigger buttons ----------

class _AreaDialogueButtons extends StatelessWidget {
  const _AreaDialogueButtons({required this.engine});
  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final dialogues = engine.currentAreaDialogues;
    if (dialogues.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 60,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: dialogues.map((d) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton.icon(
              onPressed: () => engine.startDialogue(d.id),
              icon: const Icon(Icons.chat_bubble_outline, size: 15),
              label: Text(d.name, style: const TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------- Tasks panel ----------

class _TasksPanel extends StatelessWidget {
  const _TasksPanel({required this.tasks, required this.engine});
  final List<Task> tasks;
  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.task_alt, size: 13, color: AppColors.accent),
              SizedBox(width: 6),
              Text('Tarefas',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          ...tasks.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.radio_button_unchecked,
                          size: 10, color: Colors.white54),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(t.name,
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              )),
        ],
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
    final dialogue = engine.currentDialogue!;
    if (line == null) return const SizedBox.shrink();

    final speakerName = engine.speakerName(line.speakerId);
    final portraitPath = engine.speakerPortraitPath(line.speakerId, line.emotionId);
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
              top: BorderSide(color: AppColors.dialogueBorder, width: 1)),
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
                        color: Colors.white, fontSize: 16, height: 1.55),
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
                        style: const TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: engine.skipDialogue,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Saltar',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: engine.advanceLine,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
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
      width: 90,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: speakerColor.withValues(alpha: 0.6), width: 1.5),
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
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}
