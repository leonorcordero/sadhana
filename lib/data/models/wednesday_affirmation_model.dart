class WednesdayAffirmationModel {
  const WednesdayAffirmationModel({
    required this.meditationDateKey,
    required this.name,
    required this.contentType,
    required this.text,
    required this.imagePath,
    required this.updatedAt,
  });

  final String meditationDateKey; // yyyy-MM-dd
  final String? name;
  final String contentType; // text | image
  final String? text;
  final String? imagePath;
  final String updatedAt;

  WednesdayAffirmationModel copyWith({
    String? meditationDateKey,
    String? name,
    String? contentType,
    String? text,
    String? imagePath,
    String? updatedAt,
    bool clearName = false,
    bool clearText = false,
    bool clearImagePath = false,
  }) {
    return WednesdayAffirmationModel(
      meditationDateKey: meditationDateKey ?? this.meditationDateKey,
      name: clearName ? null : (name ?? this.name),
      contentType: contentType ?? this.contentType,
      text: clearText ? null : (text ?? this.text),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'meditationDateKey': meditationDateKey,
      'name': name,
      'contentType': contentType,
      'text': text,
      'imagePath': imagePath,
      'updatedAt': updatedAt,
    };
  }

  factory WednesdayAffirmationModel.fromMap(Map<String, dynamic> map) {
    final dateKey = (map['meditationDateKey'] as String? ?? '').trim();
    final name = (map['name'] as String?)?.trim();
    final contentType = (map['contentType'] as String? ?? 'text').trim();
    final text = (map['text'] as String?)?.trim();
    final imagePath = (map['imagePath'] as String?)?.trim();

    return WednesdayAffirmationModel(
      meditationDateKey: dateKey,
      name: (name == null || name.isEmpty) ? null : name,
      contentType: contentType == 'image' ? 'image' : 'text',
      text: (text == null || text.isEmpty) ? null : text,
      imagePath: (imagePath == null || imagePath.isEmpty) ? null : imagePath,
      updatedAt:
          (map['updatedAt'] as String? ?? DateTime.now().toIso8601String())
              .trim(),
    );
  }
}
