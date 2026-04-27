import 'dart:math';

enum DialogueType { text, chat, localized, playerChat }

enum EventType {
  enableArea,
  disableArea,
  toggleArea,
  enableConnection,
  disableConnection,
  toggleConnection,
  activateGameState,
  deactivateGameState,
  toggleGameState,
  forceDialogue,
  removeDialogue,
  forceEvent,
  removeEvent,
}

enum ActivityType { movement, dialogue, task }

class GameArea {
  const GameArea({
    required this.id,
    required this.name,
    required this.backgroundPath,
    required this.connectionIds,
    this.locked = false,
    this.dialogueId,
  });

  final int id;
  final String name;
  final String backgroundPath;
  final List<int> connectionIds;
  final bool locked;
  final int? dialogueId;

  GameArea copyWith({
    String? name,
    String? backgroundPath,
    List<int>? connectionIds,
    bool? locked,
    Object? dialogueId = _sentinel,
  }) {
    return GameArea(
      id: id,
      name: name ?? this.name,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      connectionIds: connectionIds ?? this.connectionIds,
      locked: locked ?? this.locked,
      dialogueId: dialogueId == _sentinel ? this.dialogueId : dialogueId as int?,
    );
  }
}

class GameConnection {
  const GameConnection({
    required this.id,
    required this.areaA,
    required this.areaB,
    required this.travelMinutes,
    required this.iconIdle,
    required this.iconHover,
    required this.iconPosition,
    this.iconRotation = 0,
    this.iconScale = 1,
    this.locked = false,
  });

  final int id;
  final int areaA;
  final int areaB;
  final int travelMinutes;
  final String iconIdle;
  final String iconHover;
  final Point<double> iconPosition;
  final double iconRotation;
  final double iconScale;
  final bool locked;

  int destinationFor(int origin) {
    if (origin == areaA) {
      return areaB;
    }
    return areaA;
  }

  GameConnection copyWith({
    bool? locked,
    int? travelMinutes,
  }) {
    return GameConnection(
      id: id,
      areaA: areaA,
      areaB: areaB,
      travelMinutes: travelMinutes ?? this.travelMinutes,
      iconIdle: iconIdle,
      iconHover: iconHover,
      iconPosition: iconPosition,
      iconRotation: iconRotation,
      iconScale: iconScale,
      locked: locked ?? this.locked,
    );
  }
}

class GameCharacter {
  const GameCharacter({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.portraitPath,
    required this.areaId,
    required this.bodyPath,
  });

  final int id;
  final String name;
  final String colorHex;
  final String portraitPath;
  final int areaId;
  final String bodyPath;
}

class DialogueLine {
  const DialogueLine({
    required this.speakerId,
    required this.emotionId,
    required this.text,
  });

  final int speakerId;
  final int emotionId;
  final String text;
}

class GameDialogue {
  const GameDialogue({
    required this.id,
    required this.name,
    required this.type,
    required this.characterIds,
    required this.lines,
    required this.singleTrigger,
    required this.preconditions,
    required this.consequences,
    this.selfRemove = false,
    this.priority = 0,
    this.areaId,
    this.topic,
  });

  final int id;
  final String name;
  final DialogueType type;
  final List<int> characterIds;
  final List<DialogueLine> lines;
  final bool singleTrigger;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;
  final bool selfRemove;
  final int priority;
  final int? areaId;
  final String? topic;
}

class GameTask {
  const GameTask({
    required this.id,
    required this.name,
    required this.session,
    required this.section,
    required this.areaId,
    required this.iconIdle,
    required this.iconHover,
    required this.iconPosition,
    required this.iconRotation,
    required this.iconScale,
    required this.singleTrigger,
    required this.preconditions,
    required this.consequences,
    this.active = false,
    this.completed = false,
  });

  final int id;
  final String name;
  final int session;
  final int section;
  final int areaId;
  final String iconIdle;
  final String iconHover;
  final Point<double> iconPosition;
  final double iconRotation;
  final double iconScale;
  final bool singleTrigger;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;
  final bool active;
  final bool completed;

  GameTask copyWith({
    bool? active,
    bool? completed,
  }) {
    return GameTask(
      id: id,
      name: name,
      session: session,
      section: section,
      areaId: areaId,
      iconIdle: iconIdle,
      iconHover: iconHover,
      iconPosition: iconPosition,
      iconRotation: iconRotation,
      iconScale: iconScale,
      singleTrigger: singleTrigger,
      preconditions: preconditions,
      consequences: consequences,
      active: active ?? this.active,
      completed: completed ?? this.completed,
    );
  }
}

class GameEvent {
  const GameEvent({
    required this.id,
    required this.name,
    required this.type,
    required this.targetId,
    required this.singleTrigger,
    required this.preconditions,
    required this.consequences,
  });

  final int id;
  final String name;
  final EventType type;
  final int targetId;
  final bool singleTrigger;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;
}

class GameStateFlag {
  const GameStateFlag({
    required this.id,
    required this.name,
    required this.value,
  });

  final int id;
  final String name;
  final bool value;

  GameStateFlag copyWith({
    bool? value,
  }) {
    return GameStateFlag(
      id: id,
      name: name,
      value: value ?? this.value,
    );
  }
}

class GameWorldBlueprint {
  const GameWorldBlueprint({
    required this.startingAreaId,
    required this.areas,
    required this.connections,
    required this.characters,
    required this.gamestates,
    required this.dialogues,
    required this.tasks,
    required this.events,
  });

  final int startingAreaId;
  final Map<int, GameArea> areas;
  final Map<int, GameConnection> connections;
  final Map<int, GameCharacter> characters;
  final Map<int, GameStateFlag> gamestates;
  final Map<int, GameDialogue> dialogues;
  final Map<int, GameTask> tasks;
  final Map<int, GameEvent> events;
}

const Object _sentinel = Object();
