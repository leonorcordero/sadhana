import 'package:flutter/foundation.dart';
import 'package:sadhana/core/constants/app_constants.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/dashboard_snapshot.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/features/streaks/application/streak_calculator.dart';

class SadhanaRepository {
  SadhanaRepository(this._datasource);

  final LocalStorageDatasource _datasource;
  static const _streakCalculator = StreakCalculator();

  List<CycleModel> getCycles() {
    final cycles = _datasource.getCycles();
    cycles.sort((a, b) => a.name.compareTo(b.name));
    return cycles;
  }

  Future<CycleModel> createCycle(CycleModel cycle) async {
    await _datasource.saveCycle(cycle);
    return cycle;
  }

  Future<CycleModel> updateCycle(CycleModel updated) async {
    final existing = _datasource.getCycles().firstWhere(
      (cycle) => cycle.id == updated.id,
    );

    if (existing.isActive && existing.sankalpa != updated.sankalpa) {
      throw StateError('No puedes editar el sankalpa de un ciclo activo.');
    }

    await _datasource.saveCycle(updated);
    return updated;
  }

  Future<void> deleteCycle(String cycleId) async {
    final activeCycle = getCycleById(cycleId);
    if (activeCycle != null && activeCycle.isActive) {
      throw StateError('No puedes eliminar un ciclo activo.');
    }

    final tasks = getTasksByCycle(cycleId);
    for (final task in tasks) {
      await _datasource.deleteTask(task.id);
    }
    await _datasource.deleteCycle(cycleId);
  }

  CycleModel? getActiveCycle() {
    final cycles = _datasource.getCycles();
    for (final cycle in cycles) {
      if (cycle.isActive) {
        return cycle;
      }
    }
    return null;
  }

  CycleModel? getCycleById(String id) {
    for (final cycle in _datasource.getCycles()) {
      if (cycle.id == id) return cycle;
    }
    return null;
  }

  Future<void> startCycle(String cycleId) async {
    final cycle = getCycleById(cycleId);
    if (cycle == null || cycle.isActive) return;
    await _datasource.saveCycle(cycle.copyWith(isActive: true));
  }

  Future<void> stopCycle(String cycleId) async {
    final cycle = getCycleById(cycleId);
    if (cycle == null) return;
    await _datasource.saveCycle(cycle.copyWith(isActive: false));
  }

  List<TaskModel> getTasksByCycle(String cycleId) {
    return _datasource
        .getTasks()
        .where((task) => task.cycleId == cycleId)
        .toList(growable: false);
  }

  Future<TaskModel> createTask(TaskModel task) async {
    await _datasource.saveTask(task);
    return task;
  }

  Future<TaskModel> updateTask(TaskModel task) async {
    await _datasource.saveTask(task);
    return task;
  }

  Future<void> deleteTask(String taskId) async {
    final task = _datasource.getTasks().firstWhere((t) => t.id == taskId);
    final cycle = getCycleById(task.cycleId);

    if (cycle != null && cycle.isActive) {
      throw StateError('No puedes eliminar tareas de un ciclo activo.');
    }

    await _datasource.deleteTask(taskId);
  }

  DayLogModel getOrCreateDayLog({
    required String cycleId,
    required DateTime date,
  }) {
    final key = _dayLogId(cycleId, date);
    final existing = _datasource.getDayLog(key);
    if (existing != null) return existing;

    final created = DayLogModel(
      id: key,
      cycleId: cycleId,
      date: DateUtilsX.dateKey(date),
      completedTaskIds: <String>[],
      closed: false,
      wasComplete: false,
    );
    _datasource.saveDayLog(created);
    return created;
  }

  Future<DayLogModel> toggleTaskCompleted({
    required String cycleId,
    required String taskId,
    required DateTime date,
    required bool completed,
  }) async {
    final log = getOrCreateDayLog(cycleId: cycleId, date: date);
    if (log.closed) return log;

    final ids = List<String>.from(log.completedTaskIds);
    if (completed) {
      if (!ids.contains(taskId)) ids.add(taskId);
    } else {
      ids.remove(taskId);
    }

    final updated = log.copyWith(completedTaskIds: ids);
    await _datasource.saveDayLog(updated);
    return updated;
  }

  bool isDayComplete({required String cycleId, required DateTime date}) {
    final tasks = getTasksByCycle(cycleId).where((t) => t.isActive).toList();
    if (tasks.isEmpty) return false;

    final log = getOrCreateDayLog(cycleId: cycleId, date: date);
    final completedCount = log.completedTaskIds
        .where((id) => tasks.any((task) => task.id == id))
        .length;
    return completedCount == tasks.length;
  }

