import 'package:intl/intl.dart';

import 'area.dart';
import 'character.dart';
import 'connection.dart';
import 'dialogue.dart';
import 'dialogue_group.dart';
import 'event.dart';
import 'state_flag.dart';

/// A save file holds the full world definition plus runtime progress.
/// There is no separate "world" model — every save is self-contained.
class SaveData {
  const SaveData({
    required this.saveName,
    required this.timestamp,
    required this.startingAreaId,
    required this.areas,
    required this.connections,
    required this.characters,
    required this.gamestates,
    required this.dialogues,
    required this.events,
    required this.groups,
    required this.elapsedMinutes,
    required this.minutesSincePopulate,
    required this.log,
    required this.gameFlags,
    required this.characterPositions,
  });

  final String saveName;
  final DateTime timestamp;

  // World definition
  final int startingAreaId;
  final Map<int, Area> areas;
  final Map<int, Connection> connections;
  final Map<int, Character> characters;
  final Map<int, StateFlag> gamestates;
  final Map<int, Dialogue> dialogues;
  final Map<int, Event> events;
  final Map<int, DialogueGroup> groups;

  // Runtime progress (player position is not stored — it resets to
  // startingAreaId every time the editor loads / play is pressed).
  final int elapsedMinutes;
  final int minutesSincePopulate;
  final List<String> log;
  final Map<int, bool> gameFlags; // StateFlag id → value
  final Map<int, int> characterPositions; // Character id → Area id

  String get displayName => saveName;
  String get displayTime =>
      DateFormat('dd/MM/yyyy HH:mm').format(timestamp);

  Map<String, dynamic> toJson() => {
    'saveName': saveName,
    'timestamp': timestamp.toIso8601String(),
    'startingAreaId': startingAreaId,
    'areas': {for (final e in areas.entries) e.key.toString(): e.value.toJson()},
    'connections': {for (final e in connections.entries) e.key.toString(): e.value.toJson()},
    'characters': {for (final e in characters.entries) e.key.toString(): e.value.toJson()},
    'gamestates': {for (final e in gamestates.entries) e.key.toString(): e.value.toJson()},
    'dialogues': {for (final e in dialogues.entries) e.key.toString(): e.value.toJson()},
    'events': {for (final e in events.entries) e.key.toString(): e.value.toJson()},
    'groups': {for (final e in groups.entries) e.key.toString(): e.value.toJson()},
    'elapsedMinutes': elapsedMinutes,
    'minutesSincePopulate': minutesSincePopulate,
    'log': log,
    'gameFlags': {for (var e in gameFlags.entries) e.key.toString(): e.value},
    'characterPositions': {for (var e in characterPositions.entries) e.key.toString(): e.value},
  };

  factory SaveData.fromJson(Map<String, dynamic> json) => SaveData(
    saveName: json['saveName'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    startingAreaId: json['startingAreaId'] as int,
    areas: (json['areas'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), Area.fromJson(v as Map<String, dynamic>))),
    connections: (json['connections'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), Connection.fromJson(v as Map<String, dynamic>))),
    characters: (json['characters'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), Character.fromJson(v as Map<String, dynamic>))),
    gamestates: (json['gamestates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), StateFlag.fromJson(v as Map<String, dynamic>))),
    dialogues: (json['dialogues'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), Dialogue.fromJson(v as Map<String, dynamic>))),
    events: (json['events'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), Event.fromJson(v as Map<String, dynamic>))),
    groups: (json['groups'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), DialogueGroup.fromJson(v as Map<String, dynamic>))),
    elapsedMinutes: json['elapsedMinutes'] as int,
    minutesSincePopulate: json['minutesSincePopulate'] as int,
    log: List<String>.from(json['log'] as List<dynamic>),
    gameFlags: Map<int, bool>.from(
      (json['gameFlags'] as Map<dynamic, dynamic>).map(
        (k, v) => MapEntry(int.parse(k.toString()), v as bool),
      ),
    ),
    characterPositions: Map<int, int>.from(
      (json['characterPositions'] as Map<dynamic, dynamic>).map(
        (k, v) => MapEntry(int.parse(k.toString()), v as int),
      ),
    ),
  );
}
