import 'package:flutter/material.dart';

import '../data/app_preferences.dart';
import '../data/dialogue_ai_service.dart';
import '../data/save_file_service.dart';
import '../data/world_blueprint_service.dart';
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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final BlueprintEditor _editor;
  GameEngine? _engine;
  SaveData? _currentSave;
  bool _inGame = false;
  bool _showingSaveSelection = true;
  bool _worldLoaded = false;

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
    WidgetsBinding.instance.addObserver(this);
    _loadWorld();
  }

  Future<void> _loadWorld() async {
    final bp = await WorldBlueprintService.load();
    if (bp != null) {
      _editor.loadBlueprint(bp);
    }
    // If no world.json, editor starts with empty default blueprint
    setState(() => _worldLoaded = true);
  }

  Future<void> _saveWorld() async {
    await WorldBlueprintService.save(_editor.build());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine?.removeListener(_onEngineChanged);
    _editor.dispose();
    _engine?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _saveWorld();
      // Only save game state if not mid-dialogue (would lose dialogue progress)
      if (_currentSave != null && _engine != null && !_engine!.isInDialogue) {
        SaveFileService.saveSave(_engine!.saveState(_currentSave!.saveName));
      }
    }
  }

  // ── Auto-save ────────────────────────────────────────────────────────────

  void _onEngineChanged() {
    if (_currentSave == null || _engine == null || !_inGame) return;
    final areaId = _engine!.currentArea.id;
    if (_lastAutoSaveAreaId != null && areaId != _lastAutoSaveAreaId) {
      SaveFileService.saveSave(_engine!.saveState(_currentSave!.saveName));
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

  Future<void> _launchGame() async {
    final bp = _editor.build();
    if (bp.areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adiciona pelo menos uma area primeiro.')),
      );
      return;
    }

    // Persist world before launching
    await _saveWorld();

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

  // ── Editor save world ─────────────────────────────────────────────────────

  Future<void> _onEditorSaveWorld() async {
    await _saveWorld();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mundo guardado.')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_worldLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
        onSaveWorld: _onEditorSaveWorld,
        onBack: () => setState(() => _showingSaveSelection = true),
      ),
    );
  }
}
