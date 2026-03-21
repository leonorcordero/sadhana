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
import 'package:sadhana/features/app_shell/application/app_state.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

class InMemoryDatasource extends LocalStorageDatasource {
  final _cycles = <String, CycleModel>{};
  final _tasks = <String, TaskModel>{};
  final _logs = <String, DayLogModel>{};
  final _settings = <String, dynamic>{};

  @override
  Future<void> init() async {}

  @override
  List<CycleModel> getCycles() => _cycles.values.toList();

  @override
  Future<void> saveCycle(CycleModel c) async => _cycles[c.id] = c;

  @override
  Future<void> deleteCycle(String id) async => _cycles.remove(id);

  @override
  List<TaskModel> getTasks() => _tasks.values.toList();

  @override
  Future<void> saveTask(TaskModel t) async => _tasks[t.id] = t;

  @override
  Future<void> deleteTask(String id) async => _tasks.remove(id);

  @override
  List<DayLogModel> getDayLogs() => _logs.values.toList();

  @override
  DayLogModel? getDayLog(String id) => _logs[id];

  @override
  Future<void> saveDayLog(DayLogModel log) async => _logs[log.id] = log;

  @override
  Future<void> deleteDayLog(String dayLogId) async => _logs.remove(dayLogId);

  @override
  dynamic getSetting(String key) => _settings[key];

  @override
  Future<void> saveSetting(String key, dynamic value) async =>
      _settings[key] = value;

  @override
  Future<void> deleteSetting(String key) async => _settings.remove(key);
}

class SilentNotificationService extends NotificationService {
  bool cancelCalled = false;

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

  @override
  Future<void> cancelDailyReminders() async {
    cancelCalled = true;
  }

  @override
  Future<void> scheduleMandalaStartReminders({
    required List<CycleModel> cycles,
    required bool enabled,
  }) async {}
}

// ── Helper ────────────────────────────────────────────────────────────────────

