import 'package:hive_flutter/hive_flutter.dart';
import 'package:sadhana/core/constants/app_constants.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';

class LocalStorageDatasource {
  static const _schemaVersionKey = 'schema_version';
  static const _currentSchemaVersion = 2;
  static const _customEventsKey = 'custom_calendar_events';
  static const _externalEventsKey = 'external_calendar_events';
  static const _externalHiddenEventsKey = 'external_calendar_hidden_event_ids';
  static const _externalHiddenGroupsKey = 'external_calendar_hidden_groups';
  static const _externalHiddenTitlesKey = 'external_calendar_hidden_titles';
  static const _externalCalendarConfigKey = 'external_calendar_config';
  static const _diaryKey = 'diary_entries';
  static const _notesKey = 'notes';
  static const _mandalaResourcesKey = 'mandala_resources';
  static const _resourceFoldersKey = 'resource_folders';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(AppConstants.cyclesBox);
    await Hive.openBox<Map>(AppConstants.tasksBox);
    await Hive.openBox<Map>(AppConstants.dayLogsBox);
    await Hive.openBox(AppConstants.settingsBox);
    await _runMigrations();
  }

  Box<Map> get _cycleBox => Hive.box<Map>(AppConstants.cyclesBox);
  Box<Map> get _taskBox => Hive.box<Map>(AppConstants.tasksBox);
  Box<Map> get _dayLogBox => Hive.box<Map>(AppConstants.dayLogsBox);
  Box get _settingsBox => Hive.box(AppConstants.settingsBox);

  List<CycleModel> getCycles() {
    return _cycleBox.values.map(CycleModel.fromMap).toList();
  }

  Future<void> saveCycle(CycleModel cycle) async {
    await _cycleBox.put(cycle.id, cycle.toMap());
  }

  Future<void> deleteCycle(String cycleId) async {
    await _cycleBox.delete(cycleId);
  }

  List<TaskModel> getTasks() {
    return _taskBox.values.map(TaskModel.fromMap).toList();
  }

  Future<void> saveTask(TaskModel task) async {
    await _taskBox.put(task.id, task.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    await _taskBox.delete(taskId);
  }

  List<DayLogModel> getDayLogs() {
    return _dayLogBox.values.map(DayLogModel.fromMap).toList();
  }

  DayLogModel? getDayLog(String dayLogId) {
    final raw = _dayLogBox.get(dayLogId);
    if (raw == null) return null;
    return DayLogModel.fromMap(raw);
  }

  Future<void> saveDayLog(DayLogModel log) async {
    await _dayLogBox.put(log.id, log.toMap());
  }

  Future<void> deleteDayLog(String dayLogId) async {
    await _dayLogBox.delete(dayLogId);
  }

  dynamic getSetting(String key) => _settingsBox.get(key);

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  Future<void> deleteSetting(String key) async {
    await _settingsBox.delete(key);
  }

  List<Map<String, dynamic>> getCustomEventsRaw() {
    final list = _settingsBox.get(_customEventsKey) as List?;
    if (list == null) return [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveCustomEventsRaw(List<Map<String, dynamic>> items) async {
    await _settingsBox.put(_customEventsKey, items);
  }

  List<Map<String, dynamic>> getExternalEventsRaw() {
    final list = _settingsBox.get(_externalEventsKey) as List?;
    if (list == null) return [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveExternalEventsRaw(List<Map<String, dynamic>> items) async {
    await _settingsBox.put(_externalEventsKey, items);
  }

  Set<String> getExternalHiddenEventIds() {
    final list = _settingsBox.get(_externalHiddenEventsKey) as List?;
    if (list == null) return <String>{};
    return list.map((e) => e.toString()).toSet();
  }

  Future<void> saveExternalHiddenEventIds(Set<String> ids) async {
    await _settingsBox.put(
      _externalHiddenEventsKey,
      ids.toList(growable: false),
    );
  }

  Set<String> getExternalHiddenGroupKeys() {
    final list = _settingsBox.get(_externalHiddenGroupsKey) as List?;
    if (list == null) return <String>{};
    return list.map((e) => e.toString()).toSet();
  }

  Future<void> saveExternalHiddenGroupKeys(Set<String> keys) async {
    await _settingsBox.put(
      _externalHiddenGroupsKey,
      keys.toList(growable: false),
    );
  }

  Set<String> getExternalHiddenTitleKeys() {
    final list = _settingsBox.get(_externalHiddenTitlesKey) as List?;
    if (list == null) return <String>{};
    return list.map((e) => e.toString()).toSet();
  }

  Future<void> saveExternalHiddenTitleKeys(Set<String> keys) async {
    await _settingsBox.put(
      _externalHiddenTitlesKey,
      keys.toList(growable: false),
    );
  }

  Map<String, dynamic> getExternalCalendarConfig() {
    final raw = _settingsBox.get(_externalCalendarConfigKey);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  Future<void> saveExternalCalendarConfig(Map<String, dynamic> config) async {
    await _settingsBox.put(_externalCalendarConfigKey, config);
  }

  List<Map<String, dynamic>> getDiaryEntriesRaw() {
    final list = _settingsBox.get(_diaryKey) as List?;
    if (list == null) return [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveDiaryEntriesRaw(List<Map<String, dynamic>> items) async {
    await _settingsBox.put(_diaryKey, items);
  }

  List<Map<String, dynamic>> getNotesRaw() {
    final list = _settingsBox.get(_notesKey) as List?;
    if (list == null) return [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveNotesRaw(List<Map<String, dynamic>> items) async {
    await _settingsBox.put(_notesKey, items);
  }

  List<Map<String, dynamic>> getMandalaResourcesRaw() {
    final list = _settingsBox.get(_mandalaResourcesKey) as List?;
    if (list == null) return [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveMandalaResourcesRaw(List<Map<String, dynamic>> items) async {
    await _settingsBox.put(_mandalaResourcesKey, items);
  }

  Future<Map<String, dynamic>> exportAllAsJsonMap() async {
    return {
      'schemaVersion': _currentSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'cycles': _cycleBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      'tasks': _taskBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      'dayLogs': _dayLogBox.values
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      'settings': Map<String, dynamic>.from(_settingsBox.toMap()),
    };
  }

  Future<void> importAllFromJsonMap(Map<String, dynamic> payload) async {
    final cycles =
        (payload['cycles'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    final tasks =
        (payload['tasks'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    final dayLogs =
        (payload['dayLogs'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    final settings = Map<String, dynamic>.from(
      (payload['settings'] as Map?) ?? {},
    );

    await _cycleBox.clear();
    await _taskBox.clear();
    await _dayLogBox.clear();
    await _settingsBox.clear();

    for (final row in cycles) {
      final id = row['id'] as String?;
      if (id != null) {
        await _cycleBox.put(id, row);
      }
    }
    for (final row in tasks) {
      final id = row['id'] as String?;
      if (id != null) {
        await _taskBox.put(id, row);
      }
    }
    for (final row in dayLogs) {
      final id = row['id'] as String?;
      if (id != null) {
        await _dayLogBox.put(id, row);
      }
    }
    for (final entry in settings.entries) {
      await _settingsBox.put(entry.key, entry.value);
    }
    await _settingsBox.put(_schemaVersionKey, _currentSchemaVersion);
  }

  Future<void> _runMigrations() async {
    final current = (_settingsBox.get(_schemaVersionKey) as int?) ?? 0;
    if (current >= _currentSchemaVersion) return;

    if (current < 2) {
      final rawFolders = _settingsBox.get(_resourceFoldersKey);
      if (rawFolders is List) {
        final migrated = rawFolders
            .whereType<Map>()
            .map((entry) {
              final map = Map<String, dynamic>.from(entry);
              map.putIfAbsent('parentId', () => null);
              return map;
            })
            .toList(growable: false);
        await _settingsBox.put(_resourceFoldersKey, migrated);
      }
    }

    await _settingsBox.put(_schemaVersionKey, _currentSchemaVersion);
  }
}
