import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/renpy_asset_resolver.dart';
import '../models/area.dart';
import '../models/character.dart';
import '../models/connection.dart';
import '../models/dialogue.dart';
import '../models/event.dart';
import '../models/save_data.dart';
import '../models/state_flag.dart';
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
  late List<Event> _events;

  int _currentAreaId = 1;
  int _elapsedMinutes = 0;
  int _minutesSincePopulate = 0;
  final List<String> _log = [];

  Dialogue? _currentDialogue;
  DialogueNode? _currentNode;
  int _stepCount = 0;
  int _totalSteps = 0;
  bool _gameOver = false;

  /// Conversation history for emotion choices (last 4 exchanges).
  final List<(int emotionId, String playerLine)> _conversationHistory = [];

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
  // ---------- GETTERS ----------

  RenpyAssetResolver get assetResolver => _assetResolver;

  String get formattedTime {
    final h = (_elapsedMinutes ~/ 60) % 24;
    final m = _elapsedMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  List<String> get log => List.unmodifiable(_log.reversed);
  List<Area> get allAreas => [..._areas]..sort((a, b) => a.id.compareTo(b.id));
  List<StateFlag> get gameStates =>
      [..._gamestates]..sort((a, b) => a.id.compareTo(b.id));

  List<StateFlag> get activeGameStates =>
      _gamestates.where((s) => s.value).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  List<Dialogue> get activeDialogues =>
      [..._activeDialogues]..sort((a, b) => b.priority.compareTo(a.priority));

  Area get currentArea =>
      _area(_currentAreaId) ??
      _areas.firstOrNull ??
      const Area(id: 0, name: '', backgroundPath: '', connectionIds: []);

  List<Connection> get currentConnections =>
      currentArea.connectionIds.map(_conn).whereType<Connection>().toList();

  List<Character> get currentCharacters =>
      _characters.where((c) => c.areaId == _currentAreaId).toList();

  List<Dialogue> get currentAreaDialogues =>
      _activeDialogues
          .where((d) => d.areaId == null || d.areaId == _currentAreaId)
          .toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));

  bool get isGameOver => _gameOver;
  bool get isInDialogue => _currentDialogue != null;
  Dialogue? get currentDialogue => _currentDialogue;

  DialogueLine? get currentLine => _currentNode?.line;

  int get currentLineIndex => _stepCount;

  int get totalLines => _totalSteps;

  /// True when at a player emotion choice node.
  bool get emotionModeActive => _currentNode?.isChoice ?? false;

  /// Current choice node when [emotionModeActive] is true.
  DialogueChoice? get currentChoiceNode => _currentNode?.choice;

  /// Emotion IDs that have branch children on the current choice node.
  Set<int> get availableEmotionIds =>
      _currentNode?.children?.keys.toSet() ?? {};

  /// Player line text for an emotion: reads choices map first (AI-generated),
  /// falls back to branch root line if it is a player node (editor-created).
  String playerLineForEmotion(int emotionId) {
    final fromChoices = _currentNode?.choice?.choices[emotionId];
    if (fromChoices != null && fromChoices.isNotEmpty) return fromChoices;
    final root = _currentNode?.children?[emotionId];
    if (root?.isLine == true && root!.line!.speakerId == 0) {
      return root.line!.text;
    }
    return '';
  }

  /// Last exchanges for AI context. (emotionId, playerLine).
  List<(int, String)> get conversationHistory =>
      List.unmodifiable(_conversationHistory);

  bool isAreaSelected(Area area) => area.id == _currentAreaId;

  String speakerName(int speakerId) {
    if (speakerId == 0) {
      return _char(0)?.name ?? 'Jogador';
    }
    return _char(speakerId)?.name ?? 'NPC $speakerId';
  }

  String speakerColor(int speakerId) {
    if (speakerId == 0) {
      return _char(0)?.colorHex ?? '#009900';
    }
    return _char(speakerId)?.colorHex ?? '#ffffff';
  }

  String resolveAsset(String path) => _assetResolver.resolve(path);
  bool assetExists(String path) => _assetResolver.exists(path);

  /// Returns absolute path to speaker portrait for given emotion.
  /// Falls back to default portrait, then empty string.
  String speakerPortraitPath(int speakerId, int? emotionId) {
    final char = _char(speakerId);
    if (char == null || char.portraitPath.isEmpty) return '';

    // Derive emotion path: "editor/portraits/portrait (1).png"
    //   → "editor/portraits/portrait (1)/portrait (emotionId).png"
    final rel = char.portraitPath;
    final dir = p.dirname(rel);
    final stem = p.basenameWithoutExtension(rel);
    final portraitId = emotionId ?? 0;
    final emotionRel = p.join(dir, stem, 'portrait ($portraitId).png');
    if (_assetResolver.exists(emotionRel))
      return _assetResolver.resolve(emotionRel);

    // Fall back to default portrait
    if (_assetResolver.exists(rel)) return _assetResolver.resolve(rel);
    return '';
  }

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
    _tick(autoStart: true);
  }

  void startDialogue(int dialogueId) {
    if (_currentDialogue != null) return;
    final d = _find(_activeDialogues, (d) => d.id == dialogueId);
    if (d == null) return;
    _currentDialogue = d;
    _currentNode = d.parentNode;
    _stepCount = 0;
    _totalSteps = _countChain(d.parentNode);
    _conversationHistory.clear();
    _logLine('Dialogo: ${d.name}');
    notifyListeners();
  }

  /// Player selected emotion at current choice node. Advances past it.
  void selectEmotion(int emotionId) {
    if (!emotionModeActive || _currentNode == null) return;
    final choiceNode = _currentNode!;

    _elapsedMinutes += 1;
    _minutesSincePopulate += 1;
    final playerLine = playerLineForEmotion(emotionId);
    _conversationHistory.add((emotionId, playerLine));
    if (_conversationHistory.length > 4) _conversationHistory.removeAt(0);

    final branchRoot = choiceNode.children?[emotionId] ?? choiceNode.nextNode;

    if (playerLine.isNotEmpty) {
      // Show player speaking before advancing to branch
      final synthetic = DialogueNode(
        line: DialogueLine(speakerId: 0, text: playerLine),
        branchConsequences:
            branchRoot == null ? Map.from(choiceNode.branchConsequences) : {},
      );
      synthetic.nextNode = branchRoot;
      _currentNode = synthetic;
      _stepCount++;
      notifyListeners();
    } else {
      _currentNode = branchRoot;
      _stepCount++;
      if (_currentNode == null) {
        _applyConsequences(choiceNode.branchConsequences);
        _closeDialogue();
      } else {
        notifyListeners();
      }
    }
  }

  void advanceLine() {
    final node = _currentNode;
    if (node == null || !node.isLine) return;
    _currentNode = node.nextNode;
    _stepCount++;
    if (_currentNode == null) {
      _applyConsequences(node.branchConsequences);
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
    _currentNode = null;
    _stepCount = 0;
    if (d.isEnding) {
      _gameOver = true;
      notifyListeners();
      return;
    }

    // Group continuation: if this dialogue belonged to a group, immediately
    // start the next available dialogue in that group instead of returning
    // to area view.
    if (d.groupId != null) {
      _evaluateTriggers();
      final next = _activeDialogues
          .where((x) => x.groupId == d.groupId && x.id != d.id)
          .fold<Dialogue?>(null, (best, x) {
        if (best == null || x.priority > best.priority) return x;
        return best;
      });
      if (next != null) {
        _currentDialogue = next;
        _currentNode = next.parentNode;
        _stepCount = 0;
        _totalSteps = _countChain(next.parentNode);
        _conversationHistory.clear();
        _logLine('Dialogo (grupo): ${next.name}');
        notifyListeners();
        return;
      }
    }

    _tick();
  }

  int _countChain(DialogueNode? node) {
    var count = 0;
    var n = node;
    while (n != null) {
      count++;
      n = n.nextNode;
    }
    return count;
  }

  // ---------- RUNTIME ----------

  void _resetRuntime() {
    _areas = blueprint.areas.values
        .map(
          (a) => a.copyWith(
            connectionIds: List<int>.from(a.connectionIds),
            clearDialogueId: true,
          ),
        )
        .toList();
    _connections = blueprint.connections.values
        .map((c) => c.copyWith())
        .toList();
    _characters = blueprint.characters.values.toList();
    _gamestates = blueprint.gamestates.values.map((g) => g.copyWith()).toList();
    _dialoguesPool = blueprint.dialogues.values.toList();
    _activeDialogues = [];
    _events = blueprint.events.values.toList();

    _currentAreaId = blueprint.startingAreaId;
    _elapsedMinutes = 0;
    _minutesSincePopulate = 0;
    _currentDialogue = null;
    _currentNode = null;
    _stepCount = 0;
    _gameOver = false;
    _conversationHistory.clear();

    _log
      ..clear()
      ..add('Runtime iniciado em ${currentArea.name}.');

    _evaluateTriggers();
    _autoStartDialogue();
  }

  bool get hasPendingAreaDialogue => currentAreaDialogues.isNotEmpty;

  void stayAndChat() {
    _autoStartDialogue();
    notifyListeners();
  }

  void _tick({bool autoStart = false}) {
    _evaluateTriggers();
    if (_minutesSincePopulate >= 60) {
      _minutesSincePopulate = 0;
    }
    if (autoStart) _autoStartDialogue();
    notifyListeners();
  }

  void _autoStartDialogue() {
    if (_currentDialogue != null) return;
    final pending = currentAreaDialogues;
    if (pending.isEmpty) return;
    final d = pending.first; // already sorted by priority desc
    _currentDialogue = d;
    _currentNode = d.parentNode;
    _stepCount = 0;
    _totalSteps = _countChain(d.parentNode);
    _conversationHistory.clear();
    _logLine('Dialogo (auto): ${d.name}');
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
            _replace(
              _areas,
              (a) => a.id == area.id,
              area.copyWith(locked: locked),
            );
            _logLine(
              'Area ${area.name} ${locked ? "bloqueada" : "desbloqueada"}.',
            );
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

  // ---------- SAVE/RESTORE ----------

  SaveData saveState(String saveName) {
    // Capture game flags (StateFlag values)
    final gameFlags = <int, bool>{};
    for (final flag in _gamestates) {
      gameFlags[flag.id] = flag.value;
    }

    // Capture character positions
    final charPositions = <int, int>{};
    for (final char in _characters) {
      charPositions[char.id] = char.areaId;
    }

    return SaveData(
      saveName: saveName,
      timestamp: DateTime.now(),
      currentAreaId: _currentAreaId,
      elapsedMinutes: _elapsedMinutes,
      minutesSincePopulate: _minutesSincePopulate,
      log: List<String>.from(_log),
      gameFlags: gameFlags,
      characterPositions: charPositions,
    );
  }

  void restoreState(SaveData save) {
    _currentAreaId = save.currentAreaId;
    _elapsedMinutes = save.elapsedMinutes;
    _minutesSincePopulate = save.minutesSincePopulate;
    _log.clear();
    _log.addAll(save.log);

    // Restore game flags
    for (final e in save.gameFlags.entries) {
      _setGameState(e.key, e.value);
    }

    // Restore character positions
    for (final e in save.characterPositions.entries) {
      final char = _char(e.key);
      if (char != null) {
        _replace(
          _characters,
          (c) => c.id == e.key,
          char.copyWith(areaId: e.value),
        );
      }
    }

    _tick();
  }
}
