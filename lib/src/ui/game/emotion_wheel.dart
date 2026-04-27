import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/emotion.dart';

const double _wheelDotRadius = 18.0;
const double _wheelRingPadding = 36.0;

/// Emotion wheel laid out on circle for quick selection.
class EmotionWheel extends StatefulWidget {
  const EmotionWheel({
    super.key,
    required this.onEmotionSelected,
    this.selectedEmotionId,
    this.size = 480,
  });

  final Function(int emotionId) onEmotionSelected;
  final int? selectedEmotionId;
  final double size;

  @override
  State<EmotionWheel> createState() => _EmotionWheelState();
}

class _EmotionWheelState extends State<EmotionWheel> {
  int? _hoveredId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _handleTap(details.localPosition),
      child: CustomPaint(
        painter: _CircumplexPainter(
          hoveredId: _hoveredId,
          selectedId: widget.selectedEmotionId,
        ),
        size: Size(widget.size, widget.size),
      ),
    );
  }

  void _handleTap(Offset pos) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final radius = (widget.size / 2) - _wheelDotRadius - _wheelRingPadding;
    final selected = _closestEmotionAt(pos, center, radius);
    if (selected != null) {
      widget.onEmotionSelected(selected);
    }
  }

  int? _closestEmotionAt(Offset pos, Offset center, double radius) {
    int? closestId;
    var minDist = double.infinity;
    final count = emotionWheel.length;
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi * i / count) - (math.pi / 2);
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      final dist = (pos - Offset(x, y)).distance;
      if (dist < minDist) {
        minDist = dist;
        closestId = emotionWheel[i].id;
      }
    }
    if (minDist <= (_wheelDotRadius + 10)) return closestId;
    return null;
  }
}

class _CircumplexPainter extends CustomPainter {
  _CircumplexPainter({this.hoveredId, this.selectedId});
  final int? hoveredId;
  final int? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - _wheelRingPadding;

    _drawRing(canvas, center, radius);
    _drawEmotionButtons(canvas, center, radius);
  }

  void _drawRing(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, ringPaint);
  }

  void _drawEmotionButtons(Canvas canvas, Offset center, double radius) {
    final count = emotionWheel.length;
    for (var i = 0; i < count; i++) {
      final emotion = emotionWheel[i];
      final angle = (2 * math.pi * i / count) - (math.pi / 2);
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      var color = Color(int.parse(emotion.color.replaceAll('#', 'FF'), radix: 16));
      if (hoveredId == emotion.id) {
        color = Color.lerp(color, Colors.white, 0.3)!;
      }

      // Circle
      canvas.drawCircle(Offset(x, y), _wheelDotRadius, Paint()..color = color);

      if (selectedId == emotion.id) {
        canvas.drawCircle(
          Offset(x, y),
          _wheelDotRadius + 4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }

      // Label text inside circle
      _drawText(
        canvas,
        emotion.label,
        Offset(x, y - 4),
        const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
        align: true,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    bool align = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    
    final finalOffset = align
        ? Offset(offset.dx - tp.width / 2, offset.dy - tp.height / 2)
        : offset;
    
    tp.paint(canvas, finalOffset);
  }

  @override
  bool shouldRepaint(_CircumplexPainter oldDelegate) =>
      oldDelegate.hoveredId != hoveredId;
}
