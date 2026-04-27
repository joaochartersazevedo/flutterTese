import 'package:flutter/foundation.dart';

import '../data/renpy_asset_resolver.dart';
import '../models/area.dart';
import '../models/character.dart';
import '../models/connection.dart';
import '../models/dialogue.dart';
import '../models/event.dart';
import '../models/state_flag.dart';
import '../models/task.dart';
import '../models/world_blueprint.dart';

class GameEngine extends ChangeNotifier {
  GameEngine(this.blueprint, {RenpyAssetResolver? assetResolver})
      : _assetResolver = assetResolver ?? RenpyAssetResolver.auto() {
    _resetRuntime();
  }

  final WorldBlueprint blueprint;
  final RenpyAssetResolver _assetResolver;

  late List<Area> _areas;
  late List<Connection> _connections;
  late List<Character> _characters;
  late List<StateFlag> _gamestates;
  late List<Dialogue> _dialoguesPool;
  late List<Dialogue> _activeDialogues;
  late List<Task> _tasks;
  late List<Event> _events;

  int _currentAreaId = 1;
  int _elapsedMinutes = 0;
  int _minutesSincePopulate = 0;
  final List<String> _log = <String>[];

  // ---------- SAFE HELPERS ----------

  T? _firstWhereOrNull<T>(
    List<T> list,
    bool Function(T) test,
  ) {
    for (final e in list) {
      if (test(e)) return e;
    }
    return null;
  }

  int _indexWhere<T>(
    List<T> list,
    bool Function(T) test,
  ) {
    for (var i = 0; i < list.length; i++) {
      if (test(list[i])) return i;
    }
    return -1;
  }

  void _replaceWhere<T>(
    List<T> list,
    bool Function(T) test,
    T updated,
  ) {
    final index = _indexWhere(list, test);
    if (index != -1) {
      list[index] = updated;
    }
  }

  // ---------- LOOKUPS ----------

  Area? _area(int id) => _firstWhereOrNull(_areas, (a) => a.id == id);
  Connection? _connection(int id) =>
      _firstWhereOrNull(_connections, (c) => c.id == id);
  Character? _character(int id) =>
      _firstWhereOrNull(_characters, (c) => c.id == id);
  StateFlag? _state(int id) =>
      _firstWhereOrNull(_gamestates, (s) => s.id == id);
  Task? _task(int id) => _firstWhereOrNull(_tasks, (t) => t.id == id);

  // ---------- GETTERS ----------

  RenpyAssetResolver get assetResolver => _assetResolver;

  int get elapsedMinutes => _elapsedMinutes;