ProviderContainer buildContainer({
  required InMemoryDatasource datasource,
  SilentNotificationService? notificationService,
}) {
  final repo = SadhanaRepository(datasource);
  final notif = notificationService ?? SilentNotificationService();

  return ProviderContainer(
    overrides: [
      localStorageDatasourceProvider.overrideWithValue(datasource),
      repositoryProvider.overrideWithValue(repo),
      notificationServiceProvider.overrideWithValue(notif),
      dailyClosureServiceProvider.overrideWithValue(DailyClosureService()),
    ],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('AppController.createCycle', () {
    test('crea ciclo y sus tareas en un solo paso', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      await controller.createCycle(
        name: 'Meditacion',
        duration: 21,
        customDuration: false,
        sankalpa: 'Silencio interior',
        tasks: [
          (
            title: 'Meditar 20 min',
            description: null,
            linkedResourceIds: const <String>[],
          ),
          (
            title: 'Journaling',
            description: 'Escribir 3 paginas',
            linkedResourceIds: const <String>[],
          ),
        ],
      );

      final state = container.read(appControllerProvider);
      expect(state.cycles.length, 1);
      expect(state.tasks.length, 2);
      expect(
        state.tasks.map((t) => t.title),
        containsAll(['Meditar 20 min', 'Journaling']),
      );
    });

    test('ciclo creado se activa automaticamente', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      await container
          .read(appControllerProvider.notifier)
          .createCycle(
            name: 'Yoga',
            duration: 40,
            customDuration: false,
            sankalpa: 'Fuerza',
          );

      final state = container.read(appControllerProvider);
      expect(state.cycles.first.isActive, isTrue);
    });

    test('crea tareas con recursos vinculados', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      await controller.createCycle(
        name: 'Ciclo con links',
        duration: 21,
        customDuration: false,
        sankalpa: 'Persistencia',
        tasks: [
          (
            title: 'Meditacion',
            description: null,
            linkedResourceIds: const ['audio-1', 'texto-1'],
          ),
        ],
      );

      final state = container.read(appControllerProvider);
      expect(state.tasks.length, 1);
      expect(state.tasks.first.linkedResourceIds, ['audio-1', 'texto-1']);
    });

    test('crea ciclo con carpetas de recursos vinculadas', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      await controller.createCycle(
        name: 'Ciclo carpetas',
        duration: 21,
        customDuration: false,
        sankalpa: 'Orden',
        selectedResourceFolderIds: const ['folder-1', 'folder-2'],
      );

      final state = container.read(appControllerProvider);
      expect(state.cycles.length, 1);
      expect(state.cycles.first.linkedResourceFolderIds, [
        'folder-1',
        'folder-2',
      ]);
    });

    test('si inicio es futuro, crea ciclo sin activar', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await controller.createCycle(
        name: 'Ciclo futuro',
        duration: 21,
        customDuration: false,
        sankalpa: 'Preparacion',
        plannedStartDate: tomorrow,
      );

      final state = container.read(appControllerProvider);
      expect(state.cycles.length, 1);
      expect(state.cycles.first.isActive, isFalse);
      expect(state.cycles.first.plannedStartDateKey, isNotNull);
    });

    test('si inicio es pasado y no viene de plantilla, se activa', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await controller.createCycle(
        name: 'Ciclo pasado',
        duration: 21,
        customDuration: false,
        sankalpa: 'Constancia',
        plannedStartDate: yesterday,
      );

      final state = container.read(appControllerProvider);
      expect(state.cycles.length, 1);
      expect(state.cycles.first.isActive, isTrue);
      expect(state.cycles.first.currentDay, 2);
    });

    test(
      'si fecha pasada excede duracion, se crea al ultimo dia y no se activa',
      () async {
        final ds = InMemoryDatasource();
        final container = buildContainer(datasource: ds);
        addTearDown(container.dispose);

        final controller = container.read(appControllerProvider.notifier);
        final oldDate = DateTime.now().subtract(const Duration(days: 30));
        await controller.createCycle(
          name: 'Ciclo vencido',
          duration: 7,
          customDuration: false,
          sankalpa: 'Disciplina',
          plannedStartDate: oldDate,
        );

        final state = container.read(appControllerProvider);
        expect(state.cycles.length, 1);
        expect(state.cycles.first.currentDay, 7);
        expect(state.cycles.first.isActive, isFalse);
      },
    );

    test(
      'si inicio es hoy y no viene de plantilla, se activa automaticamente',
      () async {
        final ds = InMemoryDatasource();
        final container = buildContainer(datasource: ds);
        addTearDown(container.dispose);

        final controller = container.read(appControllerProvider.notifier);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        await controller.createCycle(
          name: 'Ciclo hoy',
          duration: 21,
          customDuration: false,
          sankalpa: 'Accion',
          plannedStartDate: today,
        );

        final state = container.read(appControllerProvider);
        expect(state.cycles.length, 1);
        expect(state.cycles.first.isActive, isTrue);
      },
    );

    test('si inicio es hoy y viene de plantilla, queda sin activar', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await controller.createCycle(
        name: 'Ciclo plantilla hoy',
        duration: 21,
        customDuration: false,
        sankalpa: 'Orden',
        plannedStartDate: today,
        createdFromTemplate: true,
      );

      final state = container.read(appControllerProvider);
      expect(state.cycles.length, 1);
      expect(state.cycles.first.isActive, isFalse);
    });
  });

  group('AppController multiples ciclos activos', () {
    test('startCycle permite multiples ciclos activos', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);

      await controller.createCycle(
        name: 'A',
        duration: 21,
        customDuration: false,
        sankalpa: 'S1',
      );
      await controller.createCycle(
        name: 'B',
        duration: 40,
        customDuration: false,
        sankalpa: 'S2',
      );

      final cycles = container.read(appControllerProvider).cycles;
      await controller.startCycle(cycles[0].id);
      await controller.startCycle(cycles[1].id);

      final state = container.read(appControllerProvider);
      expect(state.activeCycles.length, 2);
      expect(state.activeCycles.map((c) => c.name), containsAll(['A', 'B']));
    });

    test('stopCycle desactiva solo el ciclo indicado', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);

      await controller.createCycle(
        name: 'A',
        duration: 21,
        customDuration: false,
        sankalpa: 'S',
      );
      await controller.createCycle(
        name: 'B',
        duration: 40,
        customDuration: false,
        sankalpa: 'S',
      );

      final cycles = container.read(appControllerProvider).cycles;
      await controller.startCycle(cycles[0].id);
      await controller.startCycle(cycles[1].id);
      await controller.stopCycle(cycles[1].id);

      final state = container.read(appControllerProvider);
      expect(state.activeCycles.length, 1);
      expect(state.activeCycles.first.name, 'A');
    });

    test('permite guardar orden de tareas del ciclo', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);
      final controller = container.read(appControllerProvider.notifier);

      await controller.createCycle(
        name: 'Orden',
        duration: 21,
        customDuration: false,
        sankalpa: 'S',
        tasks: [
          (title: 'A', description: null, linkedResourceIds: const <String>[]),
          (title: 'B', description: null, linkedResourceIds: const <String>[]),
        ],
      );

      final cycle = container.read(appControllerProvider).cycles.first;
      final tasksBefore = container
          .read(appControllerProvider)
          .tasks
          .where((t) => t.cycleId == cycle.id)
          .toList(growable: false);
      await controller.saveTaskOrderForCycle(cycle.id, [
        tasksBefore[1].id,
        tasksBefore[0].id,
      ]);

      final tasksAfter = container
          .read(appControllerProvider)
          .tasks
          .where((t) => t.cycleId == cycle.id)
          .toList(growable: false);
      expect(tasksAfter.first.id, tasksBefore[1].id);
    });
  });

  group('AppController notificaciones condicionales', () {
    test(
      'cancela recordatorios cuando todos los ciclos del dia estan completos',
      () async {
        final ds = InMemoryDatasource();
        final notif = SilentNotificationService();
        final container = buildContainer(
          datasource: ds,
          notificationService: notif,
        );
        addTearDown(container.dispose);

        final controller = container.read(appControllerProvider.notifier);

        await controller.createCycle(
          name: 'Ciclo unico',
          duration: 7,
          customDuration: false,
          sankalpa: 'S',
          tasks: [
            (
              title: 'Tarea unica',
              description: null,
              linkedResourceIds: const <String>[],
            ),
          ],
        );

        final state = container.read(appControllerProvider);
        final cycle = state.cycles.first;
        await controller.startCycle(cycle.id);

        // Selecciona hoy
        final today = DateTime.now();
        controller.selectDate(today);

        final taskId = container.read(appControllerProvider).tasks.first.id;
        await controller.toggleTaskForSelectedDate(
          taskId: taskId,
          completed: true,
        );

        expect(notif.cancelCalled, isTrue);
      },
    );

    test('no cancela recordatorios si quedan ciclos incompletos', () async {
      final ds = InMemoryDatasource();
      final notif = SilentNotificationService();
      final container = buildContainer(
        datasource: ds,
        notificationService: notif,
      );
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);

      // Ciclo A con 1 tarea, Ciclo B con 1 tarea
      await controller.createCycle(
        name: 'A',
        duration: 7,
        customDuration: false,
        sankalpa: 'S',
        tasks: [
          (
            title: 'Tarea A',
            description: null,
            linkedResourceIds: const <String>[],
          ),
        ],
      );
      await controller.createCycle(
        name: 'B',
        duration: 7,
        customDuration: false,
        sankalpa: 'S',
        tasks: [
          (
            title: 'Tarea B',
            description: null,
            linkedResourceIds: const <String>[],
          ),
        ],
      );

      final cycles = container.read(appControllerProvider).cycles;
      await controller.startCycle(cycles[0].id);
      await controller.startCycle(cycles[1].id);

      final tasks = container.read(appControllerProvider).tasks;
      final taskA = tasks.firstWhere((t) => t.cycleId == cycles[0].id);

      // Solo completa el ciclo A
      await controller.toggleTaskForSelectedDate(
        taskId: taskA.id,
        completed: true,
      );

      // B sigue incompleto, no debe cancelar
      expect(notif.cancelCalled, isFalse);
    });
  });

  group('AppController auto-cierre al completar todas las tareas', () {
    test(
      'cierra el dia automaticamente cuando todas las tareas estan listas',
      () async {
        final ds = InMemoryDatasource();
        final container = buildContainer(datasource: ds);
        addTearDown(container.dispose);

        final controller = container.read(appControllerProvider.notifier);

        await controller.createCycle(
          name: 'Ciclo auto',
          duration: 7,
          customDuration: false,
          sankalpa: 'S',
          tasks: [
            (
              title: 'Unica tarea',
              description: null,
              linkedResourceIds: const <String>[],
            ),
          ],
        );

        final cycle = container.read(appControllerProvider).cycles.first;
        await controller.startCycle(cycle.id);

        controller.selectDate(DateTime.now());

        final taskId = container.read(appControllerProvider).tasks.first.id;
        await controller.toggleTaskForSelectedDate(
          taskId: taskId,
          completed: true,
        );

        final logs = container.read(appControllerProvider).logs;
        expect(logs.any((l) => l.closed), isTrue);
      },
    );

    test(
      'no cierra automaticamente si la fecha seleccionada no es hoy',
      () async {
        final ds = InMemoryDatasource();
        final container = buildContainer(datasource: ds);
        addTearDown(container.dispose);

        final controller = container.read(appControllerProvider.notifier);

        await controller.createCycle(
          name: 'Ciclo pasado',
          duration: 7,
          customDuration: false,
          sankalpa: 'S',
          tasks: [
            (
              title: 'Tarea',
              description: null,
              linkedResourceIds: const <String>[],
            ),
          ],
        );

        final cycle = container.read(appControllerProvider).cycles.first;
        await controller.startCycle(cycle.id);

        controller.selectDate(DateTime.now().subtract(const Duration(days: 1)));

        final taskId = container.read(appControllerProvider).tasks.first.id;
        await controller.toggleTaskForSelectedDate(
          taskId: taskId,
          completed: true,
        );

        final logs = container.read(appControllerProvider).logs;
        expect(logs.any((l) => l.closed), isFalse);
      },
    );

    test(
      'cierra automaticamente usando selectedDate inicial del estado',
      () async {
        final ds = InMemoryDatasource();
        final container = buildContainer(datasource: ds);
        addTearDown(container.dispose);

        final controller = container.read(appControllerProvider.notifier);

        await controller.createCycle(
          name: 'Ciclo inicial',
          duration: 7,
          customDuration: false,
          sankalpa: 'S',
          tasks: [
            (
              title: 'Tarea',
              description: null,
              linkedResourceIds: const <String>[],
            ),
          ],
        );

        final cycle = container.read(appControllerProvider).cycles.first;
        await controller.startCycle(cycle.id);

        final taskId = container.read(appControllerProvider).tasks.first.id;
        await controller.toggleTaskForSelectedDate(
          taskId: taskId,
          completed: true,
        );

        final logs = container.read(appControllerProvider).logs;
        expect(logs.any((l) => l.closed), isTrue);
      },
    );
  });

  group('AppState getters', () {
    test('activeCycle retorna null cuando no hay ciclos activos', () {
      final state = AppState.initial();
      expect(state.activeCycle, isNull);
      expect(state.activeCycles, isEmpty);
    });

    test('selectedDate inicial queda normalizada al inicio del dia', () {
      final state = AppState.initial();
      expect(state.selectedDate.hour, 0);
      expect(state.selectedDate.minute, 0);
      expect(state.selectedDate.second, 0);
    });
  });
}
