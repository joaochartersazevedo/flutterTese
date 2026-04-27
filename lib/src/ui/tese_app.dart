import 'dart:io';

import 'package:flutter/material.dart';

import '../data/seed_world.dart';
import '../logic/game_engine.dart';

class TeseDesktopApp extends StatelessWidget {
  const TeseDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF23B8D7),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Tese Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF07121D),
        cardColor: const Color(0xFF102031),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: const Color(0xFFE7F4FF),
              displayColor: const Color(0xFFE7F4FF),
            ),
      ),
      home: const GameShell(),
    );
  }
}

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late final GameEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine(buildSeedWorld());
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _engine,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tese Desktop'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text('Tempo: ${_engine.formattedTime}'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FilledButton.tonalIcon(
                  onPressed: _engine.restart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reiniciar Runtime'),
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              SizedBox(
                width: 280,
                child: _LeftPanel(engine: _engine),
              ),
              Expanded(
                flex: 3,
                child: _CenterPanel(engine: _engine),
              ),
              SizedBox(
                width: 360,
                child: _RightPanel(engine: _engine),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E2538), Color(0xFF0A1A2A)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Areas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final area in engine.allAreas)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: engine.isAreaSelected(area)
                          ? const Color(0xFF1D3E58)
                          : const Color(0xFF102031),
                      child: ListTile(
                        dense: true,
                        title: Text(area.name),
                        subtitle: Text('ID ${area.id}'),
                        trailing: area.locked
                            ? const Icon(Icons.lock_outline)
                            : const Icon(Icons.lock_open),
                        onTap: () => engine.selectArea(area.id),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gamestates',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  for (final state in engine.gameStates)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            state.value ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 16,
                            color: state.value
                                ? const Color(0xFF52E29A)
                                : Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterPanel extends StatelessWidget {
  const _CenterPanel({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final area = engine.currentArea;
    final areaPath = engine.areaBackgroundAbsolutePath(area);
    final areaImage = File(areaPath);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (areaImage.existsSync())
              Image.file(
                areaImage,
                fit: BoxFit.cover,
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10253A), Color(0xFF1A4A67)],
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xB2000000)],
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Caminho: $areaPath',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFD0E6FF)),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final connection in engine.currentConnections)
                    FilledButton.tonal(
                      onPressed: connection.locked
                          ? null
                          : () => engine.travelThrough(connection.id),
                      child: Text(engine.connectionLabel(connection)),
                    ),
                  if (area.dialogueId != null)
                    FilledButton.icon(
                      onPressed: () => engine.startDialogue(area.dialogueId!),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Iniciar Dialogo desta Area'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1724),
        border: Border(
          left: BorderSide(color: Color(0xFF153149)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dialogos Ativos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ListView(
                children: [
                  for (final dialogue in engine.activeDialogues)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        title: Text(dialogue.name),
                        subtitle: Text(dialogue.type.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => engine.startDialogue(dialogue.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tarefas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListView(
                children: [
                  for (final task in engine.tasks)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        title: Text(task.name),
                        subtitle: Text(
                          task.completed
                              ? 'Concluida'
                              : task.active
                                  ? 'Ativa'
                                  : 'Inativa',
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            task.completed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          ),
                          onPressed: task.active && !task.completed
                              ? () => engine.completeTask(task.id)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log Runtime',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF07111B),
                  border: Border.all(color: const Color(0xFF17324A)),
                ),
                child: ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.all(8),
                  itemCount: engine.log.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        engine.log[index],
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
