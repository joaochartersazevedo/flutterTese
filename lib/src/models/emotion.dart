/// Russell's circumplex: valence (-1=neg, +1=pos) + arousal (-1=low, +1=high).
class CircumplexEmotion {
  const CircumplexEmotion({
    required this.id,
    required this.label,
    required this.valence,
    required this.arousal,
    required this.color,
  });

  final int id;
  final String label;
  final double valence;
  final double arousal;
  final String color; // #RRGGBB

  @override
  String toString() => label;
}

/// 16 emotions evenly spaced on the Geneva Emotion Wheel (22.5° each).
/// Position formula: valence = sin(θ), arousal = cos(θ), θ clockwise from top.
/// IDs 0-7 kept for backward compat with existing dialogues.
const List<CircumplexEmotion> emotionWheel = [
  // θ=315° — top-left: high arousal, negative valence
  CircumplexEmotion(id: 0, label: 'Furioso',      valence: -0.71, arousal:  0.71, color: '#DC143C'),
  // θ=270° — left: negative valence, neutral arousal
  CircumplexEmotion(id: 1, label: 'Nervoso',      valence: -1.00, arousal:  0.00, color: '#9932CC'),
  // θ=45°  — top-right: high arousal, positive valence
  CircumplexEmotion(id: 2, label: 'Alegre',       valence:  0.71, arousal:  0.71, color: '#FFA500'),
  // θ=225° — bottom-left: low arousal, negative valence
  CircumplexEmotion(id: 3, label: 'Triste',       valence: -0.71, arousal: -0.71, color: '#4682B4'),
  // θ=67.5° — right-top: positive valence, medium-high arousal
  CircumplexEmotion(id: 4, label: 'Animado',      valence:  0.92, arousal:  0.38, color: '#FF6600'),
  // θ=337.5° — near top, slightly negative valence
  CircumplexEmotion(id: 5, label: 'Enojado',      valence: -0.38, arousal:  0.92, color: '#8B4513'),
  // θ=157.5° — bottom-right: low arousal, slightly positive
  CircumplexEmotion(id: 6, label: 'Calmo',        valence:  0.38, arousal: -0.92, color: '#20B2AA'),
  // θ=112.5° — right-bottom: positive valence, slight negative arousal
  CircumplexEmotion(id: 7, label: 'Contente',     valence:  0.92, arousal: -0.38, color: '#32CD32'),
  // θ=0°   — top: max arousal, neutral valence
  CircumplexEmotion(id: 8, label: 'Surpreso',     valence:  0.00, arousal:  1.00, color: '#FFE500'),
  // θ=22.5° — top-right area
  CircumplexEmotion(id: 9, label: 'Entusiasmado', valence:  0.38, arousal:  0.92, color: '#FFB300'),
  // θ=90°  — right: max positive valence, neutral arousal
  CircumplexEmotion(id: 10, label: 'Prazer',      valence:  1.00, arousal:  0.00, color: '#FF69B4'),
  // θ=135° — bottom-right: positive valence, low arousal
  CircumplexEmotion(id: 11, label: 'Satisfeito',  valence:  0.71, arousal: -0.71, color: '#90EE90'),
  // θ=292.5° — left-top: negative valence, medium arousal
  CircumplexEmotion(id: 12, label: 'Ansioso',     valence: -0.92, arousal:  0.38, color: '#800080'),
  // θ=180° — bottom: min arousal, neutral valence
  CircumplexEmotion(id: 13, label: 'Aliviado',    valence:  0.00, arousal: -1.00, color: '#00CED1'),
  // θ=202.5° — bottom-left: slightly negative, low arousal
  CircumplexEmotion(id: 14, label: 'Entediado',   valence: -0.38, arousal: -0.92, color: '#778899'),
  // θ=247.5° — left-bottom: very negative, slight negative arousal
  CircumplexEmotion(id: 15, label: 'Envergonhado',valence: -0.92, arousal: -0.38, color: '#696969'),
];

CircumplexEmotion getEmotion(int id) {
  if (id < 0 || id >= emotionWheel.length) {
    return emotionWheel[6]; // fallback: Calmo
  }
  return emotionWheel[id];
}

int getClosestEmotionId(double valence, double arousal) {
  var closest = 0;
  var minDist = double.infinity;
  for (int i = 0; i < emotionWheel.length; i++) {
    final e = emotionWheel[i];
    final dist = (e.valence - valence).abs() + (e.arousal - arousal).abs();
    if (dist < minDist) {
      minDist = dist;
      closest = i;
    }
  }
  return closest;
}
