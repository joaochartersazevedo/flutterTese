class StateFlag {
  const StateFlag({
    required this.id,
    required this.name,
    required this.value,
  });
  final String id;
  final String name;
  final bool value;

  StateFlag copyWith({bool? value}) {
    return StateFlag(
      id: id,
      name: name,
      value: value ?? this.value,
    );
  }
}