  Future<void> closeDay({
    required String cycleId,
    required DateTime date,
  }) async {
    final cycle = getCycleById(cycleId);
    if (cycle == null) return;

    final complete = isDayComplete(cycleId: cycleId, date: date);
    final log = getOrCreateDayLog(cycleId: cycleId, date: date);
    final closedLog = log.copyWith(closed: true, wasComplete: complete);

    final streak = _streakCalculator.next(
      current: cycle.streakCurrent,
      max: cycle.streakMax,
      dayComplete: complete,
    );
    final streakCurrent = streak.current;
    final streakMax = streak.max;

    var nextDay = cycle.currentDay + 1;
    var active = cycle.isActive;
    if (nextDay > cycle.duration) {
      nextDay = cycle.duration;
      active = false;
    }

    final updatedCycle = cycle.copyWith(
      streakCurrent: streakCurrent,
      streakMax: streakMax,
      currentDay: nextDay,
      isActive: active,
    );

    await _datasource.saveDayLog(closedLog);
    await _datasource.saveCycle(updatedCycle);

    await _datasource.saveSetting(
      'last_closed_date_$cycleId',
      DateUtilsX.dateKey(date),
    );
  }

  Future<void> closePendingDaysUntilYesterday() async {
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));

    final activeCycles = _datasource
        .getCycles()
        .where((c) => c.isActive)
        .toList();
    for (final cycle in activeCycles) {
      final raw =
          _datasource.getSetting('last_closed_date_${cycle.id}') as String?;
      DateTime cursor;
      if (raw == null) {
        cursor = yesterday;
      } else {
        cursor = DateUtilsX.fromDateKey(raw).add(const Duration(days: 1));
      }

      while (!cursor.isAfter(yesterday)) {
        await closeDay(cycleId: cycle.id, date: cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
  }

  Future<void> closeTodayForActiveCycles() async {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    final activeCycles = _datasource
        .getCycles()
        .where((c) => c.isActive)
        .toList();
    for (final cycle in activeCycles) {
      await closeDay(cycleId: cycle.id, date: date);
    }
  }

  DashboardSnapshot getDashboardSnapshot({required DateTime date}) {
    final cycle = getActiveCycle();
    if (cycle == null) {
      return DashboardSnapshot(
        activeCycle: null,
        tasks: const [],
        todayLog: null,
        completionRatio: 0,
      );
    }
    return getDashboardSnapshotForCycle(cycleId: cycle.id, date: date);
  }

  DashboardSnapshot getDashboardSnapshotForCycle({
    required String cycleId,
    required DateTime date,
  }) {
    final cycle = getCycleById(cycleId);
    if (cycle == null) {
      return DashboardSnapshot(
        activeCycle: null,
        tasks: const [],
        todayLog: null,
        completionRatio: 0,
      );
    }

    final tasks = getTasksByCycle(cycle.id).where((t) => t.isActive).toList();
    final log = getOrCreateDayLog(cycleId: cycle.id, date: date);

    final done = log.completedTaskIds
        .where((id) => tasks.any((t) => t.id == id))
        .length;
    final ratio = tasks.isEmpty ? 0.0 : done / tasks.length;

    return DashboardSnapshot(
      activeCycle: cycle,
      tasks: tasks,
      todayLog: log,
      completionRatio: ratio,
    );
  }

  Map<DateTime, bool> getCalendarCompletionMap(String cycleId) {
    final map = <DateTime, bool>{};
    for (final log in _datasource.getDayLogs().where(
      (l) => l.cycleId == cycleId,
    )) {
      map[DateUtilsX.fromDateKey(log.date)] = log.wasComplete;
    }
    return map;
  }

  List<DayLogModel> getLogsByCycle(String cycleId) {
    return _datasource.getDayLogs().where((l) => l.cycleId == cycleId).toList();
  }

  String motivationalQuote({required bool dayComplete}) {
    final options = dayComplete
        ? AppConstants.rewardQuotes
        : AppConstants.reminderQuotes;

    final seed = DateUtilsX.dateKey(DateTime.now()).hashCode;
    return options[seed.abs() % options.length];
  }

  String _dayLogId(String cycleId, DateTime date) {
    return '${cycleId}_${DateUtilsX.dateKey(date)}';
  }
}

void debugLog(String message) {
  debugPrint('[SadhanaRepository] $message');
}
