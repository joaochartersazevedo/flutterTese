import '../domain/models.dart';

WorldBlueprint buildSeedWorld() {
  final areas = <int, Area>{
    1: const Area(
      id: 1,
      name: 'Escadas 1',
      backgroundPath: 'editor/areas/area (1).jpg',
      connectionIds: [1, 2],
    ),
    2: const Area(
      id: 2,
      name: 'Escadas 2',
      backgroundPath: 'editor/areas/area (2).jpg',
      connectionIds: [1, 3, 4],
    ),
    3: const Area(
      id: 3,
      name: 'Corredor A',
      backgroundPath: 'editor/areas/area (3).jpg',
      connectionIds: [2, 5],
    ),
    4: const Area(
      id: 4,
      name: 'Sala A',
      backgroundPath: 'editor/areas/area (4).jpg',
      connectionIds: [3],
    ),
    5: const Area(
      id: 5,
      name: 'Patio',
      backgroundPath: 'editor/areas/area (5).jpg',
      connectionIds: [4, 5],
    ),
  };

  final connections = <int, Connection>{
    1: const Connection(id: 1, areaA: 1, areaB: 2, travelMinutes: 5),
    2: const Connection(id: 2, areaA: 1, areaB: 3, travelMinutes: 4),
    3: const Connection(id: 3, areaA: 2, areaB: 4, travelMinutes: 3),
    4: const Connection(id: 4, areaA: 2, areaB: 5, travelMinutes: 6),
    5: const Connection(id: 5, areaA: 3, areaB: 5, travelMinutes: 8),
  };

  final characters = <int, Character>{
    1: const Character(
      id: 1,
      name: 'Afonso',
      colorHex: '#11a7ef',
      portraitPath: 'editor/portraits/portrait (1).png',
      areaId: 3,
      bodyPath: 'editor/bodies/body (1).png',
    ),
    2: const Character(
      id: 2,
      name: 'Bruna',
      colorHex: '#f0298a',
      portraitPath: 'editor/portraits/portrait (2).png',
      areaId: 4,
      bodyPath: 'editor/bodies/body (2).png',
    ),
    3: const Character(
      id: 3,
      name: 'Diogo',
      colorHex: '#26c96d',
      portraitPath: 'editor/portraits/portrait (3).png',
      areaId: 5,
      bodyPath: 'editor/bodies/body (3).png',
    ),
  };

  final gamestates = <int, StateFlag>{
    1: const StateFlag(id: 1, name: 'Falei com Afonso', value: false),
    2: const StateFlag(id: 2, name: 'Falei com Bruna', value: false),
    3: const StateFlag(id: 3, name: 'Conversa videogames ativa', value: false),
    4: const StateFlag(id: 4, name: 'Task estudo concluida', value: false),
    5: const StateFlag(id: 5, name: 'Patio trancado por evento', value: false),
  };

  final dialogues = <int, Dialogue>{
    1: Dialogue(
      id: 1,
      name: 'Ice Cream',
      characterIds: [1, 2],
      parentNode: _chain([
        DialogueNode(
          line: DialogueLine(
            speakerId: 1,
            portraitId: 1,
            text: 'Sou o Afonso.',
          ),
        ),
        DialogueNode(
          line: DialogueLine(speakerId: 2, portraitId: 3, text: 'Sou a Bruna.'),
        ),
      ]),
      singleTrigger: true,
      preconditions: {},
      consequences: {1: true},
      priority: 3,
    ),
    2: Dialogue(
      id: 2,
      name: 'Football',
      characterIds: [2, 3],
      parentNode: _chain([
        DialogueNode(
          line: DialogueLine(
            speakerId: 2,
            portraitId: 2,
            text: 'Acho que ouvi a porta do patio a fechar.',
          ),
        ),
        DialogueNode(
          line: DialogueLine(
            speakerId: 3,
            portraitId: 4,
            text: 'Vamos verificar no intervalo.',
          ),
        ),
      ]),
      singleTrigger: true,
      preconditions: {},
      consequences: {2: true},
      priority: 2,
    ),
    3: Dialogue(
      id: 3,
      name: 'Videogames',
      characterIds: [1, 3],
      parentNode: _chain([
        DialogueNode(
          line: DialogueLine(
            speakerId: 1,
            portraitId: 1,
            text: 'Este dialogo so aparece depois da primeira conversa.',
          ),
        ),
        DialogueNode(
          line: DialogueLine(
            speakerId: 3,
            portraitId: 4,
            text: 'Sabes quando vai ser o torneio?',
          ),
        ),
      ]),
      singleTrigger: true,
      preconditions: {1: true},
      consequences: {3: true},
      priority: 1,
    ),
    4: Dialogue(
      id: 4,
      name: 'Conversa com Afonso',
      characterIds: [1],
      parentNode: _chain([
        DialogueNode(
          line: DialogueLine(
            speakerId: 1,
            portraitId: 1,
            text: 'Estudas hoje para o exame?',
          ),
        ),
        DialogueNode(
          choice: DialogueChoice(
            choices: {
              0: 'Não me apetece nada estudar.',
              2: 'Claro! Estou ansioso para estudar.',
              6: 'Sim, vou estudar mais tarde.',
            },
          ),
        ),
        DialogueNode(
          line: DialogueLine(
            speakerId: 1,
            portraitId: 1,
            text: 'Boa sorte no exame!',
          ),
        ),
      ]),
      singleTrigger: false,
      preconditions: {},
      consequences: {},
      selfRemove: false,
      priority: 10,
      areaId: 3,
      topic: 'the upcoming school exam',
    ),
  };

  final tasks = <int, Task>{
    1: const Task(
      id: 1,
      name: 'Rever apontamentos',
      session: 1,
      section: 1,
      areaId: 4,
      singleTrigger: true,
      preconditions: {1: true},
      consequences: {4: true},
    ),
  };

  final events = <int, Event>{
    1: const Event(
      id: 1,
      name: 'Lock Patio',
      type: EventType.disableArea,
      targetId: 5,
      singleTrigger: true,
      preconditions: {2: true},
      consequences: {5: true},
    ),
  };

  return WorldBlueprint(
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

DialogueNode _chain(List<DialogueNode> nodes) {
  assert(nodes.isNotEmpty);
  for (int i = 0; i < nodes.length - 1; i++) {
    nodes[i].nextNode = nodes[i + 1];
  }
  return nodes.first;
}
