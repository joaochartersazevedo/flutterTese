class Character {
  const Character({
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

  Character copyWith({
    String? name,
    String? colorHex,
    String? portraitPath,
    int? areaId,
    String? bodyPath,
  }) {
    return Character(
      id: id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      portraitPath: portraitPath ?? this.portraitPath,
      areaId: areaId ?? this.areaId,
      bodyPath: bodyPath ?? this.bodyPath,
    );
  }
}
