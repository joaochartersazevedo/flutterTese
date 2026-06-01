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

  Map<String, dynamic> toJson() => {
        'startingAreaId': startingAreaId,
        'areas': {for (final e in areas.entries) e.key.toString(): e.value.toJson()},
        'connections': {for (final e in connections.entries) e.key.toString(): e.value.toJson()},
        'characters': {for (final e in characters.entries) e.key.toString(): e.value.toJson()},
        'gamestates': {for (final e in gamestates.entries) e.key.toString(): e.value.toJson()},
        'dialogues': {for (final e in dialogues.entries) e.key.toString(): e.value.toJson()},
        'events': {for (final e in events.entries) e.key.toString(): e.value.toJson()},
        'groups': {for (final e in groups.entries) e.key.toString(): e.value.toJson()},
      };

  factory WorldBlueprint.fromJson(Map<String, dynamic> j) => WorldBlueprint(
        startingAreaId: j['startingAreaId'] as int,
        areas: (j['areas'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(int.parse(k), Area.fromJson(v as Map<String, dynamic>))),
        connections: (j['connections'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(int.parse(k), Connection.fromJson(v as Map<String, dynamic>))),
        characters: (j['characters'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(int.parse(k), Character.fromJson(v as Map<String, dynamic>))),
        gamestates: (j['gamestates'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(int.parse(k), StateFlag.fromJson(v as Map<String, dynamic>))),
        dialogues: (j['dialogues'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(int.parse(k), Dialogue.fromJson(v as Map<String, dynamic>))),
        events: (j['events'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(int.parse(k), Event.fromJson(v as Map<String, dynamic>))),
        groups: (j['groups'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(int.parse(k), DialogueGroup.fromJson(v as Map<String, dynamic>))),
      );
}
