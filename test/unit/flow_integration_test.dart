import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';

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
  test('flujo crear iniciar completar cerrar dia', () async {
    final ds = InMemoryDatasource();
    final repo = SadhanaRepository(ds);

    final cycle = CycleModel.create(
      name: 'Flujo',
      duration: 7,
      customDuration: false,
      sankalpa: 'S',
    );
    await repo.createCycle(cycle);
    await repo.startCycle(cycle.id);
    final active = repo.getActiveCycle();
    expect(active?.id, cycle.id);

    final t1 = TaskModel.create(cycleId: cycle.id, title: 'A');
    final t2 = TaskModel.create(cycleId: cycle.id, title: 'B');
    await repo.createTask(t1);
    await repo.createTask(t2);

    final today = DateTime.now();
    await repo.toggleTaskCompleted(
      cycleId: cycle.id,
      taskId: t1.id,
      date: today,
      completed: true,
    );
    await repo.toggleTaskCompleted(
      cycleId: cycle.id,
      taskId: t2.id,
      date: today,
      completed: true,
    );

    await repo.closeDay(cycleId: cycle.id, date: today);

    final key = '${cycle.id}_${DateUtilsX.dateKey(today)}';
    final log = ds.getDayLog(key);
    expect(log?.closed, true);
    expect(log?.wasComplete, true);
    expect(repo.getCycleById(cycle.id)?.streakCurrent, 1);
  });
}
