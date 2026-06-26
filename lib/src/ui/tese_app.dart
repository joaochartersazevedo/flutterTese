import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_preferences.dart';
import '../data/dialogue_ai_service.dart';
import '../data/save_file_service.dart';
import '../data/testing_checklist.dart';
import '../domain/blueprint_editor.dart';
import '../logic/game_engine.dart';
import '../models/save_data.dart';
import 'app_theme.dart';
import 'editor/editor_main.dart';
import 'game/game_main.dart';
import 'game/save_selection_screen.dart';
import 'widgets/testing_checklist_panel.dart';

class TeseDesktopApp extends StatelessWidget {
  const TeseDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tese Visual Novel',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final BlueprintEditor _editor;
  GameEngine? _engine;
  SaveData? _currentSave;
  bool _inGame = false;
  bool _showingSaveSelection = true;

  // Auto-save
  Timer? _autoSaveTimer;

  // Game auto-save tracking
  int? _lastAutoSaveAreaId;

  @override
  void initState() {
    super.initState();
    AppPreferences.load();
    final savedKey = AppPreferences.apiKey;
    if (savedKey.isNotEmpty) {
      DialogueAiService.instance.setApiKey(savedKey);
    }
    _editor = BlueprintEditor();
    _editor.addListener(_scheduleAutoSave);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Builds a save from the editor's current world, carrying over
  /// [_currentSave]'s progress (flags, NPC positions, log, elapsed time).
  SaveData _buildCurrentSave() => _editor.build(
        saveName: _currentSave!.saveName,
        timestamp: _currentSave!.timestamp,
        elapsedMinutes: _currentSave!.elapsedMinutes,
        minutesSincePopulate: _currentSave!.minutesSincePopulate,
        log: _currentSave!.log,
        gameFlags: _currentSave!.gameFlags,
        characterPositions: _currentSave!.characterPositions,
      );

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _engine?.removeListener(_onEngineChanged);
    _editor.dispose();
    _engine?.dispose();
    super.dispose();
  }

  // Player progress (flags, NPC positions, log, elapsed time) lives only in
  // the running GameEngine — it is never written back to the save file, so
  // closing the app or pressing Play always resets it to the save's
  // baseline. Saves on disk only change when the editor explicitly saves
  // world edits.

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      if (_currentSave == null || _inGame) return;
      _currentSave = _buildCurrentSave();
      SaveFileService.saveSave(_currentSave!);
    }
  }

  // ── Auto-save ────────────────────────────────────────────────────────────

  void _onEngineChanged() {
    if (_currentSave == null || _engine == null || !_inGame) return;
    final areaId = _engine!.currentArea.id;
    if (_lastAutoSaveAreaId != null && areaId != _lastAutoSaveAreaId) {
      TestingChecklist.instance.mark('save_game');
    }
    _lastAutoSaveAreaId = areaId;
  }

  // ── Save selection ────────────────────────────────────────────────────────

  Future<void> _onSaveSelected(SaveData save) async {
    if (mounted) {
      setState(() {
        _currentSave = save;
        _editor.loadSave(save);
        _showingSaveSelection = false;
      });
      TestingChecklist.instance.mark('select_save');
    }
  }

  // ── Game launch ───────────────────────────────────────────────────────────

  Future<void> _launchGame() async {
    if (_editor.areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adiciona pelo menos uma area primeiro.')),
      );
      return;
    }

    final saveData = _buildCurrentSave();
    await SaveFileService.saveSave(saveData);

    _engine?.removeListener(_onEngineChanged);
    setState(() {
      _currentSave = saveData;
      _engine?.dispose();
      _engine = GameEngine(saveData);

      _lastAutoSaveAreaId = _engine!.currentArea.id;
      _engine!.addListener(_onEngineChanged);

      _inGame = true;
      _showingSaveSelection = false;
    });
    TestingChecklist.instance.mark('play_game');
  }

  // ── Return to editor ──────────────────────────────────────────────────────

  Future<void> _returnToEditor() async {
    _engine?.removeListener(_onEngineChanged);

    if (mounted) {
      setState(() {
        _inGame = false;
        _showingSaveSelection = true;
      });
      TestingChecklist.instance.mark('return_to_editor');
    }
  }

  // ── Editor auto-save ─────────────────────────────────────────────────────

  void _scheduleAutoSave() {
    if (_currentSave == null || _inGame) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 600), _doAutoSave);
  }

  Future<void> _doAutoSave() async {
    if (_currentSave == null || _inGame) return;
    final saveData = _buildCurrentSave();
    await SaveFileService.saveSave(saveData);
    if (mounted) {
      setState(() => _currentSave = saveData);
      TestingChecklist.instance.mark('save_world');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showingSaveSelection) {
      return Scaffold(
        body: SaveSelectionScreen(
          onSaveSelected: _onSaveSelected,
        ),
      );
    }

    if (_inGame && _engine != null) {
      return TestingChecklistOverlay(
        child: GameMain(
          engine: _engine!,
          currentSave: _currentSave,
          onExit: _returnToEditor,
        ),
      );
    }

    return TestingChecklistOverlay(
      child: ListenableBuilder(
        listenable: _editor,
        builder: (context, _) => EditorMain(
          editor: _editor,
          onPlay: _launchGame,
          onBack: () => setState(() => _showingSaveSelection = true),
        ),
      ),
    );
  }
}
