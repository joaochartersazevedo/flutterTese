/// Russell's circumplex: valence (-1=neg, +1=pos) + arousal (-1=low, +1=high).
/// Emotion positioned by (valence, arousal) coordinates on 2D plane.
class CircumplexEmotion {
  const CircumplexEmotion({
    required this.id,
    required this.label,
    required this.valence,  // -1.0 to +1.0
    required this.arousal,  // -1.0 to +1.0
    required this.color,
  });

  final int id;           // 0-15
  final String label;
  final double valence;
  final double arousal;
  final String color;     // #RRGGBB

  @override
  String toString() => label;
}

/// 16 emotions arranged by Russell's circumplex psychology.
const List<CircumplexEmotion> emotionWheel = [
  // Negative-High Arousal (angry, tense)
  CircumplexEmotion(id: 0, label: 'Furioso', valence: -0.8, arousal: 0.9, color: '#C0392B'),
  CircumplexEmotion(id: 1, label: 'Tenso', valence: -0.6, arousal: 0.8, color: '#E74C3C'),
  
  // Negative-Low Arousal (sad, depressed)
  CircumplexEmotion(id: 2, label: 'Triste', valence: -0.7, arousal: -0.4, color: '#8E44AD'),
  CircumplexEmotion(id: 3, label: 'Deprimido', valence: -0.9, arousal: -0.7, color: '#6C3483'),
  
  // Negative-Medium (afraid, upset)
  CircumplexEmotion(id: 4, label: 'Assustado', valence: -0.5, arousal: 0.2, color: '#3498DB'),
  CircumplexEmotion(id: 5, label: 'Nojado', valence: -0.8, arousal: 0.5, color: '#7B241C'),
  
  // Positive-Low Arousal (calm, content)
  CircumplexEmotion(id: 6, label: 'Calmo', valence: 0.7, arousal: -0.8, color: '#27AE60'),
  CircumplexEmotion(id: 7, label: 'Contente', valence: 0.8, arousal: -0.3, color: '#95E1D3'),
  
  // Positive-High Arousal (excited, happy)
  CircumplexEmotion(id: 8, label: 'Excitado', valence: 0.8, arousal: 0.8, color: '#F39C12'),
  CircumplexEmotion(id: 9, label: 'Alegre', valence: 0.9, arousal: 0.9, color: '#52C46A'),
  
  // Positive-Medium (serene)
  CircumplexEmotion(id: 10, label: 'Sereno', valence: 0.6, arousal: 0.1, color: '#16A085'),
  CircumplexEmotion(id: 11, label: 'Animado', valence: 0.7, arousal: 0.7, color: '#F4D03F'),
  
  // Neutral-ish
  CircumplexEmotion(id: 12, label: 'Cansado', valence: -0.2, arousal: -0.9, color: '#95A5A6'),
  CircumplexEmotion(id: 13, label: 'Neutro', valence: 0.0, arousal: 0.0, color: '#BDC3C7'),
  CircumplexEmotion(id: 14, label: 'Surpreso', valence: 0.3, arousal: 0.8, color: '#D68910'),
  CircumplexEmotion(id: 15, label: 'Nervoso', valence: -0.3, arousal: 0.6, color: '#9B59B6'),
];

/// Get emotion by ID (0-15).
CircumplexEmotion getEmotion(int id) {
  if (id < 0 || id >= emotionWheel.length) {
    return emotionWheel[13]; // fallback: neutro
  }
  return emotionWheel[id];
}

/// Find closest emotion to (valence, arousal) coordinates.
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
