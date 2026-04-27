import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/area.dart';
import '../models/character.dart';
import '../models/connection.dart';
import '../models/dialogue.dart';
import '../models/event.dart';
import '../models/state_flag.dart';
import '../models/task.dart';
import '../models/world_blueprint.dart';

class BlueprintEditor extends ChangeNotifier {
  BlueprintEditor() {
    _ensurePlayer();
  }

  static const int playerId = 0;
  static const Character defaultPlayer = Character(
    id: playerId,
    name: 'Jogador',
    colorHex: '#009900',
    portraitPath: '',
    areaId: 0,
    bodyPath: '',
  );

  final Map<int, Area> areas = {};
  final Map<int, Connection> connections = {};
  final Map<int, Character> characters = {};
  final Map<int, StateFlag> gamestates = {};
  final Map<int, Dialogue> dialogues = {};
  final Map<int, Task> tasks = {};
  final Map<int, Event> events = {};

  int _nextAreaId = 1;
  int _nextConnectionId = 1;
  int _nextCharId = 1;
  int _nextStateId = 1;
  int _nextDialogueId = 1;
  int _nextTaskId = 1;
  int _nextEventId = 1;

  int startingAreaId = 1;

  int nextAreaId() => _nextAreaId++;
  int nextConnectionId() => _nextConnectionId++;
  int nextCharId() => _nextCharId++;
  int nextStateId() => _nextStateId++;
  int nextDialogueId() => _nextDialogueId++;
  int nextTaskId() => _nextTaskId++;
  int nextEventId() => _nextEventId++;

  // ------ Areas ------

  void addArea(Area area) {
    areas[area.id] = area;
    if (areas.length == 1) startingAreaId = area.id;
    notifyListeners();
  }

  void updateArea(Area area) {
    areas[area.id] = area;
    notifyListeners();
  }

  void removeArea(int id) {
    areas.remove(id);
    for (final conn in connections.values.toList()) {
      if (conn.areaA == id || conn.areaB == id) {
        connections.remove(conn.id);
      }
    }
    notifyListeners();
  }

  // ------ Connections ------

  void addConnection(Connection conn) {
    connections[conn.id] = conn;
    final a = areas[conn.areaA];
    if (a != null && !a.connectionIds.contains(conn.id)) {
      areas[conn.areaA] = a.copyWith(connectionIds: [...a.connectionIds, conn.id]);
    }
    final b = areas[conn.areaB];
    if (b != null && !b.connectionIds.contains(conn.id)) {
      areas[conn.areaB] = b.copyWith(connectionIds: [...b.connectionIds, conn.id]);
    }
    notifyListeners();
  }

  void removeConnection(int id) {
    final conn = connections.remove(id);
    if (conn != null) {
      final a = areas[conn.areaA];
      if (a != null) {
        areas[conn.areaA] =
            a.copyWith(connectionIds: a.connectionIds.where((c) => c != id).toList());
      }
      final b = areas[conn.areaB];
      if (b != null) {
        areas[conn.areaB] =
            b.copyWith(connectionIds: b.connectionIds.where((c) => c != id).toList());
      }
    }
    notifyListeners();
  }

  // ------ Characters ------

  void addCharacter(Character char) {
    characters[char.id] = char;
    notifyListeners();
  }

  void updateCharacter(Character char) {
    characters[char.id] = char;
    notifyListeners();
  }

  void removeCharacter(int id) {
    if (id == playerId) return;
    characters.remove(id);
    notifyListeners();
  }

  // ------ State Flags ------

  void addStateFlag(StateFlag flag) {
    gamestates[flag.id] = flag;
    notifyListeners();
  }

  void updateStateFlag(StateFlag flag) {
    gamestates[flag.id] = flag;
    notifyListeners();
  }

  void removeStateFlag(int id) {
    gamestates.remove(id);
    notifyListeners();
  }

  // ------ Dialogues ------

  void addDialogue(Dialogue d) {
    dialogues[d.id] = d;
    notifyListeners();
  }

  void updateDialogue(Dialogue d) {
    dialogues[d.id] = d;
    notifyListeners();
  }

  void removeDialogue(int id) {
    dialogues.remove(id);
    notifyListeners();
  }

  // ------ Tasks ------

  void addTask(Task t) {
    tasks[t.id] = t;
    notifyListeners();
  }

  void removeTask(int id) {
    tasks.remove(id);
    notifyListeners();
  }

  // ------ Events ------

  void addEvent(Event e) {
    events[e.id] = e;
    notifyListeners();
  }

  void removeEvent(int id) {
    events.remove(id);
    notifyListeners();
  }

  // ------ Build / Load ------

  WorldBlueprint build() => WorldBlueprint(
        startingAreaId:
            areas.containsKey(startingAreaId) ? startingAreaId : (areas.keys.firstOrNull ?? 1),
        areas: Map.from(areas),
        connections: Map.from(connections),
        characters: Map.from(characters),
        gamestates: Map.from(gamestates),
        dialogues: Map.from(dialogues),
        tasks: Map.from(tasks),
        events: Map.from(events),
      );

  void loadBlueprint(WorldBlueprint bp) {
    areas
      ..clear()
      ..addAll(bp.areas);
    connections
      ..clear()
      ..addAll(bp.connections);
    characters
      ..clear()
      ..addAll(bp.characters);
    gamestates
      ..clear()
      ..addAll(bp.gamestates);
    dialogues
      ..clear()
      ..addAll(bp.dialogues);
    tasks
      ..clear()
      ..addAll(bp.tasks);
    events
      ..clear()
      ..addAll(bp.events);
    startingAreaId = bp.startingAreaId;

    int maxId(Iterable<int> keys) =>
        keys.isEmpty ? 0 : keys.reduce(math.max);

    _nextAreaId = maxId(areas.keys) + 1;
    _nextConnectionId = maxId(connections.keys) + 1;
    _nextCharId = maxId(characters.keys) + 1;
    _nextStateId = maxId(gamestates.keys) + 1;
    _nextDialogueId = maxId(dialogues.keys) + 1;
    _nextTaskId = maxId(tasks.keys) + 1;
    _nextEventId = maxId(events.keys) + 1;

    _ensurePlayer();

    notifyListeners();
  }

  void _ensurePlayer() {
    characters.putIfAbsent(playerId, () => defaultPlayer);
  }
}
