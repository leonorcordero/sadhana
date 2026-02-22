import 'package:uuid/uuid.dart';

class TaskModel {
  TaskModel({
    required this.id,
    required this.cycleId,
    required this.title,
    this.description,
    required this.isActive,
  });

  factory TaskModel.create({
    required String cycleId,
    required String title,
    String? description,
  }) {
    return TaskModel(
      id: const Uuid().v4(),
      cycleId: cycleId,
      title: title,
      description: description,
      isActive: true,
    );
  }

  final String id;
  final String cycleId;
  final String title;
  final String? description;
  final bool isActive;

  TaskModel copyWith({
    String? id,
    String? cycleId,
    String? title,
    String? description,
    bool? isActive,
  }) {
    return TaskModel(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      title: title ?? this.title,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycleId': cycleId,
      'title': title,
      'description': description,
      'isActive': isActive,
    };
  }

  factory TaskModel.fromMap(Map<dynamic, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      cycleId: map['cycleId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      isActive: map['isActive'] as bool,
    );
  }
}
