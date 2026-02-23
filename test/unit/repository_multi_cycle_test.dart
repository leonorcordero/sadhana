import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';

// InMemoryDatasource reutilizable (mismo patron que en otros tests)
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

void main() {
  late InMemoryDatasource ds;
  late SadhanaRepository repo;

  setUp(() {
    ds = InMemoryDatasource();
    repo = SadhanaRepository(ds);
  });

  group('multiples ciclos activos', () {
    test('startCycle permite multiples ciclos activos', () async {
      final c1 = CycleModel.create(
        name: 'A',
        duration: 21,
        customDuration: false,
        sankalpa: 'S1',
      );
      final c2 = CycleModel.create(
        name: 'B',
        duration: 40,
        customDuration: false,
        sankalpa: 'S2',
      );
      await repo.createCycle(c1);
      await repo.createCycle(c2);

      await repo.startCycle(c1.id);
      await repo.startCycle(c2.id);

      expect(repo.getCycleById(c1.id)!.isActive, isTrue);
      expect(repo.getCycleById(c2.id)!.isActive, isTrue);
    });

    test('startCycle en ciclo ya activo no hace nada', () async {
      final c = CycleModel.create(
        name: 'C',
        duration: 7,
        customDuration: false,
        sankalpa: 'S',
      );
      await repo.createCycle(c);
      await repo.startCycle(c.id);
      await repo.startCycle(c.id); // segunda llamada inocua
      expect(repo.getCycleById(c.id)!.isActive, isTrue);
    });

    test('stopCycle desactiva el ciclo indicado', () async {
      final c1 = CycleModel.create(
        name: 'A',
        duration: 21,
        customDuration: false,
        sankalpa: 'S1',
      );
      final c2 = CycleModel.create(
        name: 'B',
        duration: 40,
        customDuration: false,
        sankalpa: 'S2',
      );
      await repo.createCycle(c1);
      await repo.createCycle(c2);
      await repo.startCycle(c2.id);

      await repo.stopCycle(c1.id);

      expect(repo.getCycleById(c1.id)!.isActive, isFalse);
      expect(repo.getCycleById(c2.id)!.isActive, isTrue);
    });

    test('se puede eliminar un ciclo activo', () async {
      final c = CycleModel.create(
        name: 'X',
        duration: 10,
        customDuration: false,
        sankalpa: 'S',
      );
      await repo.createCycle(c);
      await repo.startCycle(c.id);

      await repo.deleteCycle(c.id);
      expect(repo.getCycleById(c.id), isNull);
    });

    test('eliminar ciclo limpia tareas, logs y setting de cierre', () async {
      final c = CycleModel.create(
        name: 'Con datos',
        duration: 10,
        customDuration: false,
        sankalpa: 'S',
      );
      await repo.createCycle(c);
      await repo.startCycle(c.id);
      await repo.createTask(TaskModel.create(cycleId: c.id, title: 'T1'));

      final today = DateTime.now();
      await repo.closeDay(cycleId: c.id, date: today);
      expect(ds.getTasks().where((t) => t.cycleId == c.id).length, 1);
      expect(ds.getDayLogs().where((l) => l.cycleId == c.id).length, 1);
      expect(ds.getSetting('last_closed_date_${c.id}'), isNotNull);

      await repo.deleteCycle(c.id);

      expect(repo.getCycleById(c.id), isNull);
      expect(ds.getTasks().where((t) => t.cycleId == c.id), isEmpty);
      expect(ds.getDayLogs().where((l) => l.cycleId == c.id), isEmpty);
      expect(ds.getSetting('last_closed_date_${c.id}'), isNull);
    });
  });

  group('createCycle con tareas', () {
    test(
      'getTasksByCycle retorna las tareas del ciclo recien creado',
      () async {
        final c = CycleModel.create(
          name: 'Ciclo con tareas',
          duration: 21,
          customDuration: false,
          sankalpa: 'S',
        );
        await repo.createCycle(c);
        await repo.createTask(TaskModel.create(cycleId: c.id, title: 'T1'));
        await repo.createTask(TaskModel.create(cycleId: c.id, title: 'T2'));

        final tasks = repo.getTasksByCycle(c.id);
        expect(tasks.length, 2);
        expect(tasks.map((t) => t.title), containsAll(['T1', 'T2']));
      },
    );
  });
}
