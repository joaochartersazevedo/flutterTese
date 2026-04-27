class Task {
  const Task({
    required this.id,
    required this.name,
    required this.session,
    required this.section,
    required this.areaId,
    required this.singleTrigger,
    required this.preconditions,
    required this.consequences,
    this.active = false,
    this.completed = false,
  });

  final int id;
  final String name;
  final int session;
  final int section;
  final int areaId;
  final bool singleTrigger;
  final Map<int, bool> preconditions;
  final Map<int, bool> consequences;
  final bool active;
  final bool completed;

  Task copyWith({bool? active, bool? completed}) => Task(
        id: id,
        name: name,
        session: session,
        section: section,
        areaId: areaId,
        singleTrigger: singleTrigger,
        preconditions: preconditions,
        consequences: consequences,
        active: active ?? this.active,
        completed: completed ?? this.completed,
      );
}
