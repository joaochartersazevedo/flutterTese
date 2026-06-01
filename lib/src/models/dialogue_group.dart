class DialogueGroup {
  const DialogueGroup({
    required this.id,
    required this.name,
    this.orderedDialogueIds = const [],
  });
  final int id;
  final String name;
  /// Dialogue IDs in the order they should trigger within this group.
  final List<int> orderedDialogueIds;

  DialogueGroup withOrder(List<int> ids) =>
      DialogueGroup(id: id, name: name, orderedDialogueIds: ids);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'orderedDialogueIds': orderedDialogueIds,
      };

  factory DialogueGroup.fromJson(Map<String, dynamic> j) => DialogueGroup(
        id: j['id'] as int,
        name: j['name'] as String,
        orderedDialogueIds: (j['orderedDialogueIds'] as List?)?.cast<int>() ?? [],
      );
}
