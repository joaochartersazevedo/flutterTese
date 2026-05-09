import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/emotion.dart';

/// Circular Geneva Emotion Wheel — 16 emotions arranged by circumplex angle.
/// Angle derived from: θ = atan2(valence, arousal), clockwise from top.
class EmotionWheel extends StatelessWidget {
  const EmotionWheel({
    super.key,
    required this.onEmotionSelected,
    this.onEmotionHovered,
    this.selectedEmotionId,
    this.hoveredEmotionId,
    this.activeIds,
    this.size = 300,
  });

  final Function(int emotionId) onEmotionSelected;
  final Function(int? emotionId)? onEmotionHovered;
  final int? selectedEmotionId;
  final int? hoveredEmotionId;

  /// If non-null, only these IDs are selectable; others appear dimmed.
  final Set<int>? activeIds;

  final double size;

  @override
  Widget build(BuildContext context) {
    final center = size / 2;
    final btnRadius = size * 0.333; // ring radius
    final btnSize = size * 0.122;   // button diameter
    final labelRadius = btnRadius + btnSize * 0.56;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Center label area
          Positioned(
            left: center - 28,
            top: center - 28,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white12, width: 1),
              ),
            ),
          ),

          // Labels first (behind buttons) so they don't intercept taps
          for (final emotion in emotionWheel)
            _buildLabel(emotion, center, btnRadius, btnSize, labelRadius),

          // Buttons last (on top) so tap hits are never blocked by labels
          for (final emotion in emotionWheel)
            _buildButton(emotion, center, btnRadius, btnSize),
        ],
      ),
    );
  }

  Widget _buildLabel(
    CircumplexEmotion emotion,
    double center,
    double btnRadius,
    double btnSize,
    double labelRadius,
  ) {
    final angle = math.atan2(emotion.valence, emotion.arousal);
    final lx = center + labelRadius * math.sin(angle);
    final ly = center - labelRadius * math.cos(angle);
    final color = Color(
      int.parse('FF${emotion.color.replaceAll('#', '')}', radix: 16),
    );
    final isSelected = selectedEmotionId == emotion.id;
    final isHovered = hoveredEmotionId == emotion.id;
    final isActive = activeIds == null || activeIds!.contains(emotion.id);
    final labelW = size * 0.27;
    final labelH = size * 0.12;

    return Positioned(
      left: lx - labelW / 2,
      top: ly - labelH / 2,
      width: labelW,
      height: labelH,
      child: IgnorePointer(
        child: Center(
          child: Text(
            emotion.label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: isActive
                  ? (isSelected || isHovered ? color : Colors.white)
                  : Colors.white.withValues(alpha: 0.2),
              fontSize: size * 0.038,
              fontWeight: (isSelected || isHovered) ? FontWeight.w700 : (isActive ? FontWeight.w600 : FontWeight.w400),
              shadows: isActive
                  ? const [Shadow(color: Colors.black87, blurRadius: 6)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    CircumplexEmotion emotion,
    double center,
    double btnRadius,
    double btnSize,
  ) {
    final angle = math.atan2(emotion.valence, emotion.arousal);
    final bx = center + btnRadius * math.sin(angle);
    final by = center - btnRadius * math.cos(angle);
    final color = Color(
      int.parse('FF${emotion.color.replaceAll('#', '')}', radix: 16),
    );
    final isSelected = selectedEmotionId == emotion.id;
    final isHovered = hoveredEmotionId == emotion.id;
    final isActive = activeIds == null || activeIds!.contains(emotion.id);

    return Positioned(
      left: bx - btnSize / 2,
      top: by - btnSize / 2,
      width: btnSize,
      height: btnSize,
      child: MouseRegion(
        onEnter: isActive ? (_) => onEmotionHovered?.call(emotion.id) : null,
        onExit: isActive ? (_) => onEmotionHovered?.call(null) : null,
        child: GestureDetector(
          onTap: isActive ? () => onEmotionSelected(emotion.id) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? color
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isActive
                    ? (isSelected || isHovered ? Colors.white : Colors.white.withValues(alpha: 0.6))
                    : Colors.white.withValues(alpha: 0.1),
                width: (isSelected || isHovered) ? 3 : 1.5,
              ),
              boxShadow: isActive && !isSelected && !isHovered
                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                  : (isSelected || isHovered)
                      ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 14, spreadRadius: 2)]
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}
