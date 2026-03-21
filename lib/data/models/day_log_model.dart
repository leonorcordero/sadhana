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
    final rawCompleted = map['completedTaskIds'];
    final completedTaskIds = rawCompleted is List
        ? rawCompleted
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return DayLogModel(
      id: _readRequiredString(map, 'id'),
      cycleId: _readRequiredString(map, 'cycleId'),
      date: _readRequiredString(map, 'date'),
      completedTaskIds: completedTaskIds,
      closed: _readBool(map['closed'], fallback: false),
      wasComplete: _readBool(map['wasComplete'], fallback: false),
    );
  }

  static String _readRequiredString(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      throw FormatException('DayLogModel.$key requerido');
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      throw FormatException('DayLogModel.$key vacío');
    }
    return text;
  }

  static bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }
}
