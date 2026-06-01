class Area {
  const Area({
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

  Area copyWith({
    String? name,
    String? backgroundPath,
    List<int>? connectionIds,
    bool? locked,
    int? dialogueId,
    bool clearDialogueId = false,
  }) {
    return Area(
      id: id,
      name: name ?? this.name,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      connectionIds: connectionIds ?? this.connectionIds,
      locked: locked ?? this.locked,
      dialogueId: clearDialogueId ? null : (dialogueId ?? this.dialogueId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'backgroundPath': backgroundPath,
        'connectionIds': connectionIds,
        'locked': locked,
        if (dialogueId != null) 'dialogueId': dialogueId,
      };

  factory Area.fromJson(Map<String, dynamic> j) => Area(
        id: j['id'] as int,
        name: j['name'] as String,
        backgroundPath: j['backgroundPath'] as String,
        connectionIds: (j['connectionIds'] as List).cast<int>(),
        locked: j['locked'] as bool? ?? false,
        dialogueId: j['dialogueId'] as int?,
      );
}
