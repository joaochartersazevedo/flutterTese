class DialogueLine {
  DialogueLine({required this.speakerId, required this.text, this.portraitId});

  int speakerId;
  String text;
  int? portraitId;

  Map<String, dynamic> toJson() => {
        'speakerId': speakerId,
        'text': text,
        if (portraitId != null) 'portraitId': portraitId,
      };

  factory DialogueLine.fromJson(Map<String, dynamic> j) => DialogueLine(
        speakerId: j['speakerId'] as int,
        text: j['text'] as String,
        portraitId: j['portraitId'] as int?,
      );
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

  Map<String, dynamic> toJson() =>
      {'choices': choices.map((k, v) => MapEntry(k.toString(), v))};

  factory DialogueChoice.fromJson(Map<String, dynamic> j) => DialogueChoice(
        choices: (j['choices'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as String)),
      );
}

/// A single node in a playerChat dialogue sequence.
/// Exactly one of [line] or [choice] is non-null.
class DialogueNode {
  DialogueNode({
    this.line,
    this.choice,
    Map<int, bool>? branchConsequences,
  }) : branchConsequences = branchConsequences ?? {};

  DialogueLine? line;
  DialogueChoice? choice;
  DialogueNode? nextNode;
  Map<int, DialogueNode>? children;

  /// Flags applied when dialogue exits through this node (leaf-only, try-set semantics).
  Map<int, bool> branchConsequences;

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

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      if (branchConsequences.isNotEmpty)
        'branchConsequences':
            branchConsequences.map((k, v) => MapEntry(k.toString(), v)),
    };
    if (line != null) {
      m['type'] = 'line';
      m['line'] = line!.toJson();
      if (nextNode != null) m['next'] = nextNode!.toJson();
    } else {
      m['type'] = 'choice';
      m['choice'] = choice!.toJson();
      if (children != null) {
        m['children'] =
            children!.map((k, v) => MapEntry(k.toString(), v.toJson()));
      }
      if (nextNode != null) m['next'] = nextNode!.toJson();
    }
    return m;
  }

  factory DialogueNode.fromJson(Map<String, dynamic> j) {
    final bc = (j['branchConsequences'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(int.parse(k), v as bool)) ??
        {};
    final type = j['type'] as String;
    DialogueNode node;
    if (type == 'line') {
      node = DialogueNode(
        line: DialogueLine.fromJson(j['line'] as Map<String, dynamic>),
        branchConsequences: bc,
      );
    } else {
      node = DialogueNode(
        choice: DialogueChoice.fromJson(j['choice'] as Map<String, dynamic>),
        branchConsequences: bc,
      );
      if (j['children'] != null) {
        for (final entry in (j['children'] as Map<String, dynamic>).entries) {
          node.addChild(
            int.parse(entry.key),
            DialogueNode.fromJson(entry.value as Map<String, dynamic>),
          );
        }
      }
    }
    if (j['next'] != null) {
      node.setNext(DialogueNode.fromJson(j['next'] as Map<String, dynamic>));
    }
    return node;
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
    this.areaIds = const [],
    this.topic,
    this.isEnding = false,
    this.groupId,
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
  /// Empty = triggers in any area. Non-empty = only in listed areas.
  final List<int> areaIds;
  final String? topic;
  final bool isEnding;
  final int? groupId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'characterIds': characterIds,
        'parentNode': parentNode.toJson(),
        'singleTrigger': singleTrigger,
        'preconditions': preconditions.map((k, v) => MapEntry(k.toString(), v)),
        'consequences': consequences.map((k, v) => MapEntry(k.toString(), v)),
        'selfRemove': selfRemove,
        'priority': priority,
        if (areaIds.isNotEmpty) 'areaIds': areaIds,
        if (topic != null) 'topic': topic,
        'isEnding': isEnding,
        if (groupId != null) 'groupId': groupId,
      };

  factory Dialogue.fromJson(Map<String, dynamic> j) {
    // Migrate legacy single areaId field
    List<int> areaIds = [];
    if (j['areaIds'] != null) {
      areaIds = (j['areaIds'] as List).cast<int>();
    } else if (j['areaId'] != null) {
      areaIds = [j['areaId'] as int];
    }
    return Dialogue(
      id: j['id'] as int,
      name: j['name'] as String,
      characterIds: (j['characterIds'] as List).cast<int>(),
      parentNode:
          DialogueNode.fromJson(j['parentNode'] as Map<String, dynamic>),
      singleTrigger: j['singleTrigger'] as bool,
      preconditions: (j['preconditions'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as bool)),
      consequences: (j['consequences'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(int.parse(k), v as bool)),
      selfRemove: j['selfRemove'] as bool? ?? false,
      priority: j['priority'] as int? ?? 0,
      areaIds: areaIds,
      topic: j['topic'] as String?,
      isEnding: j['isEnding'] as bool? ?? false,
      groupId: j['groupId'] as int?,
    );
  }
}
