import 'package:flutter_test/flutter_test.dart';
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
  dynamic getSetting(String key) => _settings[key];

  @override
  Future<void> saveSetting(String key, dynamic value) async =>
      _settings[key] = value;

  @override
  Future<Map<String, dynamic>> exportAllAsJsonMap() async {
    return {
      'schemaVersion': 1,
      'cycles': _cycles.values.map((c) => c.toMap()).toList(),
      'tasks': _tasks.values.map((t) => t.toMap()).toList(),
      'dayLogs': _logs.values.map((d) => d.toMap()).toList(),
      'settings': Map<String, dynamic>.from(_settings),
    };
  }

  @override
  Future<void> importAllFromJsonMap(Map<String, dynamic> payload) async {
    _cycles.clear();
    _tasks.clear();
    _logs.clear();
    _settings.clear();

    for (final row in (payload['cycles'] as List)) {
      final cycle = CycleModel.fromMap(Map<String, dynamic>.from(row as Map));
      _cycles[cycle.id] = cycle;
    }
    for (final row in (payload['tasks'] as List)) {
      final task = TaskModel.fromMap(Map<String, dynamic>.from(row as Map));
      _tasks[task.id] = task;
    }
    for (final row in (payload['dayLogs'] as List)) {
      final log = DayLogModel.fromMap(Map<String, dynamic>.from(row as Map));
      _logs[log.id] = log;
    }
    _settings.addAll(Map<String, dynamic>.from(payload['settings'] as Map));
  }
}

void main() {
  test('export/import backup conserva ciclos y tareas', () async {
    final ds1 = InMemoryDatasource();
    final repo1 = SadhanaRepository(ds1);

    final cycle = CycleModel.create(
      name: 'Backup test',
      duration: 21,
      customDuration: false,
      sankalpa: 'S',
    );
    await repo1.createCycle(cycle);
    await repo1.createTask(TaskModel.create(cycleId: cycle.id, title: 'T1'));

    final backup = await repo1.exportBackupJson();

    final ds2 = InMemoryDatasource();
    final repo2 = SadhanaRepository(ds2);
    await repo2.importBackupJson(backup);

    expect(repo2.getCycles().length, 1);
    expect(repo2.getTasksByCycle(repo2.getCycles().first.id).length, 1);
  });
}
