import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';

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
}

void main() {
  group('SadhanaRepository rules', () {
    late InMemoryDatasource datasource;
    late SadhanaRepository repository;

    setUp(() {
      datasource = InMemoryDatasource();
      repository = SadhanaRepository(datasource);
    });

    test('blocks sankalpa edit after cycle is active', () async {
      final cycle = CycleModel.create(
        name: 'C1',
        duration: 40,
        customDuration: false,
        sankalpa: 'Disciplina',
      );
      await repository.createCycle(cycle);
      await repository.startCycle(cycle.id);

      final active = repository.getCycleById(cycle.id)!;
      expect(
        () =>
            repository.updateCycle(active.copyWith(sankalpa: 'Otro sankalpa')),
        throwsA(isA<StateError>()),
      );
    });

    test('blocks task deletion in active cycle', () async {
      final cycle = CycleModel.create(
        name: 'C2',
        duration: 21,
        customDuration: true,
        sankalpa: 'Foco',
      );
      await repository.createCycle(cycle);
      await repository.startCycle(cycle.id);

      final task = TaskModel.create(cycleId: cycle.id, title: 'Japa');
      await repository.createTask(task);

      expect(() => repository.deleteTask(task.id), throwsA(isA<StateError>()));
    });

    test('increments streak when all tasks complete on close', () async {
      final cycle = CycleModel.create(
        name: 'C3',
        duration: 7,
        customDuration: true,
        sankalpa: 'Servicio',
      );
      await repository.createCycle(cycle);
      await repository.startCycle(cycle.id);

      final t1 = TaskModel.create(cycleId: cycle.id, title: 'Meditar');
      final t2 = TaskModel.create(cycleId: cycle.id, title: 'Leer');
      await repository.createTask(t1);
      await repository.createTask(t2);

      final today = DateTime.now();
      await repository.toggleTaskCompleted(
        cycleId: cycle.id,
        taskId: t1.id,
        date: today,
        completed: true,
      );
      await repository.toggleTaskCompleted(
        cycleId: cycle.id,
        taskId: t2.id,
        date: today,
        completed: true,
      );

      await repository.closeDay(cycleId: cycle.id, date: today);

      final updated = repository.getCycleById(cycle.id)!;
      expect(updated.streakCurrent, 1);
      expect(updated.streakMax, 1);

      final logId = '${cycle.id}_${DateUtilsX.dateKey(today)}';
      final log = datasource.getDayLog(logId)!;
      expect(log.closed, true);
      expect(log.wasComplete, true);
    });
  });
}
