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
}
