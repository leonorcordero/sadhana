class DiaryEntryModel {
  const DiaryEntryModel({
    required this.dateKey,
    required this.manualEntries,
    required this.extraTasks,
  });

  final String dateKey;
  final List<String> manualEntries;
  final List<String> extraTasks;

  DiaryEntryModel copyWith({
    String? dateKey,
    List<String>? manualEntries,
    List<String>? extraTasks,
  }) {
    return DiaryEntryModel(
      dateKey: dateKey ?? this.dateKey,
      manualEntries: manualEntries ?? this.manualEntries,
      extraTasks: extraTasks ?? this.extraTasks,
    );
  }

  Map<String, dynamic> toMap() => {
    'dateKey': dateKey,
    'manualEntries': manualEntries,
    'extraTasks': extraTasks,
  };

  factory DiaryEntryModel.fromMap(Map<String, dynamic> map) {
    return DiaryEntryModel(
      dateKey: map['dateKey'] as String,
      manualEntries: List<String>.from(map['manualEntries'] as List? ?? []),
      extraTasks: List<String>.from(map['extraTasks'] as List? ?? []),
    );
  }
}
