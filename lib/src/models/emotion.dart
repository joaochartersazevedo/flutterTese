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

const List<CircumplexEmotion> emotionWheel = [
  CircumplexEmotion(
    id: 0,
    label: 'Furioso',
    valence: -0.8,
    arousal: 0.9,
    color: '#7FFF00', // 135° - yellow-green (top-left)
  ),
  CircumplexEmotion(
    id: 1,
    label: 'Nervoso',
    valence: -0.3,
    arousal: 0.6,
    color: '#FFFF00', // 90° - yellow (top-center)
  ),
  CircumplexEmotion(
    id: 2,
    label: 'Alegre',
    valence: 0.9,
    arousal: 0.9,
    color: '#FF7F00', // 45° - orange (top-right)
  ),
  CircumplexEmotion(
    id: 3,
    label: 'Triste',
    valence: -0.7,
    arousal: -0.4,
    color: '#00FF00', // 180° - green (left)
  ),
  CircumplexEmotion(
    id: 4,
    label: 'Animado',
    valence: 0.7,
    arousal: 0.7,
    color: '#FF0000', // 0° - red (right)
  ),
  CircumplexEmotion(
    id: 5,
    label: 'Enojado',
    valence: -0.8,
    arousal: 0.5,
    color: '#00FFFF', // 225° - cyan (bottom-left)
  ),
  CircumplexEmotion(
    id: 6,
    label: 'Calmo',
    valence: 0.7,
    arousal: -0.8,
    color: '#0000FF', // 270° - blue (bottom-center)
  ),
  CircumplexEmotion(
    id: 7,
    label: 'Contente',
    valence: 0.8,
    arousal: -0.3,
    color: '#8B00FF', // 315° - violet (bottom-right)
  ),
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
