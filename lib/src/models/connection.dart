import 'dart:ui';

class Connection {
  const Connection({
    required this.id,
    required this.areaA,
    required this.areaB,
    required this.travelMinutes,
    this.locked = false,
    this.label = '',
    this.hotspotAx,
    this.hotspotAy,
    this.hotspotBx,
    this.hotspotBy,
  });

  final int id;
  final int areaA;
  final int areaB;
  final int travelMinutes;
  final bool locked;

  /// Label shown on the in-game hotspot (e.g. "Stairs", "Exit").
  final String label;

  /// Normalized hotspot position on areaA's background (0.0–1.0).
  final double? hotspotAx;
  final double? hotspotAy;

  /// Normalized hotspot position on areaB's background (0.0–1.0).
  final double? hotspotBx;
  final double? hotspotBy;

  bool get hasHotspotA => hotspotAx != null && hotspotAy != null;
  bool get hasHotspotB => hotspotBx != null && hotspotBy != null;

  /// Returns the normalized hotspot offset for [areaId], or null if not placed.
  Offset? hotspotForArea(int areaId) {
    if (areaId == areaA && hasHotspotA) return Offset(hotspotAx!, hotspotAy!);
    if (areaId == areaB && hasHotspotB) return Offset(hotspotBx!, hotspotBy!);
    return null;
  }

  int destinationFor(int origin) => origin == areaA ? areaB : areaA;

  Connection copyWith({
    int? travelMinutes,
    bool? locked,
    String? label,
    double? hotspotAx,
    double? hotspotAy,
    double? hotspotBx,
    double? hotspotBy,
    bool clearHotspotA = false,
    bool clearHotspotB = false,
  }) {
    return Connection(
      id: id,
      areaA: areaA,
      areaB: areaB,
      travelMinutes: travelMinutes ?? this.travelMinutes,
      locked: locked ?? this.locked,
      label: label ?? this.label,
      hotspotAx: clearHotspotA ? null : (hotspotAx ?? this.hotspotAx),
      hotspotAy: clearHotspotA ? null : (hotspotAy ?? this.hotspotAy),
      hotspotBx: clearHotspotB ? null : (hotspotBx ?? this.hotspotBx),
      hotspotBy: clearHotspotB ? null : (hotspotBy ?? this.hotspotBy),
    );
  }
}
