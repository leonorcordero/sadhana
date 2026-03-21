import 'package:uuid/uuid.dart';

class TaskModel {
  TaskModel({
    required this.id,
    required this.cycleId,
    required this.title,
    this.description,
    required this.isActive,
    this.linkedResourceIds = const <String>[],
  });

  factory TaskModel.create({
    required String cycleId,
    required String title,
    String? description,
    List<String> linkedResourceIds = const <String>[],
  }) {
    return TaskModel(
      id: const Uuid().v4(),
      cycleId: cycleId,
      title: title,
      description: description,
      isActive: true,
      linkedResourceIds: linkedResourceIds,
    );
  }

  final String id;
  final String cycleId;
  final String title;
  final String? description;
  final bool isActive;
  final List<String> linkedResourceIds;

  TaskModel copyWith({
    String? id,
    String? cycleId,
    String? title,
    String? description,
    bool? isActive,
    List<String>? linkedResourceIds,
  }) {
    return TaskModel(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      title: title ?? this.title,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      linkedResourceIds: linkedResourceIds ?? this.linkedResourceIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycleId': cycleId,
      'title': title,
      'description': description,
      'isActive': isActive,
      'linkedResourceIds': linkedResourceIds.toList(growable: false),
    };
  }

  factory TaskModel.fromMap(Map<dynamic, dynamic> map) {
    final rawLinked = map['linkedResourceIds'];
    final linked = rawLinked is List
        ? rawLinked
              .map((id) => id.toString().trim())
              .where((id) => id.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final rawIsActive = map['isActive'];
    final isActive = rawIsActive is bool
        ? rawIsActive
        : rawIsActive is num
        ? rawIsActive != 0
        : rawIsActive is String
        ? (rawIsActive.trim().toLowerCase() == 'true' ||
              rawIsActive.trim() == '1')
        : true;
    return TaskModel(
      id: _readRequiredString(map, 'id'),
      cycleId: _readRequiredString(map, 'cycleId'),
      title: _readRequiredString(map, 'title'),
      description: map['description'] as String?,
      isActive: isActive,
      linkedResourceIds: linked,
    );
  }

  static String _readRequiredString(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      throw FormatException('TaskModel.$key requerido');
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      throw FormatException('TaskModel.$key vacío');
    }
    return text;
  }
}
