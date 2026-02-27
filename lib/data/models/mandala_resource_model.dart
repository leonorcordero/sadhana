import 'package:uuid/uuid.dart';

enum MandalaResourceType { audio, text, image, pdf, other }

class MandalaResourceModel {
  const MandalaResourceModel({
    required this.id,
    required this.cycleId,
    required this.folderId,
    required this.title,
    required this.type,
    required this.createdAt,
    this.filePath,
    this.inlineText,
  });

  final String id;
  final String cycleId;
  final String folderId;
  final String title;
  final MandalaResourceType type;
  final String createdAt; // ISO 8601
  final String? filePath;
  final String? inlineText;

  factory MandalaResourceModel.create({
    required String cycleId,
    required String folderId,
    required String title,
    required MandalaResourceType type,
    String? filePath,
    String? inlineText,
  }) {
    return MandalaResourceModel(
      id: const Uuid().v4(),
      cycleId: cycleId,
      folderId: folderId,
      title: title,
      type: type,
      createdAt: DateTime.now().toIso8601String(),
      filePath: filePath,
      inlineText: inlineText,
    );
  }

  MandalaResourceModel copyWith({
    String? id,
    String? cycleId,
    String? folderId,
    String? title,
    MandalaResourceType? type,
    String? createdAt,
    String? filePath,
    String? inlineText,
  }) {
    return MandalaResourceModel(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      filePath: filePath ?? this.filePath,
      inlineText: inlineText ?? this.inlineText,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycleId': cycleId,
      'folderId': folderId,
      'title': title,
      'type': type.name,
      'createdAt': createdAt,
      'filePath': filePath,
      'inlineText': inlineText,
    };
  }

  factory MandalaResourceModel.fromMap(Map<String, dynamic> map) {
    final typeRaw = (map['type'] as String? ?? 'other').toLowerCase();
    final type = MandalaResourceType.values.firstWhere(
      (t) => t.name == typeRaw,
      orElse: () => MandalaResourceType.other,
    );
    return MandalaResourceModel(
      id: map['id'] as String,
      cycleId: map['cycleId'] as String,
      folderId: map['folderId'] as String? ?? '',
      title: map['title'] as String? ?? 'Recurso',
      type: type,
      createdAt: map['createdAt'] as String? ?? '',
      filePath: map['filePath'] as String?,
      inlineText: map['inlineText'] as String?,
    );
  }
}
