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
}
