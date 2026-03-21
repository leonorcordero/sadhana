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
    this.linkedResourceFolderIds = const <String>[],
    this.plannedStartDateKey,
  });

  factory CycleModel.create({
    required String name,
    required int duration,
    required bool customDuration,
    required String sankalpa,
    String? archetype,
    int circle = 0,
    List<String> linkedResourceFolderIds = const <String>[],
    String? plannedStartDateKey,
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
      linkedResourceFolderIds: linkedResourceFolderIds,
      plannedStartDateKey: plannedStartDateKey,
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
  final List<String> linkedResourceFolderIds;
  final String? plannedStartDateKey; // yyyy-MM-dd

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
    List<String>? linkedResourceFolderIds,
    String? plannedStartDateKey,
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
      linkedResourceFolderIds:
          linkedResourceFolderIds ?? this.linkedResourceFolderIds,
      plannedStartDateKey: plannedStartDateKey ?? this.plannedStartDateKey,
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
      'linkedResourceFolderIds': linkedResourceFolderIds.toList(
        growable: false,
      ),
      'plannedStartDateKey': plannedStartDateKey,
    };
  }

  factory CycleModel.fromMap(Map<dynamic, dynamic> map) {
    final rawLinkedFolders = map['linkedResourceFolderIds'];
    final linkedFolders = rawLinkedFolders is List
        ? rawLinkedFolders
              .map((id) => id.toString().trim())
              .where((id) => id.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final plannedStartDateKey = (map['plannedStartDateKey'] as String?)?.trim();
    final rawCircle = map['circle'];
    final parsedCircle = rawCircle is int
        ? rawCircle
        : rawCircle is num
        ? rawCircle.toInt()
        : rawCircle is String
        ? int.tryParse(rawCircle.trim())
        : null;
    return CycleModel(
      id: _readRequiredString(map, 'id'),
      name: _readRequiredString(map, 'name'),
      duration: _readRequiredInt(map, 'duration'),
      customDuration: _readRequiredBool(map, 'customDuration'),
      startDay: _readRequiredInt(map, 'startDay'),
      currentDay: _readRequiredInt(map, 'currentDay'),
      sankalpa: _readRequiredString(map, 'sankalpa'),
      streakCurrent: _readRequiredInt(map, 'streakCurrent'),
      streakMax: _readRequiredInt(map, 'streakMax'),
      isActive: _readRequiredBool(map, 'isActive'),
      archetype: (map['archetype'] as String?)?.trim(),
      circle: (parsedCircle ?? 0).clamp(0, 7),
      linkedResourceFolderIds: linkedFolders,
      plannedStartDateKey: plannedStartDateKey?.isEmpty == true
          ? null
          : plannedStartDateKey,
    );
  }

  static String _readRequiredString(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      throw FormatException('CycleModel.$key requerido');
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      throw FormatException('CycleModel.$key vacío');
    }
    return text;
  }

  static int _readRequiredInt(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    throw FormatException('CycleModel.$key inválido');
  }

  static bool _readRequiredBool(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    throw FormatException('CycleModel.$key inválido');
  }
}