  String get formattedTime {
    final hours = (_elapsedMinutes ~/ 60) % 24;
    final minutes = _elapsedMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  List<String> get log => List.unmodifiable(_log.reversed);

  List<Area> get allAreas =>
      [..._areas]..sort((a, b) => a.id.compareTo(b.id));

  List<StateFlag> get gameStates =>
      [..._gamestates]..sort((a, b) => a.id.compareTo(b.id));

  List<Task> get tasks =>
      [..._tasks]..sort((a, b) => a.id.compareTo(b.id));

  List<Dialogue> get activeDialogues =>
      [..._activeDialogues]
        ..sort((a, b) => b.priority.compareTo(a.priority));

  Area get currentArea => _area(_currentAreaId)!;

  List<Connection> get currentConnections {
    return currentArea.connectionIds
        .map(_connection)
        .whereType<Connection>()
        .toList();
  }

  String speakerName(int speakerId) {
    if (speakerId == 0) return 'Jogador';
    return _character(speakerId)?.name ?? 'NPC $speakerId';
  }

  String areaBackgroundAbsolutePath(Area area) {
    return _assetResolver.resolve(area.backgroundPath);
  }

  bool isAreaSelected(Area area) => area.id == _currentAreaId;

  // ---------- ACTIONS ----------

  void selectArea(int areaId) {
    final area = _area(areaId);
    if (area == null) return;

    _currentAreaId = areaId;
    _logLine('Teleporte para ${area.name}.');
    notifyListeners();
  }

  void restart() {
    _resetRuntime();
    notifyListeners();
  }

  void travelThrough(int connectionId) {
    final connection = _connection(connectionId);
    if (connection == null) return;

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
    final destination = _area(destinationId);

    if (destination == null || destination.locked) {
      _logLine('Destino bloqueado.');
      notifyListeners();
      return;
    }

    _currentAreaId = destinationId;
    _elapsedMinutes += connection.travelMinutes;
    _minutesSincePopulate += connection.travelMinutes;

    _logLine(
      'Movimento: ${currentArea.name} (+${connection.travelMinutes} min).',
    );

    _tick();
  }

  void startDialogue(int dialogueId) {
    final dialogue =
        _firstWhereOrNull(_activeDialogues, (d) => d.id == dialogueId);
    if (dialogue == null) return;

    _logLine('Dialogo: ${dialogue.name}');
    for (final line in dialogue.lines.take(6)) {
      _logLine('${speakerName(line.speakerId)}: ${line.text}');
    }

    _applyConsequences(dialogue.consequences);

    if (dialogue.singleTrigger || dialogue.selfRemove) {
      _activeDialogues.removeWhere((d) => d.id == dialogue.id);
      _dialoguesPool.removeWhere((d) => d.id == dialogue.id);
    }

    _tick();
  }

  void completeTask(int taskId) {
    final task = _task(taskId);
    if (task == null || !task.active || task.completed) return;

    _replaceWhere(
      _tasks,
      (t) => t.id == taskId,
      task.copyWith(active: false, completed: true),
    );

    _applyConsequences(task.consequences);
    _logLine('Tarefa concluida: ${task.name}');
    _tick();
  }

  String connectionLabel(Connection connection) {
    final destinationId = connection.destinationFor(_currentAreaId);
    final destinationName =
        _area(destinationId)?.name ?? 'Area $destinationId';
    return '$destinationName (${connection.travelMinutes}m)';
  }

  // ---------- RUNTIME ----------

  void _resetRuntime() {
    _areas = blueprint.areas
        .map((a) => a.copyWith(
              connectionIds: List<int>.from(a.connectionIds),
              dialogueId: null,
            ))
        .toList();

    _connections =
        blueprint.connections.values.map((c) => c.copyWith()).toList();

    _characters = blueprint.characters.values.toList();

    _gamestates =
        blueprint.gamestates.values.map((g) => g.copyWith()).toList();

    _dialoguesPool = blueprint.dialogues.values.toList();
    _activeDialogues = [];

    _tasks = blueprint.tasks.values
        .map((t) => t.copyWith(active: false, completed: false))
        .toList();

    _events = blueprint.events.values.toList();

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

  // ---------- LOGIC ----------

  void _evaluateTriggers() {
    var safety = 0;
    var changed = true;

    while (changed && safety < 20) {
      safety++;
      changed = false;

      for (final event in List<Event>.from(_events)) {
        if (!_conditionsMet(event.preconditions)) continue;

        final eventChanged = _applyEvent(event);

        if (event.singleTrigger) {
          _events.removeWhere((e) => e.id == event.id);
        }

        changed = changed || eventChanged;
      }

      for (final dialogue in List<Dialogue>.from(_dialoguesPool)) {
        if (_activeDialogues.any((d) => d.id == dialogue.id)) continue;

        if (_conditionsMet(dialogue.preconditions)) {
          _activeDialogues.add(dialogue);
          _logLine('Dialogo ativado: ${dialogue.name}.');
          changed = true;
        }
      }

      for (final task in List<Task>.from(_tasks)) {
        if (task.completed) continue;

        final shouldBeActive = _conditionsMet(task.preconditions);

        if (task.active != shouldBeActive) {
          _replaceWhere(
            _tasks,
            (t) => t.id == task.id,
            task.copyWith(active: shouldBeActive),
          );

          if (shouldBeActive) {
            _logLine('Nova tarefa ativa: ${task.name}.');
          }

          changed = true;
        }
      }
    }
  }

  bool _conditionsMet(Map<int, bool> conditions) {
    for (final entry in conditions.entries) {
      final state = _state(entry.key);
      if (state == null || state.value != entry.value) return false;
    }
    return true;
  }

  bool _applyEvent(Event event) {
    var changed = false;

    switch (event.type) {
      case EventType.enableArea:
        final area = _area(event.targetId);
        if (area != null && area.locked) {
          _replaceWhere(
              _areas, (a) => a.id == area.id, area.copyWith(locked: false));
          _logLine('Evento: area ${area.name} desbloqueada.');
          changed = true;
        }
        break;

      case EventType.activateGameState:
        changed = _setGameState(event.targetId, true) || changed;
        break;

      default:
        break;
    }

    _applyConsequences(event.consequences);
    return changed;
  }

  bool _setGameState(int id, bool value) {
    final state = _state(id);
    if (state == null || state.value == value) return false;

    _replaceWhere(
      _gamestates,
      (s) => s.id == id,
      state.copyWith(value: value),
    );

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