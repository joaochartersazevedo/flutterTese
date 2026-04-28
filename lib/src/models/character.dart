class Character {
  const Character({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.portraitPath,
    required this.areaId,
    required this.bodyPath,
    this.personality = const <String, int>{},
    this.relationships = const <int, String>{},
  });

  final int id;
  final String name;
  final String colorHex;
  final String portraitPath;
  final int areaId;
  final String bodyPath;
  /// Big Five traits → 0 (low), 1 (neutral), 2 (high).
  /// Keys: extroverted, friendly, responsible, anxious, creative
  final Map<String, int> personality;
  /// charId → plain-English relationship description (e.g. "best friend", "rival")
  final Map<int, String> relationships;

  Character copyWith({
    String? name,
    String? colorHex,
    String? portraitPath,
    int? areaId,
    String? bodyPath,
    Map<String, int>? personality,
    Map<int, String>? relationships,
  }) {
    return Character(
      id: id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      portraitPath: portraitPath ?? this.portraitPath,
      areaId: areaId ?? this.areaId,
      bodyPath: bodyPath ?? this.bodyPath,
      personality: personality ?? this.personality,
      relationships: relationships ?? this.relationships,
    );
  }
}
