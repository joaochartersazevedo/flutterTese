import 'dart:math';

import '../domain/models.dart';

GameWorldBlueprint buildSeedWorld() {
  final areas = <int, GameArea>{
    1: const GameArea(
      id: 1,
      name: 'Escadas 1',
      backgroundPath: 'editor/areas/area (1).jpg',
      connectionIds: [1, 2],
    ),
    2: const GameArea(
      id: 2,
      name: 'Escadas 2',
      backgroundPath: 'editor/areas/area (2).jpg',
      connectionIds: [1, 3, 4],
    ),
    3: const GameArea(
      id: 3,
      name: 'Corredor A',
      backgroundPath: 'editor/areas/area (3).jpg',
      connectionIds: [2, 5],
    ),
    4: const GameArea(
      id: 4,
      name: 'Sala A',
      backgroundPath: 'editor/areas/area (4).jpg',
      connectionIds: [3],
    ),
    5: const GameArea(
      id: 5,
      name: 'Patio',
      backgroundPath: 'editor/areas/area (5).jpg',
      connectionIds: [4, 5],
    ),
  };

  final connections = <int, GameConnection>{
    1: const GameConnection(
      id: 1,
      areaA: 1,
      areaB: 2,
      travelMinutes: 5,
      iconIdle: 'editor/connections/blue.png',
      iconHover: 'editor/connections/cyan.png',
      iconPosition: Point(0.85, 0.25),
      iconRotation: 90,
      iconScale: 1.4,
    ),
    2: const GameConnection(
      id: 2,
      areaA: 1,
      areaB: 3,
      travelMinutes: 4,
      iconIdle: 'editor/connections/red.png',
      iconHover: 'editor/connections/magenta.png',
      iconPosition: Point(0.65, 0.65),
      iconRotation: 40,
      iconScale: 1.1,
    ),
    3: const GameConnection(
      id: 3,
      areaA: 2,
      areaB: 4,
      travelMinutes: 3,
      iconIdle: 'editor/connections/green.png',
      iconHover: 'editor/connections/yellow.png',
      iconPosition: Point(0.70, 0.55),
      iconRotation: 180,
      iconScale: 1.2,
    ),
    4: const GameConnection(
      id: 4,
      areaA: 2,
      areaB: 5,
      travelMinutes: 6,
      iconIdle: 'editor/connections/default.png',
      iconHover: 'editor/connections/blue.png',
      iconPosition: Point(0.90, 0.70),
      iconRotation: 0,
      iconScale: 1.0,
    ),
    5: const GameConnection(
      id: 5,
      areaA: 3,
      areaB: 5,
      travelMinutes: 8,
      iconIdle: 'editor/connections/cyan.png',
      iconHover: 'editor/connections/green.png',
      iconPosition: Point(0.45, 0.80),
      iconRotation: 220,
      iconScale: 1.0,
    ),
  };

  final characters = <int, GameCharacter>{
    1: const GameCharacter(
      id: 1,
      name: 'Afonso',
      colorHex: '#11a7ef',
      portraitPath: 'editor/portraits/portrait (1).png',
      areaId: 3,
      bodyPath: 'editor/bodies/body (1).png',
    ),
    2: const GameCharacter(
      id: 2,
      name: 'Bruna',
      colorHex: '#f0298a',
      portraitPath: 'editor/portraits/portrait (2).png',
      areaId: 4,
      bodyPath: 'editor/bodies/body (2).png',
    ),
    3: const GameCharacter(
      id: 3,
      name: 'Diogo',
      colorHex: '#26c96d',
      portraitPath: 'editor/portraits/portrait (3).png',
      areaId: 5,
      bodyPath: 'editor/bodies/body (3).png',
    ),
  };

  final gamestates = <int, GameStateFlag>{
    1: const GameStateFlag(id: 1, name: 'Falei com Afonso', value: false),
    2: const GameStateFlag(id: 2, name: 'Falei com Bruna', value: false),
    3: const GameStateFlag(id: 3, name: 'Conversa videogames ativa', value: false),
    4: const GameStateFlag(id: 4, name: 'Task estudo concluida', value: false),
    5: const GameStateFlag(id: 5, name: 'Patio trancado por evento', value: false),
  };

  final dialogues = <int, GameDialogue>{
    1: const GameDialogue(
      id: 1,
      name: 'Ice Cream',
      type: DialogueType.chat,
      characterIds: [1, 2],
      lines: [
        DialogueLine(speakerId: 1, emotionId: 1, text: 'Sou o Afonso.'),
        DialogueLine(speakerId: 2, emotionId: 3, text: 'Sou a Bruna.'),
      ],
      singleTrigger: true,
      preconditions: {},
      consequences: {1: true},
      priority: 3,
    ),
    2: const GameDialogue(
      id: 2,
      name: 'Football',
      type: DialogueType.chat,
      characterIds: [2, 3],
      lines: [
        DialogueLine(speakerId: 2, emotionId: 2, text: 'Acho que ouvi a porta do patio a fechar.'),
        DialogueLine(speakerId: 3, emotionId: 4, text: 'Vamos verificar no intervalo.'),
      ],
      singleTrigger: true,
      preconditions: {},
      consequences: {2: true},
      priority: 2,
    ),
    3: const GameDialogue(
      id: 3,
      name: 'Videogames',
      type: DialogueType.chat,
      characterIds: [1, 3],
      lines: [
        DialogueLine(speakerId: 1, emotionId: 5, text: 'Este dialogo so aparece depois da primeira conversa.'),
        DialogueLine(speakerId: 3, emotionId: 6, text: 'Sabes quando vai ser o torneio?'),
      ],
      singleTrigger: true,
      preconditions: {1: true},
      consequences: {3: true},
      priority: 1,
    ),
    4: const GameDialogue(
      id: 4,
      name: 'Conversa com Afonso',
      type: DialogueType.playerChat,
      characterIds: [1],
      lines: [
        DialogueLine(speakerId: 1, emotionId: 1, text: 'Estudas hoje para o exame?'),
      ],
      singleTrigger: false,
      preconditions: {},
      consequences: {},
      selfRemove: false,
      priority: 10,
      areaId: 3,
      topic: 'the upcoming school exam',
    ),
  };

  final tasks = <int, GameTask>{
    1: const GameTask(
      id: 1,
      name: 'Rever apontamentos',
      session: 1,
      section: 1,
      areaId: 4,
      iconIdle: 'editor/task_icons/book.png',
      iconHover: 'editor/task_icons/books.png',
      iconPosition: Point(0.55, 0.70),
      iconRotation: 0,
      iconScale: 1.0,
      singleTrigger: true,
      preconditions: {1: true},
      consequences: {4: true},
    ),
  };

  final events = <int, GameEvent>{
    1: const GameEvent(
      id: 1,
      name: 'Lock Patio',
      type: EventType.disableArea,
      targetId: 5,
      singleTrigger: true,
      preconditions: {2: true},
      consequences: {5: true},
    ),
  };

  return GameWorldBlueprint(
    startingAreaId: 1,
    areas: areas,
    connections: connections,
    characters: characters,
    gamestates: gamestates,
    dialogues: dialogues,
    tasks: tasks,
    events: events,
  );
}
