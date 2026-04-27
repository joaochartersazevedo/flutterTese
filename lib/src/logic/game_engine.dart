import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/renpy_asset_resolver.dart';
import '../domain/models.dart';

class GameEngine extends ChangeNotifier {
  GameEngine(
    this.blueprint, {
    RenpyAssetResolver? assetResolver,
  }) : _assetResolver = assetResolver ?? RenpyAssetResolver.auto() {
    _resetRuntime();
  }

  final GameWorldBlueprint blueprint;
  final RenpyAssetResolver _assetResolver;

  late Map<int, GameArea> _areas;
  late Map<int, GameConnection> _connections;
  late Map<int, GameCharacter> _characters;
  late Map<int, GameStateFlag> _gamestates;
  late Map<int, GameDialogue> _dialoguesPool;
  late Map<int, GameDialogue> _activeDialogues;
  late Map<int, GameTask> _tasks;
  late Map<int, GameEvent> _events;

  int _currentAreaId = 1;
  int _elapsedMinutes = 0;
  int _minutesSincePopulate = 0;
  final List<String> _log = <String>[];

  RenpyAssetResolver get assetResolver => _assetResolver;

  int get elapsedMinutes => _elapsedMinutes;

  String get formattedTime {
    final hours = (_elapsedMinutes ~/ 60) % 24;
    final minutes = _elapsedMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  List<String> get log => List.unmodifiable(_log.reversed);

  List<GameArea> get allAreas =>
      _areas.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  List<GameStateFlag> get gameStates =>
      _gamestates.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  List<GameTask> get tasks =>
      _tasks.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  List<GameDialogue> get activeDialogues =>
      _activeDialogues.values.toList()..sort((a, b) => b.priority.compareTo(a.priority));

  GameArea get currentArea => _areas[_currentAreaId]!;

  List<GameConnection> get currentConnections {
    final ids = currentArea.connectionIds;
    return ids
        .where((id) => _connections.containsKey(id))
        .map((id) => _connections[id]!)
        .toList();
  }

  String speakerName(int speakerId) {
    if (speakerId == 0) {
      return 'Jogador';
    }
    return _characters[speakerId]?.name ?? 'NPC $speakerId';
  }

  String areaBackgroundAbsolutePath(GameArea area) {
    return _assetResolver.resolve(area.backgroundPath);
  }

  bool isAreaSelected(GameArea area) => area.id == _currentAreaId;

  void selectArea(int areaId) {
    if (!_areas.containsKey(areaId)) {
      return;
    }
    _currentAreaId = areaId;
    _logLine('Teleporte para ${_areas[areaId]!.name}.');
    notifyListeners();
  }

  void restart() {
    _resetRuntime();
    notifyListeners();
  }

  void travelThrough(int connectionId) {
    final connection = _connections[connectionId];
    if (connection == null) {
      return;
    }

    if (!currentArea.connectionIds.contains(connectionId)) {
      _logLine('Conexao indisponivel neste local.');
      notifyListeners();
      return;
    }

    if (connection.locked) {
      _logLine('Ligacao bloqueada.');
      notifyListeners();
      return;
    }

    final destinationId = connection.destinationFor(_currentAreaId);
    final destination = _areas[destinationId];
    if (destination == null || destination.locked) {
      _logLine('Destino bloqueado.');
      notifyListeners();
      return;
    }

    _currentAreaId = destinationId;
    _elapsedMinutes += connection.travelMinutes;
    _minutesSincePopulate += connection.travelMinutes;

    _logLine('Movimento: ${currentArea.name} (+${connection.travelMinutes} min).');
    _tick();
  }

  void startDialogue(int dialogueId) {
    final dialogue = _activeDialogues[dialogueId];
    if (dialogue == null) {
      return;
    }

    _logLine('Dialogo: ${dialogue.name}');
    for (final line in dialogue.lines.take(6)) {
      _logLine('${speakerName(line.speakerId)}: ${line.text}');
    }

    _applyConsequences(dialogue.consequences);

    if (dialogue.singleTrigger || dialogue.selfRemove) {
      _activeDialogues.remove(dialogue.id);
      _dialoguesPool.remove(dialogue.id);
    }

    if (currentArea.dialogueId == dialogueId) {
      _areas[_currentAreaId] = currentArea.copyWith(dialogueId: null);
    }

    _tick();
  }

  void completeTask(int taskId) {
    final task = _tasks[taskId];
    if (task == null || !task.active || task.completed) {
      return;
    }

    _tasks[taskId] = task.copyWith(active: false, completed: true);
    _applyConsequences(task.consequences);
    _logLine('Tarefa concluida: ${task.name}');
    _tick();
  }

  String connectionLabel(GameConnection connection) {
    final destinationId = connection.destinationFor(_currentAreaId);
    final destinationName = _areas[destinationId]?.name ?? 'Area $destinationId';
    return '$destinationName (${connection.travelMinutes}m)';
  }

  void _resetRuntime() {
    _areas = {
      for (final entry in blueprint.areas.entries)
        entry.key: entry.value.copyWith(
          connectionIds: List<int>.from(entry.value.connectionIds),
          dialogueId: null,
        ),
    };
    _connections = {
      for (final entry in blueprint.connections.entries) entry.key: entry.value.copyWith(),
    };
    _characters = Map<int, GameCharacter>.from(blueprint.characters);
    _gamestates = {
      for (final entry in blueprint.gamestates.entries) entry.key: entry.value.copyWith(),
    };
    _dialoguesPool = Map<int, GameDialogue>.from(blueprint.dialogues);
    _activeDialogues = <int, GameDialogue>{};
    _tasks = {
      for (final entry in blueprint.tasks.entries)
        entry.key: entry.value.copyWith(active: false, completed: false),
    };
    _events = Map<int, GameEvent>.from(blueprint.events);
    _currentAreaId = blueprint.startingAreaId;
    _elapsedMinutes = 0;
    _minutesSincePopulate = 0;
    _log
      ..clear()
      ..add('Runtime iniciado em ${currentArea.name}.');

    _evaluateTriggers();
    _populateDialoguesInAreas();
  }

  void _tick() {
    _evaluateTriggers();

    if (_minutesSincePopulate >= 60) {
      _minutesSincePopulate = 0;
      _logLine('Repopulacao de dialogos.');
    }

    _populateDialoguesInAreas();
    notifyListeners();
  }

  void _evaluateTriggers() {
    var safety = 0;
    var changed = true;

    while (changed && safety < 20) {
      safety += 1;
      changed = false;

      for (final event in _events.values.toList()) {
        if (!_conditionsMet(event.preconditions)) {
          continue;
        }

        final eventChanged = _applyEvent(event);
        if (event.singleTrigger) {
          _events.remove(event.id);
        }
        changed = changed || eventChanged;
      }

      for (final dialogue in _dialoguesPool.values.toList()) {
        if (_activeDialogues.containsKey(dialogue.id)) {
          continue;
        }

        if (_conditionsMet(dialogue.preconditions)) {
          _activeDialogues[dialogue.id] = dialogue;
          _logLine('Dialogo ativado: ${dialogue.name}.');
          changed = true;
        }
      }

      for (final taskEntry in _tasks.entries.toList()) {
        final task = taskEntry.value;
        if (task.completed) {
          continue;
        }

        final shouldBeActive = _conditionsMet(task.preconditions);
        if (task.active != shouldBeActive) {
          _tasks[taskEntry.key] = task.copyWith(active: shouldBeActive);
          if (shouldBeActive) {
            _logLine('Nova tarefa ativa: ${task.name}.');
          }
          changed = true;
        }
      }
    }
  }

  void _populateDialoguesInAreas() {
    for (final entry in _areas.entries.toList()) {
      _areas[entry.key] = entry.value.copyWith(dialogueId: null);
    }

    final active = activeDialogues;
    final localized = active
        .where((d) => d.type == DialogueType.localized || d.areaId != null)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final freeAreas = _areas.values
        .where((area) => !area.locked)
        .map((area) => area.id)
        .toList();

    final random = Random(_elapsedMinutes + _currentAreaId + active.length);
    freeAreas.shuffle(random);

    for (final dialogue in localized) {
      final areaId = dialogue.areaId;
      if (areaId == null || !_areas.containsKey(areaId)) {
        continue;
      }
      if (_areas[areaId]!.dialogueId != null || _areas[areaId]!.locked) {
        continue;
      }
      _areas[areaId] = _areas[areaId]!.copyWith(dialogueId: dialogue.id);
      freeAreas.remove(areaId);
    }

    final dynamicDialogues = active
        .where((d) => d.areaId == null && d.type != DialogueType.localized)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final dialogue in dynamicDialogues) {
      if (freeAreas.isEmpty) {
        break;
      }
      final areaId = freeAreas.removeAt(0);
      _areas[areaId] = _areas[areaId]!.copyWith(dialogueId: dialogue.id);
    }
  }

