class DialogueLine {
  const DialogueLine({
    required this.speakerId,
    required this.emotionId,
    required this.text,
  });

  final int speakerId;
  final int emotionId;
  final String text;
}

class Dialogue {
  const Dialogue({
    required this.id,
    required this.name,
    required this.characterIds,
    required this.lines,
    required this.singleTrigger,
    required this.preconditions,
    required this.consequences,
    this.selfRemove = false,
    this.priority = 0,
    this.areaId,
    this.topic,
  });

  final int id;
  final String name;
  final List<int> characterIds;
  final List<DialogueLine> lines;
  final bool singleTrigger;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;
  final bool selfRemove;
  final int priority;
  final int? areaId;
  final String? topic;
}
