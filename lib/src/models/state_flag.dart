class StateFlag {
  const StateFlag({
    required this.id,
    required this.name,
    required this.value,
  });

  final int id;
  final String name;
  final bool value;

  StateFlag copyWith({bool? value}) =>
      StateFlag(id: id, name: name, value: value ?? this.value);
}
