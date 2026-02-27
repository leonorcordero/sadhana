import 'package:uuid/uuid.dart';

class ResourceFolderModel {
  const ResourceFolderModel({
    required this.id,
    required this.name,
    required this.circle,
    required this.createdAt,
    this.parentId,
  });

  final String id;
  final String name;
  final int circle; // 0..7 (0 = sin círculo)
  final String createdAt;
  final String? parentId;

  factory ResourceFolderModel.create({
    required String name,
    required int circle,
    String? parentId,
  }) {
    return ResourceFolderModel(
      id: const Uuid().v4(),
      name: name,
      circle: circle.clamp(0, 7),
      createdAt: DateTime.now().toIso8601String(),
      parentId: _normalizeParentId(parentId),
    );
  }

  ResourceFolderModel copyWith({
    String? id,
    String? name,
    int? circle,
    String? createdAt,
    String? parentId,
    bool clearParentId = false,
  }) {
    return ResourceFolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      circle: (circle ?? this.circle).clamp(0, 7),
      createdAt: createdAt ?? this.createdAt,
      parentId: clearParentId
          ? null
          : _normalizeParentId(parentId ?? this.parentId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'circle': circle,
      'createdAt': createdAt,
      'parentId': parentId,
    };
  }

  factory ResourceFolderModel.fromMap(Map<String, dynamic> map) {
    return ResourceFolderModel(
      id: map['id'] as String,
      name: (map['name'] as String? ?? 'Carpeta').trim(),
      circle: ((map['circle'] as int?) ?? 0).clamp(0, 7),
      createdAt: map['createdAt'] as String? ?? '',
      parentId: _normalizeParentId(map['parentId'] as String?),
    );
  }

  static String? _normalizeParentId(String? parentId) {
    final normalized = parentId?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }
}
