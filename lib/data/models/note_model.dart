class NoteModel {
  const NoteModel({
    required this.id,
    required this.content,
    required this.createdAt,
    this.title,
  });

  final String id;
  final String? title;
  final String content;
  final String createdAt; // ISO 8601

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? createdAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt,
  };

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      title: map['title'] as String?,
      content: map['content'] as String? ?? '',
      createdAt: map['createdAt'] as String? ?? '',
    );
  }

  factory NoteModel.create({String? title, required String content}) {
    return NoteModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: (title == null || title.trim().isEmpty) ? null : title.trim(),
      content: content,
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}
