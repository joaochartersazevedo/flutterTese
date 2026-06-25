import 'dart:io';

import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/emotion.dart';
import '../app_theme.dart';
import 'emotion_wheel.dart';

/// In-game dialogue line box (speaker + text + continue/skip). Reused by the
/// game screen and the dialogue editor's preview.
class DialogueBox extends StatelessWidget {
  const DialogueBox({super.key, required this.engine});
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
            _Portrait(
              file: portraitFile,
              speakerColor: speakerColor,
              speakerName: speakerName,
            ),
            const SizedBox(width: 16),
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

/// In-game emotion-wheel choice box. Reused by the game screen and the
/// dialogue editor's preview.
class EmotionDialogueBox extends StatefulWidget {
  const EmotionDialogueBox({super.key, required this.engine});
  final GameEngine engine;

  @override
  State<EmotionDialogueBox> createState() => _EmotionDialogueBoxState();
}

class _EmotionDialogueBoxState extends State<EmotionDialogueBox> {
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
