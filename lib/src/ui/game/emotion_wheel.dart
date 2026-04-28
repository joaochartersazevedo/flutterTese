import 'package:flutter/material.dart';

import '../../models/emotion.dart';

// Grid col/row for each emotion id (0-7). Center cell (col=1, row=1) is empty.
const _gridCols = [0, 1, 2, 0, 2, 0, 1, 2];
const _gridRows = [0, 0, 0, 1, 1, 2, 2, 2];

/// 3×3 emotion grid (center empty) for player emotion selection.
class EmotionWheel extends StatelessWidget {
  const EmotionWheel({
    super.key,
    required this.onEmotionSelected,
    this.selectedEmotionId,
    this.activeIds,
    this.size = 300,
  });

  final Function(int emotionId) onEmotionSelected;
  final int? selectedEmotionId;

  /// If non-null, only these emotion IDs are selectable; others appear dimmed.
  final Set<int>? activeIds;

  final double size;

  @override
  Widget build(BuildContext context) {
    final cellSize = size / 3;
    final gap = size * 0.02;
    final innerCell = cellSize - gap * 2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < emotionWheel.length; i++)
            _buildCell(emotionWheel[i], cellSize, gap, innerCell),
        ],
      ),
    );
  }

  Widget _buildCell(
    CircumplexEmotion emotion,
    double cellSize,
    double gap,
    double innerCell,
  ) {
    final col = _gridCols[emotion.id];
    final row = _gridRows[emotion.id];
    final color = Color(
      int.parse('FF${emotion.color.replaceAll('#', '')}', radix: 16),
    );
    final isSelected = selectedEmotionId == emotion.id;
    final isActive = activeIds == null || activeIds!.contains(emotion.id);

    return Positioned(
      left: col * cellSize + gap,
      top: row * cellSize + gap,
      width: innerCell,
      height: innerCell,
      child: GestureDetector(
        onTap: isActive ? () => onEmotionSelected(emotion.id) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: isActive
                ? (isSelected ? color : color.withValues(alpha: 0.65))
                : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? (isSelected ? Colors.white : color.withValues(alpha: 0.9))
                  : color.withValues(alpha: 0.3),
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              emotion.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white38,
                fontSize: innerCell * 0.14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                shadows: isActive
                    ? const [Shadow(color: Colors.black45, blurRadius: 4)]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