  bool _conditionsMet(Map<int, bool> conditions) {
    for (final entry in conditions.entries) {
      final state = _gamestates[entry.key];
      if (state == null || state.value != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _applyEvent(GameEvent event) {
    var changed = false;

    switch (event.type) {
      case EventType.enableArea:
        final area = _areas[event.targetId];
        if (area != null && area.locked) {
          _areas[event.targetId] = area.copyWith(locked: false);
          _logLine('Evento: area ${area.name} desbloqueada.');
          changed = true;
        }
      case EventType.disableArea:
        final area = _areas[event.targetId];
        if (area != null && !area.locked) {
          _areas[event.targetId] = area.copyWith(locked: true);
          _logLine('Evento: area ${area.name} bloqueada.');
          changed = true;
        }
      case EventType.toggleArea:
        final area = _areas[event.targetId];
        if (area != null) {
          _areas[event.targetId] = area.copyWith(locked: !area.locked);
          _logLine('Evento: area ${area.name} alternada.');
          changed = true;
        }
      case EventType.enableConnection:
        final connection = _connections[event.targetId];
        if (connection != null && connection.locked) {
          _connections[event.targetId] = connection.copyWith(locked: false);
          changed = true;
        }
      case EventType.disableConnection:
        final connection = _connections[event.targetId];
        if (connection != null && !connection.locked) {
          _connections[event.targetId] = connection.copyWith(locked: true);
          changed = true;
        }
      case EventType.toggleConnection:
        final connection = _connections[event.targetId];
        if (connection != null) {
          _connections[event.targetId] = connection.copyWith(locked: !connection.locked);
          changed = true;
        }
      case EventType.activateGameState:
        changed = _setGameState(event.targetId, true) || changed;
      case EventType.deactivateGameState:
        changed = _setGameState(event.targetId, false) || changed;
      case EventType.toggleGameState:
        final current = _gamestates[event.targetId];
        if (current != null) {
          changed = _setGameState(event.targetId, !current.value) || changed;
        }
      case EventType.forceDialogue:
        final dialogue = _dialoguesPool[event.targetId];
        if (dialogue != null) {
          _activeDialogues[dialogue.id] = dialogue;
          changed = true;
        }
      case EventType.removeDialogue:
        final removedFromActive = _activeDialogues.remove(event.targetId) != null;
        final removedFromPool = _dialoguesPool.remove(event.targetId) != null;
        changed = removedFromActive || removedFromPool || changed;
      case EventType.forceEvent:
        final targetEvent = _events[event.targetId];
        if (targetEvent != null && targetEvent.id != event.id) {
          changed = _applyEvent(targetEvent) || changed;
        }
      case EventType.removeEvent:
        changed = (_events.remove(event.targetId) != null) || changed;
    }

    _applyConsequences(event.consequences);
    return changed;
  }

  bool _setGameState(int id, bool value) {
    final state = _gamestates[id];
    if (state == null || state.value == value) {
      return false;
    }

    _gamestates[id] = state.copyWith(value: value);
    _logLine('Estado atualizado: ${state.name} = $value');
    return true;
  }

  void _applyConsequences(Map<int, bool> consequences) {
    for (final entry in consequences.entries) {
      _setGameState(entry.key, entry.value);
    }
  }

  void _logLine(String message) {
    _log.add(message);
    if (_log.length > 200) {
      _log.removeRange(0, _log.length - 200);
    }
  }
}
