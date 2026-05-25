import 'package:flutter/material.dart';

import '../data/app_preferences.dart';
import '../data/dialogue_ai_service.dart';
import '../data/save_file_service.dart';
import '../data/seed_world.dart';
import '../domain/blueprint_editor.dart';
import '../logic/game_engine.dart';
import '../models/save_data.dart';
import 'app_theme.dart';
import 'editor/editor_main.dart';
import 'game/game_main.dart';
import 'game/save_selection_screen.dart';

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

class _AppShellState extends State<AppShell> {
  late final BlueprintEditor _editor;
  GameEngine? _engine;
  SaveData? _currentSave;
  bool _inGame = false;
  bool _showingSaveSelection = true;

  // Auto-save tracking
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
  }

  @override
  void dispose() {
    _engine?.removeListener(_onEngineChanged);
    _editor.dispose();
    _engine?.dispose();
    super.dispose();
  }

  // ── Auto-save ────────────────────────────────────────────────────────────

  void _onEngineChanged() {
    if (_currentSave == null || _engine == null || !_inGame) return;
    final areaId = _engine!.currentArea.id;
    if (_lastAutoSaveAreaId != null && areaId != _lastAutoSaveAreaId) {
      SaveFileService.saveSave(
          _engine!.saveState(_currentSave!.saveName));
    }
    _lastAutoSaveAreaId = areaId;
  }

  // ── Save selection ────────────────────────────────────────────────────────

  Future<void> _onSaveSelected(SaveData save) async {
    if (mounted) {
      setState(() {
        _currentSave = save;
        _showingSaveSelection = false;
      });
    }
  }

  // ── Game launch ───────────────────────────────────────────────────────────

  void _launchGame() {
    final bp = _editor.build();
    if (bp.areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adiciona pelo menos uma area primeiro.')),
      );
      return;
    }

    _engine?.removeListener(_onEngineChanged);
    setState(() {
      _engine?.dispose();
      _engine = GameEngine(bp);

      if (_currentSave != null) {
        _engine!.restoreState(_currentSave!);
      }

      _lastAutoSaveAreaId = _engine!.currentArea.id;
      _engine!.addListener(_onEngineChanged);

      _inGame = true;
      _showingSaveSelection = false;
    });
  }

  void _launchSeed() {
    final bp = buildSeedWorld();
    _editor.loadBlueprint(bp);
    _launchGame();
  }

  /// Loads the seed world into the editor without launching the game.
  void _loadSeedToEditor() {
    _editor.loadBlueprint(buildSeedWorld());
  }

  // ── Return to editor ──────────────────────────────────────────────────────

  Future<void> _returnToEditor() async {
    _engine?.removeListener(_onEngineChanged);

    if (_currentSave != null && _engine != null) {
      final updatedSave = _engine!.saveState(_currentSave!.saveName);
      await SaveFileService.saveSave(updatedSave);
    }

    if (mounted) {
      setState(() {
        _inGame = false;
        _showingSaveSelection = true;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showingSaveSelection) {
      return Scaffold(
        body: SaveSelectionScreen(
        onSaveSelected: _onSaveSelected,
        startingAreaId: _editor.startingAreaId,
      ),
      );
    }

    if (_inGame && _engine != null) {
      return GameMain(
        engine: _engine!,
        currentSave: _currentSave,
        onExit: _returnToEditor,
      );
    }

    return ListenableBuilder(
      listenable: _editor,
      builder: (context, _) => EditorMain(
        editor: _editor,
        onPlay: _launchGame,
        onPlaySeed: _launchSeed,
        onLoadSeed: _loadSeedToEditor,
        onBack: () => setState(() => _showingSaveSelection = true),
      ),
    );
  }
}
