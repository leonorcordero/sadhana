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
  dynamic getSetting(String key) => _settings[key];

  @override
  Future<void> saveSetting(String key, dynamic value) async =>
      _settings[key] = value;
}

class SilentNotificationService extends NotificationService {
  bool cancelCalled = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleDailyReminders() async {}

  @override
  Future<void> showCompletionNotification() async {}

  @override
  Future<void> cancelDailyReminders() async {
    cancelCalled = true;
  }
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
          (title: 'Meditar 20 min', description: null),
          (title: 'Journaling', description: 'Escribir 3 paginas'),
        ],
      );

      final state = container.read(appControllerProvider);
      expect(state.cycles.length, 1);
      expect(state.tasks.length, 2);
      expect(state.tasks.map((t) => t.title), containsAll([
        'Meditar 20 min',
        'Journaling',
      ]));
    });

    test('ciclo creado comienza inactivo', () async {
      final ds = InMemoryDatasource();
      final container = buildContainer(datasource: ds);
      addTearDown(container.dispose);

      await container.read(appControllerProvider.notifier).createCycle(
        name: 'Yoga',
        duration: 40,
        customDuration: false,
        sankalpa: 'Fuerza',
      );

      final state = container.read(appControllerProvider);
      expect(state.cycles.first.isActive, isFalse);
    });
  });

  group('AppController multiples ciclos activos', () {
    test('activeCycles retorna todos los ciclos activos', () async {
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

      await controller.stopCycle(cycles[0].id);

      final state = container.read(appControllerProvider);
      expect(state.activeCycles.length, 1);
      expect(state.activeCycles.first.name, 'B');
    });
  });

  group('AppController notificaciones condicionales', () {
    test('cancela recordatorios cuando todos los ciclos del dia estan completos',
        () async {
      final ds = InMemoryDatasource();
      final notif = SilentNotificationService();
      final container = buildContainer(datasource: ds, notificationService: notif);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);

      await controller.createCycle(
        name: 'Ciclo unico',
        duration: 7,
        customDuration: false,
        sankalpa: 'S',
        tasks: [(title: 'Tarea unica', description: null)],
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
    });

    test('no cancela recordatorios si quedan ciclos incompletos', () async {
      final ds = InMemoryDatasource();
      final notif = SilentNotificationService();
      final container = buildContainer(datasource: ds, notificationService: notif);
      addTearDown(container.dispose);

      final controller = container.read(appControllerProvider.notifier);

      // Ciclo A con 1 tarea, Ciclo B con 1 tarea
      await controller.createCycle(
        name: 'A',
        duration: 7,
        customDuration: false,
        sankalpa: 'S',
        tasks: [(title: 'Tarea A', description: null)],
      );
      await controller.createCycle(
        name: 'B',
        duration: 7,
        customDuration: false,
        sankalpa: 'S',
        tasks: [(title: 'Tarea B', description: null)],
      );

      final cycles = container.read(appControllerProvider).cycles;
      await controller.startCycle(cycles[0].id);
      await controller.startCycle(cycles[1].id);

      final tasks = container.read(appControllerProvider).tasks;
      final taskA = tasks.firstWhere(
        (t) => t.cycleId == cycles[0].id,
      );

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
    test('cierra el dia automaticamente cuando todas las tareas estan listas',
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
        tasks: [(title: 'Unica tarea', description: null)],
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
    });

    test('no cierra automaticamente si la fecha seleccionada no es hoy',
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
        tasks: [(title: 'Tarea', description: null)],
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
    });
  });

  group('AppState getters', () {
    test('activeCycle retorna null cuando no hay ciclos activos', () {
      final state = AppState.initial();
      expect(state.activeCycle, isNull);
      expect(state.activeCycles, isEmpty);
    });
  });
}
