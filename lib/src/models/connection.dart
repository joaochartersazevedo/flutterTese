class Connection {
  const Connection({
    required this.id,
    required this.areaA,
    required this.areaB,
    required this.travelMinutes,
    this.locked = false,
  });

  final int id;
  final int areaA;
  final int areaB;
  final int travelMinutes;
  final bool locked;

  int destinationFor(int origin) {
    if (origin == areaA) {
      return areaB;
    }
    return areaA;
  }

  Connection copyWith({bool? locked, int? travelMinutes}) {
    return Connection(
      id: id,
      areaA: areaA,
      areaB: areaB,
      travelMinutes: travelMinutes ?? this.travelMinutes,
      locked: locked ?? this.locked,
    );
  }
}
