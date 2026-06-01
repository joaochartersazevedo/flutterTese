enum EventType {
  enableArea,
  disableArea,
  toggleArea,
  enableConnection,
  disableConnection,
  toggleConnection,
  activateGameState,
  deactivateGameState,
  toggleGameState,
  forceDialogue,
  removeDialogue,
  forceEvent,
  removeEvent,
}

class Event {
  const Event({
    required this.id,
    required this.name,
    required this.type,
    required this.targetId,
    required this.singleTrigger,
    required this.preconditions,
    required this.consequences,
  });

  final int id;
  final String name;
  final EventType type;
  final int targetId;
  final bool singleTrigger;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'targetId': targetId,
        'singleTrigger': singleTrigger,
        'preconditions': preconditions.map((k, v) => MapEntry(k.toString(), v)),
        'consequences': consequences.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as int,
        name: j['name'] as String,
        type: EventType.values.firstWhere((e) => e.name == j['type']),
        targetId: j['targetId'] as int,
        singleTrigger: j['singleTrigger'] as bool,
        preconditions: (j['preconditions'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(int.parse(k), v as bool)) ??
            {},
        consequences: (j['consequences'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(int.parse(k), v as bool)) ??
            {},
      );
}
