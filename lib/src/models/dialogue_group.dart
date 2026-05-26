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
}
