import 'package:uuid/uuid.dart';

class CalendarCustomEvent {
  CalendarCustomEvent({
    required this.id,
    required this.title,
    this.description,
    required this.dateKey,
  });

  factory CalendarCustomEvent.create({
    required String title,
    String? description,
    required String dateKey,
  }) {
    return CalendarCustomEvent(
      id: const Uuid().v4(),
      title: title,
      description: description,
      dateKey: dateKey,
    );
  }

  final String id;
  final String title;
  final String? description;
  final String dateKey;

  CalendarCustomEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? dateKey,
  }) {
    return CalendarCustomEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateKey: dateKey ?? this.dateKey,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateKey': dateKey,
    };
  }

  factory CalendarCustomEvent.fromMap(Map<dynamic, dynamic> map) {
    return CalendarCustomEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      dateKey: map['dateKey'] as String,
    );
  }
}
