import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/services/daily_closure_service.dart';
import 'package:sadhana/core/services/notification_service.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:sadhana/features/diary/presentation/diary_page.dart';

class _InMemoryDatasource extends LocalStorageDatasource {
  final Map<String, CycleModel> _cycles = {};
  final Map<String, TaskModel> _tasks = {};
  final Map<String, DayLogModel> _logs = {};
  final Map<String, dynamic> _settings = {};
  final List<Map<String, dynamic>> _diaryEntries = [];

  @override
  Future<void> init() async {}

  @override
  List<CycleModel> getCycles() => _cycles.values.toList();

  @override
  Future<void> saveCycle(CycleModel cycle) async => _cycles[cycle.id] = cycle;

  @override
  Future<void> deleteCycle(String cycleId) async => _cycles.remove(cycleId);

  @override
  List<TaskModel> getTasks() => _tasks.values.toList();

  @override
  Future<void> saveTask(TaskModel task) async => _tasks[task.id] = task;

  @override
  Future<void> deleteTask(String taskId) async => _tasks.remove(taskId);

  @override
  List<DayLogModel> getDayLogs() => _logs.values.toList();

  @override
  DayLogModel? getDayLog(String dayLogId) => _logs[dayLogId];

  @override
  Future<void> saveDayLog(DayLogModel log) async => _logs[log.id] = log;

  @override
  Future<void> deleteDayLog(String dayLogId) async => _logs.remove(dayLogId);

  @override
  dynamic getSetting(String key) => _settings[key];

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    _settings[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async => _settings.remove(key);

  @override
  List<Map<String, dynamic>> getCustomEventsRaw() => const [];

  @override
  Future<void> saveCustomEventsRaw(List<Map<String, dynamic>> items) async {}

  @override
  List<Map<String, dynamic>> getDiaryEntriesRaw() =>
      List.unmodifiable(_diaryEntries);

  @override
  Future<void> saveDiaryEntriesRaw(List<Map<String, dynamic>> items) async {
    _diaryEntries
      ..clear()
      ..addAll(items);
  }

  @override
  List<Map<String, dynamic>> getNotesRaw() => const [];

  @override
  Future<void> saveNotesRaw(List<Map<String, dynamic>> items) async {}
}

class _SilentNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleDailyReminders({
    List<int> hours = const [9, 14, 20],
    bool enabled = true,
    String contentType = 'focus',
    String customText = '',
  }) async {}

  @override
  Future<void> showCompletionNotification() async {}
}

void main() {
  testWidgets('diary page muestra historial y no muestra notas libres', (
    tester,
  ) async {
    final datasource = _InMemoryDatasource();
    final repository = SadhanaRepository(datasource);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageDatasourceProvider.overrideWithValue(datasource),
          repositoryProvider.overrideWithValue(repository),
          notificationServiceProvider.overrideWithValue(
            _SilentNotificationService(),
          ),
          dailyClosureServiceProvider.overrideWithValue(DailyClosureService()),
        ],
        child: const MaterialApp(home: DiaryPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('HISTORIAL DE PRÁCTICA'), findsOneWidget);
    expect(find.text('NOTAS LIBRES'), findsNothing);
  });
}
