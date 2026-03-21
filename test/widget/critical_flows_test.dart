import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/services/daily_closure_service.dart';
import 'package:sadhana/core/services/notification_service.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:sadhana/features/cycles/presentation/cycles_page.dart';
import 'package:sadhana/features/resources/presentation/resources_library_page.dart';

class _InMemoryDatasource extends LocalStorageDatasource {
  final _cycles = <String, CycleModel>{};
  final _tasks = <String, TaskModel>{};
  final _logs = <String, DayLogModel>{};
  final _settings = <String, dynamic>{};
  List<Map<String, dynamic>> _resources = <Map<String, dynamic>>[];

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
  List<Map<String, dynamic>> getMandalaResourcesRaw() => _resources;

  @override
  Future<void> saveMandalaResourcesRaw(List<Map<String, dynamic>> items) async {
    _resources = List<Map<String, dynamic>>.from(items);
  }

  @override
  List<Map<String, dynamic>> getCustomEventsRaw() => const [];

  @override
  Future<void> saveCustomEventsRaw(List<Map<String, dynamic>> items) async {}

  @override
  List<Map<String, dynamic>> getDiaryEntriesRaw() => const [];

  @override
  Future<void> saveDiaryEntriesRaw(List<Map<String, dynamic>> items) async {}

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
  Future<void> scheduleMandalaStartReminders({
    required List<CycleModel> cycles,
    required bool enabled,
  }) async {}

  @override
  Future<void> showCompletionNotification() async {}
}

Widget _wrapWithProviders({
  required _InMemoryDatasource datasource,
  required SadhanaRepository repository,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      localStorageDatasourceProvider.overrideWithValue(datasource),
      repositoryProvider.overrideWithValue(repository),
      notificationServiceProvider.overrideWithValue(
        _SilentNotificationService(),
      ),
      dailyClosureServiceProvider.overrideWithValue(DailyClosureService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('crear mandala programado lo deja inactivo', (tester) async {
    final datasource = _InMemoryDatasource();
    final repository = SadhanaRepository(datasource);
    await tester.pumpWidget(
      _wrapWithProviders(
        datasource: datasource,
        repository: repository,
        child: const CyclesPage(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CyclesPage)),
    );
    await container
        .read(appControllerProvider.notifier)
        .createCycle(
          name: 'Mandala Programado',
          duration: 21,
          customDuration: false,
          sankalpa: 'Preparado',
          plannedStartDate: DateTime.now().add(const Duration(days: 1)),
        );
    await tester.pumpAndSettle();

    expect(find.textContaining('Programado para iniciar el'), findsOneWidget);
  });

  testWidgets('ordenar tareas refleja el nuevo orden', (tester) async {
    final datasource = _InMemoryDatasource();
    final repository = SadhanaRepository(datasource);
    await tester.pumpWidget(
      _wrapWithProviders(
        datasource: datasource,
        repository: repository,
        child: const CyclesPage(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CyclesPage)),
    );
    final controller = container.read(appControllerProvider.notifier);
    await controller.createCycle(
      name: 'Mandala Orden',
      duration: 21,
      customDuration: false,
      sankalpa: 'Orden',
      tasks: const [
        (title: 'Meditación', description: null, linkedResourceIds: <String>[]),
        (title: 'Japa', description: null, linkedResourceIds: <String>[]),
        (title: 'Kriyas', description: null, linkedResourceIds: <String>[]),
      ],
    );
    final cycle = container.read(appControllerProvider).cycles.first;
    final tasks = repository.getTasksByCycle(cycle.id);
    await controller.saveTaskOrderForCycle(cycle.id, [
      tasks[1].id,
      tasks[2].id,
      tasks[0].id,
    ]);
    await tester.pumpAndSettle();

    expect(repository.getTasksByCycle(cycle.id).first.title, 'Japa');
  });

  testWidgets('editar recursos por tarea deja vínculo guardado', (
    tester,
  ) async {
    final datasource = _InMemoryDatasource();
    final repository = SadhanaRepository(datasource);
    final folder = await repository.createResourceFolder(
      name: 'Base',
      circle: 1,
    );
    final resource = MandalaResourceModel.create(
      cycleId: 'base',
      folderId: folder.id,
      title: 'Audio guía',
      type: MandalaResourceType.audio,
    );
    await repository.saveMandalaResource(resource);

    await tester.pumpWidget(
      _wrapWithProviders(
        datasource: datasource,
        repository: repository,
        child: const CyclesPage(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CyclesPage)),
    );
    await container
        .read(appControllerProvider.notifier)
        .createCycle(
          name: 'Mandala Recursos',
          duration: 21,
          customDuration: false,
          sankalpa: 'Enlace',
          tasks: [
            (
              title: 'Japa',
              description: null,
              linkedResourceIds: <String>[resource.id],
            ),
          ],
        );
    await tester.pumpAndSettle();

    final cycle = repository.getCycles().first;
    expect(repository.getTasksByCycle(cycle.id).first.linkedResourceIds, [
      resource.id,
    ]);
  });

  testWidgets('carpeta recursos alterna vista y respeta orden', (tester) async {
    final datasource = _InMemoryDatasource();
    final repository = SadhanaRepository(datasource);
    final folder = await repository.createResourceFolder(
      name: 'Test Media',
      circle: 1,
    );
    final itemA = MandalaResourceModel.create(
      cycleId: folder.id,
      folderId: folder.id,
      title: 'Imagen A',
      type: MandalaResourceType.image,
      filePath: 'https://picsum.photos/seed/a/200/200',
    );
    final itemB = MandalaResourceModel.create(
      cycleId: folder.id,
      folderId: folder.id,
      title: 'Imagen B',
      type: MandalaResourceType.image,
      filePath: 'https://picsum.photos/seed/b/200/200',
    );
    await repository.saveMandalaResource(itemA);
    await repository.saveMandalaResource(itemB);
    await repository.saveResourceItemsOrderForFolder(folder.id, [
      itemB.id,
      itemA.id,
    ]);

    await tester.pumpWidget(
      _wrapWithProviders(
        datasource: datasource,
        repository: repository,
        child: const ResourcesLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Media').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.view_list_outlined), findsOneWidget);
    expect(
      repository.getMandalaResourcesForFolderOrdered(folder.id).first.id,
      itemB.id,
    );
  });
}
