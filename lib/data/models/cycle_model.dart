import 'package:uuid/uuid.dart';

class CycleModel {
  CycleModel({
    required this.id,
    required this.name,
    required this.duration,
    required this.customDuration,
    required this.startDay,
    required this.currentDay,
    required this.sankalpa,
    required this.streakCurrent,
    required this.streakMax,
    required this.isActive,
    this.archetype,
    this.circle = 0,
  });

  factory CycleModel.create({
    required String name,
    required int duration,
    required bool customDuration,
    required String sankalpa,
    String? archetype,
    int circle = 0,
  }) {
    if (duration < 1) {
      throw ArgumentError.value(duration, 'duration', 'Debe ser mayor a 0');
    }
    return CycleModel(
      id: const Uuid().v4(),
      name: name,
      duration: duration,
      customDuration: customDuration,
      startDay: 1,
      currentDay: 1,
      sankalpa: sankalpa,
      streakCurrent: 0,
      streakMax: 0,
      isActive: false,
      archetype: archetype,
      circle: circle.clamp(0, 7),
    );
  }

  final String id;
  final String name;
  final int duration;
  final bool customDuration;
  final int startDay;
  final int currentDay;
  final String sankalpa;
  final int streakCurrent;
  final int streakMax;
  final bool isActive;

  /// Clave del arquetipo mandala (nullable para compatibilidad con datos existentes).
  final String? archetype;
  final int circle; // 0..7 (0 = sin círculo)

  double get progress =>
      duration == 0 ? 0 : (currentDay / duration).clamp(0, 1);

  CycleModel copyWith({
    String? id,
    String? name,
    int? duration,
    bool? customDuration,
    int? startDay,
    int? currentDay,
    String? sankalpa,
    int? streakCurrent,
    int? streakMax,
    bool? isActive,
    String? archetype,
    int? circle,
  }) {
    return CycleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      duration: duration ?? this.duration,
      customDuration: customDuration ?? this.customDuration,
      startDay: startDay ?? this.startDay,
      currentDay: currentDay ?? this.currentDay,
      sankalpa: sankalpa ?? this.sankalpa,
      streakCurrent: streakCurrent ?? this.streakCurrent,
      streakMax: streakMax ?? this.streakMax,
      isActive: isActive ?? this.isActive,
      archetype: archetype ?? this.archetype,
      circle: (circle ?? this.circle).clamp(0, 7),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'duration': duration,
      'customDuration': customDuration,
      'startDay': startDay,
      'currentDay': currentDay,
      'sankalpa': sankalpa,
      'streakCurrent': streakCurrent,
      'streakMax': streakMax,
      'isActive': isActive,
      'archetype': archetype,
      'circle': circle,
    };
  }

  factory CycleModel.fromMap(Map<dynamic, dynamic> map) {
    return CycleModel(
      id: map['id'] as String,
      name: map['name'] as String,
      duration: map['duration'] as int,
      customDuration: map['customDuration'] as bool,
      startDay: map['startDay'] as int,
      currentDay: map['currentDay'] as int,
      sankalpa: map['sankalpa'] as String,
      streakCurrent: map['streakCurrent'] as int,
      streakMax: map['streakMax'] as int,
      isActive: map['isActive'] as bool,
      archetype: map['archetype'] as String?,
      circle: ((map['circle'] as int?) ?? 0).clamp(0, 7),
    );
  }
}
