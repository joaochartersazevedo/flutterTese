class DialogueLine {
  DialogueLine({required this.speakerId, required this.text, this.portraitId});

  int speakerId;
  String text;

  int? portraitId;
}

/// A player emotion choice point in a playerChat dialogue.
/// Each active emotionId maps to the one line the player says when choosing it.
class DialogueChoice {
  DialogueChoice({Map<int, String>? choices})
    : choices = Map<int, String>.from(choices ?? {});

  Map<int, String> choices;

  bool hasChoice(int id) => (choices[id]?.isNotEmpty ?? false);

  DialogueChoice copyWith({Map<int, String>? choices}) =>
      DialogueChoice(choices: choices ?? this.choices);
}

/// A single node in a playerChat dialogue sequence.
/// Exactly one of [line] or [choice] is non-null.
class DialogueNode {
  DialogueNode({this.line, this.choice});

  DialogueLine? line;
  DialogueChoice? choice;
  DialogueNode? nextNode;
  Map<int, DialogueNode>? children;

  bool get isChoice => choice != null;
  bool get isLine => line != null;

  void dispose() {
    nextNode?.dispose();
    children?.values.forEach((n) => n.dispose());
  }

  DialogueNode copyWith({DialogueLine? line, DialogueChoice? choice}) =>
      DialogueNode(line: line ?? this.line, choice: choice ?? this.choice);

  void setNext(DialogueNode node) => nextNode = node;

  void addChild(int emotionId, DialogueNode node) {
    children ??= {};
    children![emotionId] = node;
  }
}

class Dialogue {
  Dialogue({
    required this.id,
    required this.name,
    required this.characterIds,
    required this.parentNode,
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

  final DialogueNode parentNode;

  final bool singleTrigger;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;
  final bool selfRemove;
  final int priority;
  final int? areaId;
  final String? topic;
}
