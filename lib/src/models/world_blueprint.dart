import 'area.dart';
import 'character.dart';
import 'connection.dart';
import 'dialogue.dart';
import 'dialogue_group.dart';
import 'event.dart';
import 'state_flag.dart';

class WorldBlueprint {
  const WorldBlueprint({
    required this.startingAreaId,
    required this.areas,
    required this.connections,
    required this.characters,
    required this.gamestates,
    required this.dialogues,
    required this.events,
    required this.groups,
  });

  final int startingAreaId;
  final Map<int, Area> areas;
  final Map<int, Connection> connections;
  final Map<int, Character> characters;
  final Map<int, StateFlag> gamestates;
  final Map<int, Dialogue> dialogues;
  final Map<int, Event> events;
  final Map<int, DialogueGroup> groups;
}
