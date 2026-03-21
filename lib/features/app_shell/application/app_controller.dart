import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/services/daily_closure_service.dart';
import 'package:sadhana/core/services/google_drive_sync_service.dart';
import 'package:sadhana/core/services/notification_service.dart';
import 'package:sadhana/core/settings/app_settings.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:sadhana/features/app_shell/application/app_state.dart';

class AppController extends StateNotifier<AppState> {
  AppController(
    this._repository,
    this._dailyClosureService,
    this._notificationService,
    this._driveSyncService,
  ) : super(AppState.initial());

  final SadhanaRepository _repository;
  final DailyClosureService _dailyClosureService;
  final NotificationService _notificationService;
  final GoogleDriveSyncService _driveSyncService;
  bool _resourceBaselineEnsured = false;
  bool _remindersEnabled = true;
  List<int> _reminderHours = const [9, 14, 20];
  String _reminderContentType = AppSettings.defaultReminderContentType;
  String _customReminderText = AppSettings.defaultCustomReminderText;
  bool _driveSyncInFlight = false;

  Timer? _midnightTimer;
  Timer? _driveSyncTimer;

  Future<void> initialize({
    bool remindersEnabled = true,
    List<int> reminderHours = const [9, 14, 20],
    String reminderContentType = AppSettings.defaultReminderContentType,
    String customReminderText = AppSettings.defaultCustomReminderText,
    bool forceResourceBaseline = false,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    String? baselineError;
    if (forceResourceBaseline) {
      _resourceBaselineEnsured = false;
    }
    if (!_resourceBaselineEnsured) {
      try {
        await _repository.ensureResourceBaseline();
        _resourceBaselineEnsured = true;
      } catch (error, stackTrace) {
        final message = '$error';
        final isStorageNotReady = message.contains('Box not found');
        if (!isStorageNotReady) {
          debugPrint('Resource baseline failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          baselineError = 'No se pudo inicializar la biblioteca de recursos.';
        }
      }
    }
    _remindersEnabled = remindersEnabled;
    _reminderHours = List<int>.from(reminderHours);
    _reminderContentType = reminderContentType;
    _customReminderText = customReminderText;
    await _repository.closePendingDaysUntilYesterday();
    _loadState();
    if (baselineError != null) {
      state = state.copyWith(error: baselineError);
    }
    await _runDriveAutoSyncIfEnabled();
    _scheduleDriveSync();
    _scheduleDailyClosure();
    await _notificationService.scheduleDailyReminders(
      enabled: _remindersEnabled,
      hours: _reminderHours,
      contentType: _reminderContentType,
      customText: _customReminderText,
    );
    await _scheduleMandalaStartReminders();
  }

  void _loadState() {
    final cycles = _repository.getCycles();
    final collections = _repository.getStateCollectionsForCycles(cycles);

    state = state.copyWith(
      cycles: cycles,
      tasks: collections.tasks,
      logs: collections.logs,
      isLoading: false,
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
    int circle = 0,
    List<String> selectedSavedAudioIds = const [],
    List<String> selectedResourceFolderIds = const [],
    DateTime? plannedStartDate,
    bool createdFromTemplate = false,
    List<({String title, String? description, List<String> linkedResourceIds})>
        tasks =
        const [],
  }) async {
    try {
      final normalizedPlanned = plannedStartDate == null
          ? null
          : DateTime(
              plannedStartDate.year,
              plannedStartDate.month,
              plannedStartDate.day,
            );
      final cycle = CycleModel.create(
        name: name,
        duration: duration,
        customDuration: customDuration,
        sankalpa: sankalpa,
        archetype: archetype,
        circle: circle,
        linkedResourceFolderIds: selectedResourceFolderIds,
        plannedStartDateKey: normalizedPlanned == null
            ? null
            : DateUtilsX.dateKey(normalizedPlanned),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var cycleToCreate = cycle;
      var shouldStartNow = normalizedPlanned == null;
      if (normalizedPlanned != null &&
          !createdFromTemplate &&
          !normalizedPlanned.isAfter(today)) {
        final elapsed = today.difference(normalizedPlanned).inDays;
        final computedCurrentDay = (elapsed + 1).clamp(1, duration);
        cycleToCreate = cycle.copyWith(currentDay: computedCurrentDay);
        shouldStartNow = elapsed < duration;
      }
      await _repository.createCycle(cycleToCreate);
      if (shouldStartNow) {
        await _repository.startCycle(cycleToCreate.id);
      }
      for (final t in tasks) {
        await _repository.createTask(
          TaskModel.create(
            cycleId: cycleToCreate.id,
            title: t.title,
            description: t.description,
            linkedResourceIds: t.linkedResourceIds,
          ),
        );
      }
      if (selectedSavedAudioIds.isNotEmpty) {
        final ids = selectedSavedAudioIds.toSet();
        final sourceAudios = _repository
            .getMandalaResources()
            .where(
              (r) => r.type == MandalaResourceType.audio && ids.contains(r.id),
            )
            .toList(growable: false);
        for (final source in sourceAudios) {
          await _repository.saveMandalaResource(
            MandalaResourceModel.create(
              cycleId: cycleToCreate.id,
              folderId: cycleToCreate.id,
              title: source.title,
              type: MandalaResourceType.audio,
              filePath: source.filePath,
            ),
          );
        }
      }
      _loadState();
      await _scheduleMandalaStartReminders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateCycle(CycleModel cycle) async {
    try {
      await _repository.updateCycle(cycle);
      _loadState();
      await _scheduleMandalaStartReminders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteCycle(String cycleId) async {
    try {
      await _repository.deleteCycle(cycleId);
      _loadState();
      await _scheduleMandalaStartReminders();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> startCycle(String cycleId) async {
    await _repository.startCycle(cycleId);
    _loadState();
    await _scheduleMandalaStartReminders();
  }

  Future<void> stopCycle(String cycleId) async {
    await _repository.stopCycle(cycleId);
    _loadState();
    await _scheduleMandalaStartReminders();
  }

  Future<void> restartCycle(String cycleId) async {
    await _repository.restartCycle(cycleId);
    _loadState();
    await _scheduleMandalaStartReminders();
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

  Future<void> saveTaskOrderForCycle(
    String cycleId,
    List<String> orderedTaskIds,
  ) async {
    await _repository.saveTaskOrderForCycle(cycleId, orderedTaskIds);
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
    required String contentType,
    required String customText,
  }) async {
    _remindersEnabled = enabled;
    _reminderHours = List<int>.from(hours);
    _reminderContentType = contentType;
    _customReminderText = customText;
    await _notificationService.scheduleDailyReminders(
      enabled: _remindersEnabled,
      hours: _reminderHours,
      contentType: _reminderContentType,
      customText: _customReminderText,
    );
    await _scheduleMandalaStartReminders();
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
        contentType: _reminderContentType,
        customText: _customReminderText,
      );
      await _scheduleMandalaStartReminders();
      _scheduleDailyClosure();
    });
  }

  Future<void> _scheduleMandalaStartReminders() async {
    await _notificationService.scheduleMandalaStartReminders(
      cycles: _repository.getCycles(),
      enabled: _remindersEnabled,
    );
  }

  Future<void> _runDriveAutoSyncIfEnabled() async {
    if (_driveSyncInFlight) return;
    _driveSyncInFlight = true;
    try {
      final status = await _driveSyncService.getStatus();
      if (!status.enabled || status.folderId.trim().isEmpty) return;
      await _driveSyncService.syncNow();
      _loadState();
    } catch (_) {
      // Sync opcional: fallos no deben romper la app local.
    } finally {
      _driveSyncInFlight = false;
    }
  }

  void _scheduleDriveSync() {
    _driveSyncTimer?.cancel();
    _driveSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      await _runDriveAutoSyncIfEnabled();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _driveSyncTimer?.cancel();
    super.dispose();
  }
}
