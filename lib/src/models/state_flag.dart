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

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'value': value};

  factory StateFlag.fromJson(Map<String, dynamic> j) => StateFlag(
        id: j['id'] as int,
        name: j['name'] as String,
        value: j['value'] as bool,
      );
}
