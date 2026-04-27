class WorldBlueprint {
  const WorldBlueprint({
    required this.id,
    required this.name,
    required this.areas,
    required this.characters,
    required this.stateFlags,
    required this.connections,
    required this.events,
    required this.dialogues,
  });
  final String id;
  final String name;
  final List<String> areas;
  final List<String> characters;
  final List<String> stateFlags;
  final List<String> connections;
  final List<String> events;
  final List<String> dialogues;
}
