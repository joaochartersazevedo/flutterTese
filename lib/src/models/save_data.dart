import 'package:intl/intl.dart';

class SaveData {
  const SaveData({
    required this.saveName,
    required this.timestamp,
    required this.currentAreaId,
    required this.elapsedMinutes,
    required this.minutesSincePopulate,
    required this.log,
    required this.gameFlags,
    required this.characterPositions,
  });

  final String saveName;
  final DateTime timestamp;
  final int currentAreaId;
  final int elapsedMinutes;
  final int minutesSincePopulate;
  final List<String> log;
  final Map<int, bool> gameFlags; // StateFlag id → value
  final Map<int, int> characterPositions; // Character id → Area id

  String get displayName => saveName;
  String get displayTime =>
      DateFormat('dd/MM/yyyy HH:mm').format(timestamp);

  Map<String, dynamic> toJson() => {
    'saveName': saveName,
    'timestamp': timestamp.toIso8601String(),
    'currentAreaId': currentAreaId,
    'elapsedMinutes': elapsedMinutes,
    'minutesSincePopulate': minutesSincePopulate,
    'log': log,
    'gameFlags': {for (var e in gameFlags.entries) e.key.toString(): e.value},
    'characterPositions': {for (var e in characterPositions.entries) e.key.toString(): e.value},
  };

  factory SaveData.fromJson(Map<String, dynamic> json) => SaveData(
    saveName: json['saveName'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    currentAreaId: json['currentAreaId'] as int,
    elapsedMinutes: json['elapsedMinutes'] as int,
    minutesSincePopulate: json['minutesSincePopulate'] as int,
    log: List<String>.from(json['log'] as List<dynamic>),
    gameFlags: Map<int, bool>.from(
      (json['gameFlags'] as Map<dynamic, dynamic>).map(
        (k, v) => MapEntry(int.parse(k.toString()), v as bool),
      ),
    ),
    characterPositions: Map<int, int>.from(
      (json['characterPositions'] as Map<dynamic, dynamic>).map(
        (k, v) => MapEntry(int.parse(k.toString()), v as int),
      ),
    ),
  );
}
