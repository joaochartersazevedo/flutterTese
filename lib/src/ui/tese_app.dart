import 'package:flutter/material.dart';

import '../data/seed_world.dart';
import '../domain/blueprint_editor.dart';
import '../logic/game_engine.dart';
import 'app_theme.dart';
import 'editor/editor_main.dart';
import 'game/game_main.dart';

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
  bool _inGame = false;

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
      _inGame = true;
    });
  }

  void _launchSeed() {
    final bp = buildSeedWorld();
    _editor.loadBlueprint(bp);
    _launchGame();
  }

  void _returnToEditor() => setState(() => _inGame = false);

  @override
  Widget build(BuildContext context) {
    if (_inGame && _engine != null) {
      return GameMain(engine: _engine!, onExit: _returnToEditor);
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
