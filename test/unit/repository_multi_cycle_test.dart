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
  List<DayLogModel> getDayLogs() => [];

  @override
  DayLogModel? getDayLog(String id) => null;

  @override
  Future<void> saveDayLog(DayLogModel log) async {}

  @override
  dynamic getSetting(String key) => _settings[key];

  @override
  Future<void> saveSetting(String key, dynamic value) async =>
      _settings[key] = value;
}

void main() {
  late InMemoryDatasource ds;
  late SadhanaRepository repo;

  setUp(() {
    ds = InMemoryDatasource();
    repo = SadhanaRepository(ds);
  });

  group('multiples ciclos activos', () {
    test('startCycle no desactiva otros ciclos activos', () async {
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

    test('stopCycle desactiva solo el ciclo indicado', () async {
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

      await repo.stopCycle(c1.id);

      expect(repo.getCycleById(c1.id)!.isActive, isFalse);
      expect(repo.getCycleById(c2.id)!.isActive, isTrue);
    });

    test('no se puede eliminar ninguno de los ciclos activos', () async {
      final c = CycleModel.create(
        name: 'X',
        duration: 10,
        customDuration: false,
        sankalpa: 'S',
      );
      await repo.createCycle(c);
      await repo.startCycle(c.id);

      expect(
        () => repo.deleteCycle(c.id),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('createCycle con tareas', () {
    test('getTasksByCycle retorna las tareas del ciclo recien creado', () async {
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
    });
  });
}
