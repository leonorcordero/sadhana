import 'package:uuid/uuid.dart';

class MandalaTemplateTaskModel {
  const MandalaTemplateTaskModel({
    required this.title,
    this.description,
    this.linkedResourceIds = const <String>[],
  });

  final String title;
  final String? description;
  final List<String> linkedResourceIds;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'linkedResourceIds': linkedResourceIds.toList(growable: false),
    };
  }

  factory MandalaTemplateTaskModel.fromMap(Map<dynamic, dynamic> map) {
    final linkedRaw = map['linkedResourceIds'];
    final linked = linkedRaw is List
        ? linkedRaw
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return MandalaTemplateTaskModel(
      title: (map['title'] as String? ?? 'Tarea').trim(),
      description: (map['description'] as String?)?.trim(),
      linkedResourceIds: linked,
    );
  }
}

class MandalaTemplateModel {
  const MandalaTemplateModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.duration,
    required this.customDuration,
    required this.sankalpa,
    required this.tasks,
    required this.linkedResourceFolderIds,
    required this.createdAt,
    required this.updatedAt,
    this.archetype,
  });

  factory MandalaTemplateModel.create({
    required String name,
    required String kind,
    required int duration,
    required bool customDuration,
    required String sankalpa,
    required List<MandalaTemplateTaskModel> tasks,
    required List<String> linkedResourceFolderIds,
    String? archetype,
  }) {
    final now = DateTime.now().toIso8601String();
    return MandalaTemplateModel(
      id: const Uuid().v4(),
      name: name,
      kind: kind.trim().isEmpty ? 'mandala' : kind.trim(),
      duration: duration < 1 ? 21 : duration,
      customDuration: customDuration,
      sankalpa: sankalpa,
      tasks: tasks,
      linkedResourceFolderIds: linkedResourceFolderIds,
      archetype: archetype,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String name;
  final String kind;
  final int duration;
  final bool customDuration;
  final String sankalpa;
  final List<MandalaTemplateTaskModel> tasks;
  final List<String> linkedResourceFolderIds;
  final String? archetype;
  final String createdAt;
  final String updatedAt;

  MandalaTemplateModel copyWith({
    String? id,
    String? name,
    String? kind,
    int? duration,
    bool? customDuration,
    String? sankalpa,
    List<MandalaTemplateTaskModel>? tasks,
    List<String>? linkedResourceFolderIds,
    String? archetype,
    String? createdAt,
    String? updatedAt,
  }) {
    return MandalaTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      duration: duration ?? this.duration,
      customDuration: customDuration ?? this.customDuration,
      sankalpa: sankalpa ?? this.sankalpa,
      tasks: tasks ?? this.tasks,
      linkedResourceFolderIds:
          linkedResourceFolderIds ?? this.linkedResourceFolderIds,
      archetype: archetype ?? this.archetype,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'kind': kind,
      'duration': duration,
      'customDuration': customDuration,
      'sankalpa': sankalpa,
      'tasks': tasks.map((task) => task.toMap()).toList(growable: false),
      'linkedResourceFolderIds': linkedResourceFolderIds.toList(
        growable: false,
      ),
      'archetype': archetype,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory MandalaTemplateModel.fromMap(Map<dynamic, dynamic> map) {
    final rawTasks = map['tasks'];
    final tasks = rawTasks is List
        ? rawTasks
              .whereType<Map>()
              .map(MandalaTemplateTaskModel.fromMap)
              .where((task) => task.title.isNotEmpty)
              .toList(growable: false)
        : const <MandalaTemplateTaskModel>[];
    final rawFolders = map['linkedResourceFolderIds'];
    final linkedFolders = rawFolders is List
        ? rawFolders
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return MandalaTemplateModel(
      id: (map['id'] as String?)?.trim().isNotEmpty == true
          ? (map['id'] as String).trim()
          : const Uuid().v4(),
      name: ((map['name'] as String?) ?? 'Plantilla').trim(),
      kind: ((map['kind'] as String?) ?? 'mandala').trim(),
      duration: ((map['duration'] as int?) ?? 21).clamp(1, 1080),
      customDuration: (map['customDuration'] as bool?) ?? false,
      sankalpa: ((map['sankalpa'] as String?) ?? '').trim(),
      tasks: tasks,
      linkedResourceFolderIds: linkedFolders,
      archetype: (map['archetype'] as String?)?.trim(),
      createdAt:
          (map['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt:
          (map['updatedAt'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}
