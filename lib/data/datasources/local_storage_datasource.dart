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
    final cycles = _readRowsWithId(payload, key: 'cycles');
    final tasks = _readRowsWithId(payload, key: 'tasks');
    final dayLogs = _readRowsWithId(payload, key: 'dayLogs');
    final settings = _readSettingsMap(payload);
    _validateEntityRows(cycles, tasks, dayLogs);
    final backupCycles = _snapshotMapBox(_cycleBox);
    final backupTasks = _snapshotMapBox(_taskBox);
    final backupDayLogs = _snapshotMapBox(_dayLogBox);
    final backupSettings = Map<dynamic, dynamic>.from(_settingsBox.toMap());

    try {
      await _replaceAllData(
        cycles: cycles,
        tasks: tasks,
        dayLogs: dayLogs,
        settings: settings,
      );
    } catch (error) {
      await _restoreBackup(
        cycles: backupCycles,
        tasks: backupTasks,
        dayLogs: backupDayLogs,
        settings: backupSettings,
      );
      rethrow;
    }
  }

  void _validateEntityRows(
    List<Map<String, dynamic>> cycles,
    List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>> dayLogs,
  ) {
    try {
      for (final row in cycles) {
        CycleModel.fromMap(row);
      }
      for (final row in tasks) {
        TaskModel.fromMap(row);
      }
      for (final row in dayLogs) {
        DayLogModel.fromMap(row);
      }
    } catch (_) {
      throw const FormatException('Estructura de backup inválida');
    }
  }

  List<Map<String, dynamic>> _readRowsWithId(
    Map<String, dynamic> payload, {
    required String key,
  }) {
    final raw = payload[key];
    if (raw == null) return <Map<String, dynamic>>[];
    if (raw is! List) {
      throw FormatException('Campo "$key" inválido en backup');
    }
    final rows = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) {
        throw FormatException('Elemento inválido en "$key"');
      }
      final map = Map<String, dynamic>.from(item);
      final id = map['id'];
      if (id is! String || id.trim().isEmpty) {
        throw FormatException('Elemento sin id válido en "$key"');
      }
      rows.add(map);
    }
    return rows;
  }

  Map<String, dynamic> _readSettingsMap(Map<String, dynamic> payload) {
    final raw = payload['settings'];
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map) {
      throw const FormatException('Campo "settings" inválido en backup');
    }
    final out = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      out[key] = entry.value;
    }
    return out;
  }

  Map<String, Map<String, dynamic>> _snapshotMapBox(Box<Map> box) {
    final out = <String, Map<String, dynamic>>{};
    for (final entry in box.toMap().entries) {
      final key = entry.key.toString();
      out[key] = Map<String, dynamic>.from(entry.value);
    }
    return out;
  }

  Future<void> _replaceAllData({
    required List<Map<String, dynamic>> cycles,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> dayLogs,
    required Map<String, dynamic> settings,
  }) async {
    await _cycleBox.clear();
    await _taskBox.clear();
    await _dayLogBox.clear();
    await _settingsBox.clear();

    for (final row in cycles) {
      await _cycleBox.put(row['id'] as String, row);
    }
    for (final row in tasks) {
      await _taskBox.put(row['id'] as String, row);
    }
    for (final row in dayLogs) {
      await _dayLogBox.put(row['id'] as String, row);
    }
    for (final entry in settings.entries) {
      await _settingsBox.put(entry.key, entry.value);
    }
    await _settingsBox.put(_schemaVersionKey, _currentSchemaVersion);
  }

  Future<void> _restoreBackup({
    required Map<String, Map<String, dynamic>> cycles,
    required Map<String, Map<String, dynamic>> tasks,
    required Map<String, Map<String, dynamic>> dayLogs,
    required Map<dynamic, dynamic> settings,
  }) async {
    await _cycleBox.clear();
    await _taskBox.clear();
    await _dayLogBox.clear();
    await _settingsBox.clear();

    for (final entry in cycles.entries) {
      await _cycleBox.put(entry.key, entry.value);
    }
    for (final entry in tasks.entries) {
      await _taskBox.put(entry.key, entry.value);
    }
    for (final entry in dayLogs.entries) {
      await _dayLogBox.put(entry.key, entry.value);
    }
    for (final entry in settings.entries) {
      await _settingsBox.put(entry.key, entry.value);
    }
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
