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
  bool _remindersEnabled = true;
  List<int> _reminderHours = const [9, 14, 20];

  Timer? _midnightTimer;

  Future<void> initialize({
    bool remindersEnabled = true,
    List<int> reminderHours = const [9, 14, 20],
  }) async {
    _remindersEnabled = remindersEnabled;
    _reminderHours = List<int>.from(reminderHours);
    await _repository.closePendingDaysUntilYesterday();
    _loadState();
    _scheduleDailyClosure();
    await _notificationService.scheduleDailyReminders(
      enabled: _remindersEnabled,
      hours: _reminderHours,
    );
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
    String? archetype,
    List<({String title, String? description})> tasks = const [],
  }) async {
    try {
      final cycle = CycleModel.create(
        name: name,
        duration: duration,
        customDuration: customDuration,
        sankalpa: sankalpa,
        archetype: archetype,
      );
      await _repository.createCycle(cycle);
      await _repository.startCycle(cycle.id);
      for (final t in tasks) {
        await _repository.createTask(
          TaskModel.create(
            cycleId: cycle.id,
            title: t.title,
            description: t.description,
          ),
        );
      }
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

  Future<void> restartCycle(String cycleId) async {
    await _repository.restartCycle(cycleId);
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
    final task = state.tasks.firstWhere((t) => t.id == taskId);

    await _repository.toggleTaskCompleted(
      cycleId: task.cycleId,
      taskId: taskId,
      date: state.selectedDate,
      completed: completed,
    );

    final isComplete = _repository.isDayComplete(
      cycleId: task.cycleId,
      date: state.selectedDate,
    );

    if (isComplete) {
      await _notificationService.showCompletionNotification();

      // Si todos los ciclos activos completaron el dia, cancela recordatorios.
      final allDone = state.activeCycles.every(
        (c) =>
            _repository.isDayComplete(cycleId: c.id, date: state.selectedDate),
      );
      if (allDone) {
        await _notificationService.cancelDailyReminders();

        // Auto-cierre: solo si la fecha seleccionada es hoy.
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final selected = state.selectedDate;
        final isToday =
            selected.year == today.year &&
            selected.month == today.month &&
            selected.day == today.day;
        if (isToday) {
          await _repository.closeTodayForActiveCycles();
        }
      }
    }

    _loadState();
  }

  Future<void> closeDayNow() async {
    await _repository.closeTodayForActiveCycles();
    _loadState();
  }

  Future<void> closePendingDays() async {
    await _repository.closePendingDaysUntilYesterday();
    _loadState();
  }

  Future<void> closeTodayForActiveCycles() async {
    await _repository.closeTodayForActiveCycles();
    _loadState();
  }

  Future<void> reconfigureNotifications({
    required bool enabled,
    required List<int> hours,
  }) async {
    _remindersEnabled = enabled;
    _reminderHours = List<int>.from(hours);
    await _notificationService.scheduleDailyReminders(
      enabled: _remindersEnabled,
      hours: _reminderHours,
    );
  }

  void _scheduleDailyClosure() {
    _midnightTimer?.cancel();
    final wait = _dailyClosureService.timeUntilNextClosure(DateTime.now());
    _midnightTimer = Timer(wait, () async {
      await closeTodayForActiveCycles();
      // Re-agenda recordatorios para el nuevo dia.
      await _notificationService.scheduleDailyReminders(
        enabled: _remindersEnabled,
        hours: _reminderHours,
      );
      _scheduleDailyClosure();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }
}
