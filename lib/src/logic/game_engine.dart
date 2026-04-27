import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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
  final List<String> _log = [];

  Dialogue? _currentDialogue;
  int _currentLineIndex = 0;

  // ---------- HELPERS ----------

  T? _find<T>(List<T> list, bool Function(T) test) {
    for (final e in list) {
      if (test(e)) return e;
    }
    return null;
  }

  void _replace<T>(List<T> list, bool Function(T) test, T updated) {
    for (var i = 0; i < list.length; i++) {
      if (test(list[i])) {
        list[i] = updated;
        return;
      }
    }
  }

  // ---------- LOOKUPS ----------

  Area? _area(int id) => _find(_areas, (a) => a.id == id);
  Connection? _conn(int id) => _find(_connections, (c) => c.id == id);
  Character? _char(int id) => _find(_characters, (c) => c.id == id);
  StateFlag? _state(int id) => _find(_gamestates, (s) => s.id == id);
  Task? _task(int id) => _find(_tasks, (t) => t.id == id);

  // ---------- GETTERS ----------

  RenpyAssetResolver get assetResolver => _assetResolver;

  String get formattedTime {
    final h = (_elapsedMinutes ~/ 60) % 24;
    final m = _elapsedMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  List<String> get log => List.unmodifiable(_log.reversed);
  List<Area> get allAreas => [..._areas]..sort((a, b) => a.id.compareTo(b.id));
  List<StateFlag> get gameStates => [..._gamestates]..sort((a, b) => a.id.compareTo(b.id));
  List<Task> get tasks => [..._tasks]..sort((a, b) => a.id.compareTo(b.id));
  List<Dialogue> get activeDialogues =>
      [..._activeDialogues]..sort((a, b) => b.priority.compareTo(a.priority));

  Area get currentArea => _area(_currentAreaId)!;

  List<Connection> get currentConnections => currentArea.connectionIds
      .map(_conn)
      .whereType<Connection>()
      .toList();

  List<Character> get currentCharacters =>
      _characters.where((c) => c.areaId == _currentAreaId).toList();

  List<Dialogue> get currentAreaDialogues => _activeDialogues
      .where((d) => d.areaId == null || d.areaId == _currentAreaId)
      .toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));

  bool get isInDialogue => _currentDialogue != null;
  Dialogue? get currentDialogue => _currentDialogue;

  DialogueLine? get currentLine {
    final d = _currentDialogue;
    if (d == null || _currentLineIndex >= d.lines.length) return null;
    return d.lines[_currentLineIndex];
  }

  int get currentLineIndex => _currentLineIndex;
  int get totalLines => _currentDialogue?.lines.length ?? 0;

  bool isAreaSelected(Area area) => area.id == _currentAreaId;

  String speakerName(int speakerId) {
    if (speakerId == 0) return 'Jogador';
    return _char(speakerId)?.name ?? 'NPC $speakerId';
  }

  String speakerColor(int speakerId) {
    if (speakerId == 0) return '#009900';
    return _char(speakerId)?.colorHex ?? '#ffffff';
  }

  String resolveAsset(String path) => _assetResolver.resolve(path);
  bool assetExists(String path) => _assetResolver.exists(path);

  /// Returns absolute path to speaker portrait for given emotion.
  /// Falls back to default portrait, then empty string.
  String speakerPortraitPath(int speakerId, int emotionId) {
    final char = speakerId == 0 ? null : _char(speakerId);
    if (char == null || char.portraitPath.isEmpty) return '';

    // Derive emotion path: "editor/portraits/portrait (1).png"
    //   → "editor/portraits/portrait (1)/portrait (emotionId).png"
    final rel = char.portraitPath;
    final dir = p.dirname(rel);
    final stem = p.basenameWithoutExtension(rel);
    final emotionRel = p.join(dir, stem, 'portrait ($emotionId).png');
    if (_assetResolver.exists(emotionRel)) return _assetResolver.resolve(emotionRel);

    // Fall back to default portrait
    if (_assetResolver.exists(rel)) return _assetResolver.resolve(rel);
    return '';
  }

  List<Task> get activeTasks => _tasks.where((t) => t.active && !t.completed).toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  String areaBackgroundAbsolutePath(Area area) =>
      _assetResolver.resolve(area.backgroundPath);

  String connectionLabel(Connection connection) {
    final dest = connection.destinationFor(_currentAreaId);
    return '${_area(dest)?.name ?? 'Area $dest'} (${connection.travelMinutes}m)';
  }

  // ---------- ACTIONS ----------

  void selectArea(int areaId) {
    if (_area(areaId) == null) return;
    _currentAreaId = areaId;
    _logLine('Teleporte para ${currentArea.name}.');
    notifyListeners();
  }

  void restart() {
    _resetRuntime();
    notifyListeners();
  }

  void travelThrough(int connectionId) {
    final c = _conn(connectionId);
    if (c == null || !currentArea.connectionIds.contains(connectionId)) return;
    if (c.locked) {
      _logLine('Ligacao bloqueada.');
      notifyListeners();
      return;
    }
    final destId = c.destinationFor(_currentAreaId);
    final dest = _area(destId);
    if (dest == null || dest.locked) {
      _logLine('Destino bloqueado.');
      notifyListeners();
      return;
    }
    _currentAreaId = destId;
    _elapsedMinutes += c.travelMinutes;
    _minutesSincePopulate += c.travelMinutes;
    _logLine('Movimento: ${currentArea.name} (+${c.travelMinutes} min).');
    _tick();
  }

  void startDialogue(int dialogueId) {
    if (_currentDialogue != null) return;
    final d = _find(_activeDialogues, (d) => d.id == dialogueId);
    if (d == null) return;
    _currentDialogue = d;
    _currentLineIndex = 0;
    _logLine('Dialogo: ${d.name}');
    notifyListeners();
  }

  void advanceLine() {
    if (_currentDialogue == null) return;
    _currentLineIndex++;
    if (_currentLineIndex >= _currentDialogue!.lines.length) {
      _closeDialogue();
    } else {
      notifyListeners();
    }
  }

  void skipDialogue() => _closeDialogue();

  void _closeDialogue() {
    final d = _currentDialogue;
    if (d == null) return;
    _applyConsequences(d.consequences);
    if (d.singleTrigger || d.selfRemove) {
      _activeDialogues.removeWhere((x) => x.id == d.id);
      _dialoguesPool.removeWhere((x) => x.id == d.id);
    }
    _logLine('Dialogo concluido: ${d.name}');
    _currentDialogue = null;
    _currentLineIndex = 0;
    _tick();
  }

  void completeTask(int taskId) {
    final t = _task(taskId);
    if (t == null || !t.active || t.completed) return;
    _replace(_tasks, (x) => x.id == taskId, t.copyWith(active: false, completed: true));
    _applyConsequences(t.consequences);
    _logLine('Tarefa concluida: ${t.name}');
    _tick();
  }

  // ---------- RUNTIME ----------

  void _resetRuntime() {
    _areas = blueprint.areas.values
        .map((a) => a.copyWith(connectionIds: List<int>.from(a.connectionIds), clearDialogueId: true))
        .toList();
    _connections = blueprint.connections.values.map((c) => c.copyWith()).toList();
    _characters = blueprint.characters.values.toList();
    _gamestates = blueprint.gamestates.values.map((g) => g.copyWith()).toList();
    _dialoguesPool = blueprint.dialogues.values.toList();
    _activeDialogues = [];
    _tasks = blueprint.tasks.values
        .map((t) => t.copyWith(active: false, completed: false))
        .toList();
    _events = blueprint.events.values.toList();

    _currentAreaId = blueprint.startingAreaId;
    _elapsedMinutes = 0;
    _minutesSincePopulate = 0;
    _currentDialogue = null;
    _currentLineIndex = 0;

    _log
      ..clear()
      ..add('Runtime iniciado em ${currentArea.name}.');

    _evaluateTriggers();
  }

  void _tick() {
    _evaluateTriggers();
    if (_minutesSincePopulate >= 60) {
      _minutesSincePopulate = 0;
    }
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
        final c = _applyEvent(event);
        if (event.singleTrigger) _events.removeWhere((e) => e.id == event.id);
        changed = changed || c;
      }

      for (final d in List<Dialogue>.from(_dialoguesPool)) {
        if (_activeDialogues.any((x) => x.id == d.id)) continue;
        if (_conditionsMet(d.preconditions)) {
          _activeDialogues.add(d);
          _logLine('Dialogo ativado: ${d.name}.');
          changed = true;
        }
      }

      for (final t in List<Task>.from(_tasks)) {
        if (t.completed) continue;
        final shouldActive = _conditionsMet(t.preconditions);
        if (t.active != shouldActive) {
          _replace(_tasks, (x) => x.id == t.id, t.copyWith(active: shouldActive));
          if (shouldActive) _logLine('Nova tarefa: ${t.name}.');
          changed = true;
        }
      }
    }
  }

  bool _conditionsMet(Map<int, bool> conds) {
    for (final e in conds.entries) {
      final s = _state(e.key);
      if (s == null || s.value != e.value) return false;
    }
    return true;
  }

  bool _applyEvent(Event event) {
    var changed = false;
    switch (event.type) {
      case EventType.enableArea:
      case EventType.disableArea:
        final area = _area(event.targetId);
        if (area != null) {
          final locked = event.type == EventType.disableArea;
          if (area.locked != locked) {
            _replace(_areas, (a) => a.id == area.id, area.copyWith(locked: locked));
            _logLine('Area ${area.name} ${locked ? "bloqueada" : "desbloqueada"}.');
            changed = true;
          }
        }
        break;
      case EventType.activateGameState:
        changed = _setGameState(event.targetId, true) || changed;
        break;
      case EventType.deactivateGameState:
        changed = _setGameState(event.targetId, false) || changed;
        break;
      default:
        break;
    }
    _applyConsequences(event.consequences);
    return changed;
  }

  bool _setGameState(int id, bool value) {
    final s = _state(id);
    if (s == null || s.value == value) return false;
    _replace(_gamestates, (x) => x.id == id, s.copyWith(value: value));
    _logLine('${s.name} = $value');
    return true;
  }

  void _applyConsequences(Map<int, bool> cons) {
    for (final e in cons.entries) {
      _setGameState(e.key, e.value);
    }
  }

  void _logLine(String msg) {
    _log.add(msg);
    if (_log.length > 200) _log.removeRange(0, _log.length - 200);
  }
}
