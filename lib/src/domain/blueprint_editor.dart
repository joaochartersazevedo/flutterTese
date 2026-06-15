import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/area.dart';
import '../models/character.dart';
import '../models/connection.dart';
import '../models/dialogue.dart';
import '../models/dialogue_group.dart';
import '../models/event.dart';
import '../models/save_data.dart';
import '../models/state_flag.dart';

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
  final Map<int, Event> events = {};
  final Map<int, DialogueGroup> groups = {};

  int _nextAreaId = 1;
  int _nextConnectionId = 1;
  int _nextCharId = 1;
  int _nextStateId = 1;
  int _nextDialogueId = 1;
  int _nextEventId = 1;
  int _nextGroupId = 1;

  int startingAreaId = 1;

  int nextAreaId() => _nextAreaId++;
  int nextConnectionId() => _nextConnectionId++;
  int nextCharId() => _nextCharId++;
  int nextStateId() => _nextStateId++;
  int nextDialogueId() => _nextDialogueId++;
  int nextEventId() => _nextEventId++;
  int nextGroupId() => _nextGroupId++;

  void setStartingArea(int id) {
    if (areas.containsKey(id)) {
      startingAreaId = id;
      notifyListeners();
    }
  }

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
    _removeAreaInternal(id);
    notifyListeners();
  }

  void _removeAreaInternal(int id) {
    areas.remove(id);
    if (startingAreaId == id) {
      startingAreaId = areas.keys.firstOrNull ?? 1;
    }
    for (final conn in connections.values.toList()) {
      if (conn.areaA == id || conn.areaB == id) {
        _removeConnectionInternal(conn.id);
      }
    }
    // Reassign characters whose home area was deleted to area 0
    for (final entry in characters.entries) {
      if (entry.value.areaId == id && entry.key != playerId) {
        characters[entry.key] = entry.value.copyWith(areaId: 0);
      }
    }
    _removeEventsTargeting(id);
  }

  /// Removes all events whose targetId matches [id].
  void _removeEventsTargeting(int id) {
    events.removeWhere((_, e) => e.targetId == id);
  }

  /// Removes [areaId] from areaIds of all dialogues that reference it.
  void removeAreaFromDialogues(int areaId) {
    for (final entry in dialogues.entries) {
      if (entry.value.areaIds.contains(areaId)) {
        dialogues[entry.key] = Dialogue(
          id: entry.value.id,
          name: entry.value.name,
          characterIds: entry.value.characterIds,
          parentNode: entry.value.parentNode,
          singleTrigger: entry.value.singleTrigger,
          preconditions: entry.value.preconditions,
          consequences: entry.value.consequences,
          selfRemove: entry.value.selfRemove,
          priority: entry.value.priority,
          areaIds: entry.value.areaIds.where((a) => a != areaId).toList(),
          topic: entry.value.topic,
          isEnding: entry.value.isEnding,
          groupId: entry.value.groupId,
        );
      }
    }
  }

  /// Brute-force: deletes area + connections + all dialogues referencing the area.
  void removeAreaBrute(int id) {
    final affectedDialogueIds = dialoguesForArea(id).map((d) => d.id).toList();
    for (final dId in affectedDialogueIds) {
      _removeDialogueInternal(dId);
    }
    _removeAreaInternal(id);
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
    _removeConnectionInternal(id);
    notifyListeners();
  }

  void _removeConnectionInternal(int id) {
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
      _removeEventsTargeting(id);
    }
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
    for (final entry in characters.entries) {
      if (entry.value.relationships.containsKey(id)) {
        final newRels = Map<int, String>.from(entry.value.relationships)..remove(id);
        characters[entry.key] = entry.value.copyWith(relationships: newRels);
      }
    }
    _removeEventsTargeting(id);
    notifyListeners();
  }

  /// Removes character from all dialogue characterIds without deleting dialogues.
  void removeCharacterFromDialogues(int charId) {
    for (final entry in dialogues.entries) {
      if (entry.value.characterIds.contains(charId)) {
        dialogues[entry.key] = Dialogue(
          id: entry.value.id,
          name: entry.value.name,
          characterIds: entry.value.characterIds.where((c) => c != charId).toList(),
          parentNode: entry.value.parentNode,
          singleTrigger: entry.value.singleTrigger,
          preconditions: entry.value.preconditions,
          consequences: entry.value.consequences,
          selfRemove: entry.value.selfRemove,
          priority: entry.value.priority,
          areaIds: entry.value.areaIds,
          topic: entry.value.topic,
          isEnding: entry.value.isEnding,
          groupId: entry.value.groupId,
        );
      }
    }
  }

  /// Brute-force: deletes character + all dialogues that reference them.
  void removeCharacterBrute(int id) {
    if (id == playerId) return;
    final affectedIds = dialoguesForCharacter(id).map((d) => d.id).toList();
    for (final dId in affectedIds) {
      _removeDialogueInternal(dId);
    }
    characters.remove(id);
    for (final entry in characters.entries) {
      if (entry.value.relationships.containsKey(id)) {
        final newRels = Map<int, String>.from(entry.value.relationships)..remove(id);
        characters[entry.key] = entry.value.copyWith(relationships: newRels);
      }
    }
    notifyListeners();
  }

  /// Returns all dialogues that reference [charId].
  List<Dialogue> dialoguesForCharacter(int charId) =>
      dialogues.values.where((d) => d.characterIds.contains(charId)).toList();

  /// Returns all dialogues that reference [areaId].
  List<Dialogue> dialoguesForArea(int areaId) =>
      dialogues.values.where((d) => d.areaIds.contains(areaId)).toList();

  /// Returns all characters assigned to [areaId].
  List<Character> charactersInArea(int areaId) =>
      characters.values.where((c) => c.areaId == areaId && c.id != playerId).toList();

  /// Returns all dialogues that reference [stateFlagId] in preconditions or consequences.
  List<Dialogue> dialoguesForStateFlag(int flagId) =>
      dialogues.values
          .where((d) => d.preconditions.containsKey(flagId) || d.consequences.containsKey(flagId))
          .toList();

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

  /// Removes state flag references from all dialogue preconditions/consequences, then deletes the flag.
  void removeStateFlagClean(int id) {
    for (final entry in dialogues.entries) {
      final d = entry.value;
      if (d.preconditions.containsKey(id) || d.consequences.containsKey(id)) {
        final newPre = Map<int, bool>.from(d.preconditions)..remove(id);
        final newCons = Map<int, bool>.from(d.consequences)..remove(id);
        dialogues[entry.key] = Dialogue(
          id: d.id,
          name: d.name,
          characterIds: d.characterIds,
          parentNode: d.parentNode,
          singleTrigger: d.singleTrigger,
          preconditions: newPre,
          consequences: newCons,
          selfRemove: d.selfRemove,
          priority: d.priority,
          areaIds: d.areaIds,
          topic: d.topic,
          isEnding: d.isEnding,
          groupId: d.groupId,
        );
      }
    }
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
    _removeDialogueInternal(id);
    notifyListeners();
  }

  void _removeDialogueInternal(int id) {
    final d = dialogues.remove(id);
    if (d?.groupId != null) {
      final g = groups[d!.groupId!];
      if (g != null) {
        groups[d.groupId!] = g.withOrder(g.orderedDialogueIds.where((i) => i != id).toList());
      }
    }
    _removeEventsTargeting(id);
  }

  // ------ Groups ------

  void addGroup(DialogueGroup g) {
    groups[g.id] = g;
    notifyListeners();
  }

  void updateGroup(DialogueGroup g) {
    groups[g.id] = g;
    notifyListeners();
  }

  void removeGroup(int id) {
    groups.remove(id);
    // Clear groupId on dialogues that referenced this group
    for (final entry in dialogues.entries) {
      if (entry.value.groupId == id) {
        dialogues[entry.key] = Dialogue(
          id: entry.value.id,
          name: entry.value.name,
          characterIds: entry.value.characterIds,
          parentNode: entry.value.parentNode,
          singleTrigger: entry.value.singleTrigger,
          preconditions: entry.value.preconditions,
          consequences: entry.value.consequences,
          selfRemove: entry.value.selfRemove,
          priority: entry.value.priority,
          areaIds: entry.value.areaIds,
          topic: entry.value.topic,
          isEnding: entry.value.isEnding,
        );
      }
    }
    notifyListeners();
  }

  /// Returns an error string if [dialogueId] can't join [groupId], null if ok.
  String? groupJoinError(int dialogueId, int groupId) {
    final d = dialogues[dialogueId];
    final g = groups[groupId];
    if (d == null || g == null) return null;
    if (g.orderedDialogueIds.isEmpty) return null;
    final firstId = g.orderedDialogueIds.first;
    final first = dialogues[firstId];
    if (first == null) return null;
    // Warn if both have explicit areas and they don't overlap
    if (d.areaIds.isNotEmpty && first.areaIds.isNotEmpty) {
      final overlap = d.areaIds.any((a) => first.areaIds.contains(a));
      if (!overlap) {
        return 'Diálogos têm áreas incompatíveis: ${d.areaIds} vs ${first.areaIds}.';
      }
    }
    return null;
  }

  void setDialogueGroup(int dialogueId, int? groupId) {
    final d = dialogues[dialogueId];
    if (d == null) return;
    final oldGroupId = d.groupId;

    dialogues[dialogueId] = Dialogue(
      id: d.id,
      name: d.name,
      characterIds: d.characterIds,
      parentNode: d.parentNode,
      singleTrigger: d.singleTrigger,
      preconditions: d.preconditions,
      consequences: d.consequences,
      selfRemove: d.selfRemove,
      priority: d.priority,
      areaIds: d.areaIds,
      topic: d.topic,
      isEnding: d.isEnding,
      groupId: groupId,
    );

    // Remove from old group order
    if (oldGroupId != null && groups.containsKey(oldGroupId)) {
      final g = groups[oldGroupId]!;
      final newOrder = [...g.orderedDialogueIds]..remove(dialogueId);
      groups[oldGroupId] = g.withOrder(newOrder);
    }
    // Add to new group order
    if (groupId != null && groups.containsKey(groupId)) {
      final g = groups[groupId]!;
      if (!g.orderedDialogueIds.contains(dialogueId)) {
        groups[groupId] = g.withOrder([...g.orderedDialogueIds, dialogueId]);
      }
    }

    notifyListeners();
  }

  void reorderGroupDialogues(int groupId, List<int> orderedIds) {
    final g = groups[groupId];
    if (g == null) return;
    groups[groupId] = g.withOrder(orderedIds);
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

  /// Builds a full save from the current world definition. [saveName] and
  /// the progress fields default to a fresh game; pass the previous save's
  /// progress fields to keep them when re-saving an existing save.
  SaveData build({
    required String saveName,
    DateTime? timestamp,
    int elapsedMinutes = 0,
    int minutesSincePopulate = 0,
    List<String> log = const [],
    Map<int, bool>? gameFlags,
    Map<int, int>? characterPositions,
  }) =>
      SaveData(
        saveName: saveName,
        timestamp: timestamp ?? DateTime.now(),
        startingAreaId:
            areas.containsKey(startingAreaId) ? startingAreaId : (areas.keys.firstOrNull ?? 1),
        areas: Map.from(areas),
        connections: Map.from(connections),
        characters: Map.from(characters),
        gamestates: Map.from(gamestates),
        dialogues: Map.from(dialogues),
        events: Map.from(events),
        groups: Map.from(groups),
        elapsedMinutes: elapsedMinutes,
        minutesSincePopulate: minutesSincePopulate,
        log: log,
        gameFlags: gameFlags ?? {for (final g in gamestates.values) g.id: g.value},
        characterPositions:
            characterPositions ?? {for (final c in characters.values) c.id: c.areaId},
      );

  /// Loads the world definition from [save] for editing. Progress fields
  /// (gameFlags, characterPositions, log, ...) are not loaded into the
  /// editor — they live only in the save file / game engine.
  void loadSave(SaveData save) {
    areas
      ..clear()
      ..addAll(save.areas);
    connections
      ..clear()
      ..addAll(save.connections);
    characters
      ..clear()
      ..addAll(save.characters);
    gamestates
      ..clear()
      ..addAll(save.gamestates);
    dialogues
      ..clear()
      ..addAll(save.dialogues);
    events
      ..clear()
      ..addAll(save.events);
    groups
      ..clear()
      ..addAll(save.groups);
    startingAreaId = save.startingAreaId;

    int maxId(Iterable<int> keys) =>
        keys.isEmpty ? 0 : keys.reduce(math.max);

    _nextAreaId = maxId(areas.keys) + 1;
    _nextConnectionId = maxId(connections.keys) + 1;
    _nextCharId = maxId(characters.keys) + 1;
    _nextStateId = maxId(gamestates.keys) + 1;
    _nextDialogueId = maxId(dialogues.keys) + 1;
    _nextEventId = maxId(events.keys) + 1;
    _nextGroupId = maxId(groups.keys) + 1;

    _ensurePlayer();

    notifyListeners();
  }

  void _ensurePlayer() {
    characters.putIfAbsent(playerId, () => defaultPlayer);
  }
}
