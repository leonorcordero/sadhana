import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/services/daily_closure_service.dart';
import 'package:sadhana/core/services/notification_service.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:sadhana/features/app_shell/application/app_state.dart';

class AppController extends StateNotifier<AppState> {
  AppController(
    this._repository,
    this._dailyClosureService,
    this._notificationService,
  ) : super(AppState.initial());

  final SadhanaRepository _repository;
  final DailyClosureService _dailyClosureService;
  final NotificationService _notificationService;

  Timer? _midnightTimer;

  Future<void> initialize() async {
    await _repository.closePendingDaysUntilYesterday();
    _loadState();
    _scheduleDailyClosure();
    await _notificationService.scheduleDailyReminders();
  }

  void _loadState() {
    final cycles = _repository.getCycles();
    final tasks = <TaskModel>[];
    final logs = <DayLogModel>[];

    for (final cycle in cycles) {
      tasks.addAll(_repository.getTasksByCycle(cycle.id));
      logs.addAll(_repository.getLogsByCycle(cycle.id));
    }

    state = state.copyWith(
      cycles: cycles,
      tasks: tasks,
      logs: logs,
      clearError: true,
    );
  }

  void selectDate(DateTime date) {
    state = state.copyWith(
      selectedDate: DateTime(date.year, date.month, date.day),
    );
  }

  Future<void> createCycle({
    required String name,
    required int duration,
    required bool customDuration,
    required String sankalpa,
  }) async {
    try {
      final cycle = CycleModel.create(
        name: name,
        duration: duration,
        customDuration: customDuration,
        sankalpa: sankalpa,
      );
      await _repository.createCycle(cycle);
      _loadState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateCycle(CycleModel cycle) async {
    try {
      await _repository.updateCycle(cycle);
      _loadState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteCycle(String cycleId) async {
    try {
      await _repository.deleteCycle(cycleId);
      _loadState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> startCycle(String cycleId) async {
    await _repository.startCycle(cycleId);
    _loadState();
  }

  Future<void> stopCycle(String cycleId) async {
    await _repository.stopCycle(cycleId);
    _loadState();
  }

  Future<void> createTask({
    required String cycleId,
    required String title,
    String? description,
  }) async {
    try {
      await _repository.createTask(
        TaskModel.create(
          cycleId: cycleId,
          title: title,
          description: description,
        ),
      );
      _loadState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateTask(TaskModel task) async {
    await _repository.updateTask(task);
    _loadState();
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _repository.deleteTask(taskId);
      _loadState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleTaskForSelectedDate({
    required String taskId,
    required bool completed,
  }) async {
    final cycle = state.activeCycle;
    if (cycle == null) return;

    await _repository.toggleTaskCompleted(
      cycleId: cycle.id,
      taskId: taskId,
      date: state.selectedDate,
      completed: completed,
    );

    final isComplete = _repository.isDayComplete(
      cycleId: cycle.id,
      date: state.selectedDate,
    );

    if (isComplete) {
      await _notificationService.showCompletionNotification();
    }

    _loadState();
  }

  Future<void> closeDayNow() async {
    final cycle = state.activeCycle;
    if (cycle == null) return;

    await _repository.closeDay(cycleId: cycle.id, date: state.selectedDate);
    _loadState();
  }

  Future<void> closePendingDays() async {
    await _repository.closePendingDaysUntilYesterday();
    _loadState();
  }

  void _scheduleDailyClosure() {
    _midnightTimer?.cancel();
    final wait = _dailyClosureService.timeUntilNextClosure(DateTime.now());
    _midnightTimer = Timer(wait, () async {
      await closePendingDays();
      _scheduleDailyClosure();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }
}
