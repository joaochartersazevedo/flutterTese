import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _editor = BlueprintEditor();
  }

  @override
  void dispose() {
    _editor.dispose();
    _engine?.dispose();
    super.dispose();
  }

  Future<void> _onSaveSelected(SaveData save) async {
    if (mounted) {
      setState(() {
        _currentSave = save;
        _showingSaveSelection = false;
      });
    }
  }

  void _launchGame() {
    final bp = _editor.build();
    if (bp.areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adiciona pelo menos uma area primeiro.')),
      );
      return;
    }
    
    setState(() {
      _engine?.dispose();
      _engine = GameEngine(bp);
      
      // Restore save state if current save exists
      if (_currentSave != null) {
        _engine!.restoreState(_currentSave!);
      }
      
      _inGame = true;
      _showingSaveSelection = false;
    });
  }

  void _launchSeed() {
    final bp = buildSeedWorld();
    _editor.loadBlueprint(bp);
    _launchGame();
  }

  Future<void> _returnToEditor() async {
    // Save current game state if in game
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
      ),
    );
  }
}
