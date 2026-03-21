import 'package:uuid/uuid.dart';

class CalendarExternalEvent {
  CalendarExternalEvent({
    required this.id,
    required this.title,
    this.description,
    required this.dateKey,
    required this.sourceLabel,
  });

  factory CalendarExternalEvent.create({
    required String title,
    String? description,
    required String dateKey,
    String sourceLabel = 'Google Calendar',
  }) {
    return CalendarExternalEvent(
      id: const Uuid().v4(),
      title: title,
      description: description,
      dateKey: dateKey,
      sourceLabel: sourceLabel,
    );
  }

  final String id;
  final String title;
  final String? description;
  final String dateKey;
  final String sourceLabel;

  CalendarExternalEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? dateKey,
    String? sourceLabel,
  }) {
    return CalendarExternalEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateKey: dateKey ?? this.dateKey,
      sourceLabel: sourceLabel ?? this.sourceLabel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateKey': dateKey,
      'sourceLabel': sourceLabel,
    };
  }

  factory CalendarExternalEvent.fromMap(Map<dynamic, dynamic> map) {
    return CalendarExternalEvent(
      id: _readRequiredString(map, 'id'),
      title: _readRequiredString(map, 'title'),
      description: map['description'] as String?,
      dateKey: _readRequiredString(map, 'dateKey'),
      sourceLabel: (map['sourceLabel'] as String?)?.trim().isNotEmpty == true
          ? map['sourceLabel'] as String
          : 'Google Calendar',
    );
  }

  static String _readRequiredString(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      throw FormatException('CalendarExternalEvent.$key requerido');
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      throw FormatException('CalendarExternalEvent.$key vacío');
    }
    return text;
  }
}
