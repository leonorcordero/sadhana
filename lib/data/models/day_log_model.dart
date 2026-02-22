class DayLogModel {
  DayLogModel({
    required this.id,
    required this.cycleId,
    required this.date,
    required this.completedTaskIds,
    required this.closed,
    required this.wasComplete,
  });

  final String id;
  final String cycleId;
  final String date;
  final List<String> completedTaskIds;
  final bool closed;
  final bool wasComplete;

  DayLogModel copyWith({
    String? id,
    String? cycleId,
    String? date,
    List<String>? completedTaskIds,
    bool? closed,
    bool? wasComplete,
  }) {
    return DayLogModel(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      date: date ?? this.date,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
      closed: closed ?? this.closed,
      wasComplete: wasComplete ?? this.wasComplete,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycleId': cycleId,
      'date': date,
      'completedTaskIds': completedTaskIds,
      'closed': closed,
      'wasComplete': wasComplete,
    };
  }

  factory DayLogModel.fromMap(Map<dynamic, dynamic> map) {
    return DayLogModel(
      id: map['id'] as String,
      cycleId: map['cycleId'] as String,
      date: map['date'] as String,
      completedTaskIds: List<String>.from(map['completedTaskIds'] as List),
      closed: map['closed'] as bool,
      wasComplete: map['wasComplete'] as bool,
    );
  }
}
