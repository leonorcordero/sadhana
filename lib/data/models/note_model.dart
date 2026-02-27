class NoteModel {
  const NoteModel({
    required this.id,
    required this.content,
    required this.createdAt,
    this.title,
    this.tags = const [],
    this.isPinned = false,
  });

  final String id;
  final String? title;
  final String content;
  final String createdAt; // ISO 8601
  final List<String> tags;
  final bool isPinned;

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? createdAt,
    List<String>? tags,
    bool? isPinned,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt,
    'tags': tags,
    'isPinned': isPinned,
  };

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      title: map['title'] as String?,
      content: map['content'] as String? ?? '',
      createdAt: map['createdAt'] as String? ?? '',
      tags: ((map['tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false),
      isPinned: map['isPinned'] == true,
    );
  }

  factory NoteModel.create({
    String? title,
    required String content,
    List<String> tags = const [],
  }) {
    return NoteModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: (title == null || title.trim().isEmpty) ? null : title.trim(),
      content: content,
      createdAt: DateTime.now().toIso8601String(),
      tags: tags,
    );
  }
}
