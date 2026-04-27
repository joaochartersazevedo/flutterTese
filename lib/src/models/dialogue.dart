enum DialogueType { text, chat, localized, playerChat }

class DialogueLine {
  const DialogueLine({
    required this.speakerId,
    required this.emotionId,
    required this.text,
  });

  final int speakerId;
  final int emotionId;
  final String text;

  DialogueLine copyWith({int? speakerId, int? emotionId, String? text}) =>
      DialogueLine(
        speakerId: speakerId ?? this.speakerId,
        emotionId: emotionId ?? this.emotionId,
        text: text ?? this.text,
      );
}

/// One emotion branch for a playerChat dialogue.
/// emotionId matches the EMOTION_WHEEL index (0-15).
class PlayerEmotionBranch {
  const PlayerEmotionBranch({
    required this.emotionId,
    this.playerLine = '',
    this.npcResponse = '',
  });

  final int emotionId;
  final String playerLine;
  final String npcResponse;

  PlayerEmotionBranch copyWith({
    String? playerLine,
    String? npcResponse,
  }) =>
      PlayerEmotionBranch(
        emotionId: emotionId,
        playerLine: playerLine ?? this.playerLine,
        npcResponse: npcResponse ?? this.npcResponse,
      );
}

class Dialogue {
  const Dialogue({
    required this.id,
    required this.name,
    required this.type,
    required this.characterIds,
    required this.lines,
    required this.singleTrigger,
    required this.preconditions,
    required this.consequences,
    this.selfRemove = false,
    this.priority = 0,
    this.areaId,
    this.topic,
    this.playerEmotions = const {},
  });

  final int id;
  final String name;
  final DialogueType type;
  final List<int> characterIds;
  final List<DialogueLine> lines;
  final bool singleTrigger;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;
  final bool selfRemove;
  final int priority;
  final int? areaId;
  final String? topic;

  /// Emotion branches for playerChat type. Key = emotionId (0-15).
  final Map<int, PlayerEmotionBranch> playerEmotions;
}
