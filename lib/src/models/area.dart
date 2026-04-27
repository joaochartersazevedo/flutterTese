class Area {
  const Area({
    required this.id,
    required this.name,
    required this.backgroundPath,
    required this.connectionIds,
    this.locked = false,
  });

  final String id;
  final String name;
  final String backgroundPath;
  final List<String> connectionIds;
  final bool locked;

  Area copyWith({
    String? name,
    String? backgroundPath,
    List<String>? connectionIds,
    bool? locked,
  }) {
    return Area(
      id: id,
      name: name ?? this.name,
      backgroundPath: backgroundPath ?? this.backgroundPath,
      connectionIds: connectionIds ?? this.connectionIds,
      locked: locked ?? this.locked,
    );
  }
}
