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
import 'package:sadhana/features/dashboard/presentation/dashboard_page.dart';

class InMemoryDatasource extends LocalStorageDatasource {
  final Map<String, CycleModel> _cycles = {};
  final Map<String, TaskModel> _tasks = {};
  final Map<String, DayLogModel> _logs = {};
  final Map<String, dynamic> _settings = {};

  @override
  Future<void> init() async {}

  @override
  List<CycleModel> getCycles() => _cycles.values.toList();

  @override
  Future<void> saveCycle(CycleModel cycle) async {
    _cycles[cycle.id] = cycle;
  }

  @override
  Future<void> deleteCycle(String cycleId) async {
    _cycles.remove(cycleId);
  }

  @override
  List<TaskModel> getTasks() => _tasks.values.toList();

  @override
  Future<void> saveTask(TaskModel task) async {
    _tasks[task.id] = task;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.remove(taskId);
  }

  @override
  List<DayLogModel> getDayLogs() => _logs.values.toList();

  @override
  DayLogModel? getDayLog(String dayLogId) => _logs[dayLogId];

  @override
  Future<void> saveDayLog(DayLogModel log) async {
    _logs[log.id] = log;
  }

  @override
  dynamic getSetting(String key) => _settings[key];

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    _settings[key] = value;
  }

  @override
  List<Map<String, dynamic>> getCustomEventsRaw() => const [];

  @override
  Future<void> saveCustomEventsRaw(List<Map<String, dynamic>> items) async {}
}

class SilentNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleDailyReminders({
    List<int> hours = const [9, 14, 20],
    bool enabled = true,
  }) async {}

  @override
  Future<void> showCompletionNotification() async {}
}

void main() {
  testWidgets('dashboard muestra sankalpa cuando hay ciclo activo', (
    tester,
  ) async {
    final datasource = InMemoryDatasource();
    final repository = SadhanaRepository(datasource);

    final cycle = CycleModel(
      id: 'c1',
      name: 'Ciclo 40',
      duration: 40,
      customDuration: false,
      startDay: 1,
      currentDay: 5,
      sankalpa: 'Servir con presencia',
      streakCurrent: 3,
      streakMax: 6,
      isActive: true,
    );
    await repository.createCycle(cycle);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageDatasourceProvider.overrideWithValue(datasource),
          repositoryProvider.overrideWithValue(repository),
          notificationServiceProvider.overrideWithValue(
            SilentNotificationService(),
          ),
          dailyClosureServiceProvider.overrideWithValue(DailyClosureService()),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );
    final controller = container.read(appControllerProvider.notifier);
    controller.initialize();

    await tester.pump();

    expect(find.text('Ciclo 40'), findsOneWidget);
    expect(find.textContaining('Servir con presencia'), findsOneWidget);
  });
}
