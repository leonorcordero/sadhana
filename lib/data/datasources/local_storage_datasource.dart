import 'package:hive_flutter/hive_flutter.dart';
import 'package:sadhana/core/constants/app_constants.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';

class LocalStorageDatasource {
  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(AppConstants.cyclesBox);
    await Hive.openBox<Map>(AppConstants.tasksBox);
    await Hive.openBox<Map>(AppConstants.dayLogsBox);
    await Hive.openBox(AppConstants.settingsBox);
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

  dynamic getSetting(String key) => _settingsBox.get(key);

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }
}
