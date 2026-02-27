import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/data/models/resource_folder_model.dart';
import 'package:sadhana/data/models/task_model.dart';
import 'package:sadhana/data/models/wednesday_affirmation_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';

class InMemoryDatasource extends LocalStorageDatasource {
  final Map<String, CycleModel> _cycles = {};
  final Map<String, TaskModel> _tasks = {};
  final Map<String, DayLogModel> _logs = {};
  final Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _mandalaResources = <Map<String, dynamic>>[];

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
  Future<void> deleteDayLog(String dayLogId) async {
    _logs.remove(dayLogId);
  }

  @override
  dynamic getSetting(String key) => _settings[key];

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    _settings[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _settings.remove(key);
  }

  @override
  List<Map<String, dynamic>> getMandalaResourcesRaw() =>
      List<Map<String, dynamic>>.from(_mandalaResources);

  @override
  Future<void> saveMandalaResourcesRaw(List<Map<String, dynamic>> items) async {
    _mandalaResources = List<Map<String, dynamic>>.from(items);
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

    test('wednesday affirmation lee formato antiguo map', () async {
      await datasource.saveSetting('wednesday_affirmation', {
        'meditationDateKey': '2026-02-18',
        'name': 'Antigua',
        'contentType': 'text',
        'text': 'contenido',
      });

      final item = repository.getWednesdayAffirmation();
      expect(item, isNotNull);
      expect(item!.meditationDateKey, '2026-02-18');
      expect(item.name, 'Antigua');
    });

    test('wednesday affirmation guarda y lee lista', () async {
      await repository.saveWednesdayAffirmation(
        const WednesdayAffirmationModel(
          meditationDateKey: '2026-02-24',
          name: 'Uno',
          contentType: 'text',
          text: 'A',
          imagePath: null,
          updatedAt: '2026-02-24T10:00:00.000Z',
        ),
      );
      await repository.saveWednesdayAffirmation(
        const WednesdayAffirmationModel(
          meditationDateKey: '2026-02-25',
          name: 'Dos',
          contentType: 'text',
          text: 'B',
          imagePath: null,
          updatedAt: '2026-02-25T10:00:00.000Z',
        ),
      );

      final list = repository.getWednesdayAffirmations();
      expect(list.length, 2);
      expect(list.first.meditationDateKey, '2026-02-25');
      expect(repository.getWednesdayAffirmation()!.name, 'Dos');
    });

    test('permite editar afirmacion personalizada sin duplicar', () async {
      await repository.addCustomHomePhrase(
        type: 'affirmation',
        text: 'Primera',
      );
      await repository.addCustomHomePhrase(
        type: 'affirmation',
        text: 'Segunda',
      );

      final updated = await repository.updateCustomHomePhrase(
        type: 'affirmation',
        previousText: 'Primera',
        nextText: 'Primera editada',
      );
      expect(updated, isTrue);

      final list = repository.getCustomHomePhrases(type: 'affirmation');
      expect(list, ['Primera editada', 'Segunda']);

      final rejected = await repository.updateCustomHomePhrase(
        type: 'affirmation',
        previousText: 'Segunda',
        nextText: 'Primera editada',
      );
      expect(rejected, isFalse);
      expect(repository.getCustomHomePhrases(type: 'affirmation'), list);
    });

    test('permite borrar afirmacion de miercoles por updatedAt', () async {
      await repository.saveWednesdayAffirmations(const [
        WednesdayAffirmationModel(
          meditationDateKey: '2026-02-26',
          name: 'A',
          contentType: 'text',
          text: 'uno',
          imagePath: null,
          updatedAt: '2026-02-26T10:00:00.000Z',
        ),
        WednesdayAffirmationModel(
          meditationDateKey: '2026-02-27',
          name: 'B',
          contentType: 'text',
          text: 'dos',
          imagePath: null,
          updatedAt: '2026-02-27T10:00:00.000Z',
        ),
      ]);

      await repository.removeWednesdayAffirmation(
        updatedAt: '2026-02-26T10:00:00.000Z',
      );

      final remaining = repository.getWednesdayAffirmations();
      expect(remaining.length, 1);
      expect(remaining.first.updatedAt, '2026-02-27T10:00:00.000Z');
    });

    test('permite guardar orden manual de carpetas de recursos', () async {
      final a = await repository.createResourceFolder(name: 'A', circle: 0);
      final b = await repository.createResourceFolder(name: 'B', circle: 0);
      final c = await repository.createResourceFolder(name: 'C', circle: 0);

      await repository.saveResourceFoldersOrderIds([b.id, a.id, c.id]);

      final ordered = repository.getResourceFolders().map((f) => f.id).toList();
      expect(ordered, [b.id, a.id, c.id]);
    });

    test(
      'permite guardar orden manual de recursos dentro de carpeta',
      () async {
        const folder = ResourceFolderModel(
          id: 'folder-1',
          name: 'Carpeta',
          circle: 0,
          createdAt: '2026-02-01T10:00:00.000Z',
        );
        await repository.saveResourceFolder(folder);

        final one = MandalaResourceModel.create(
          cycleId: folder.id,
          folderId: folder.id,
          title: 'Uno',
          type: MandalaResourceType.text,
          inlineText: 'A',
        );
        final two = MandalaResourceModel.create(
          cycleId: folder.id,
          folderId: folder.id,
          title: 'Dos',
          type: MandalaResourceType.text,
          inlineText: 'B',
        );
        await repository.saveMandalaResource(one);
        await repository.saveMandalaResource(two);

        await repository.saveResourceItemsOrderForFolder(folder.id, [
          one.id,
          two.id,
        ]);

        final ordered = repository
            .getMandalaResourcesForFolderOrdered(folder.id)
            .map((r) => r.id)
            .toList();
        expect(ordered, [one.id, two.id]);
      },
    );

    test('permite crear y listar subcarpetas por parentId', () async {
      final parent = await repository.createResourceFolder(
        name: 'Padre',
        circle: 2,
      );
      final child = await repository.createResourceFolder(
        name: 'Hija',
        circle: 2,
        parentId: parent.id,
      );

      final topLevel = repository.getChildResourceFolders(null);
      final children = repository.getChildResourceFolders(parent.id);
      expect(topLevel.any((f) => f.id == parent.id), isTrue);
      expect(topLevel.any((f) => f.id == child.id), isFalse);
      expect(children.map((f) => f.id), contains(child.id));
    });

    test(
      'createResourceFolder ignora parentId invalido y crea en raiz',
      () async {
        final orphan = await repository.createResourceFolder(
          name: 'Huérfana',
          circle: 0,
          parentId: 'no-existe',
        );
        expect(orphan.parentId, isNull);
        expect(
          repository
              .getChildResourceFolders(null)
              .any((f) => f.id == orphan.id),
          isTrue,
        );
      },
    );

    test(
      'eliminar carpeta borra subcarpetas y recursos descendientes',
      () async {
        final parent = await repository.createResourceFolder(
          name: 'Padre',
          circle: 1,
        );
        final child = await repository.createResourceFolder(
          name: 'Hija',
          circle: 1,
          parentId: parent.id,
        );

        final parentResource = MandalaResourceModel.create(
          cycleId: parent.id,
          folderId: parent.id,
          title: 'A',
          type: MandalaResourceType.text,
          inlineText: 'uno',
        );
        final childResource = MandalaResourceModel.create(
          cycleId: child.id,
          folderId: child.id,
          title: 'B',
          type: MandalaResourceType.text,
          inlineText: 'dos',
        );
        await repository.saveMandalaResource(parentResource);
        await repository.saveMandalaResource(childResource);

        await repository.deleteResourceFolder(parent.id);

        expect(
          repository.getResourceFolders().where(
            (f) => f.id == parent.id || f.id == child.id,
          ),
          isEmpty,
        );
        expect(
          repository.getMandalaResources().where(
            (r) => r.folderId == parent.id || r.folderId == child.id,
          ),
          isEmpty,
        );
      },
    );

    test(
      'moon card texts usa defaults y permite guardar personalizados',
      () async {
        final defaults = repository.getMoonCardTexts();
        expect(
          defaults.nightWarningText,
          SadhanaRepository.defaultMoonNightWarningText,
        );
        expect(defaults.dayOnlyText, SadhanaRepository.defaultMoonDayOnlyText);

        await repository.saveMoonCardTexts(
          nightWarningText: 'Evita sadhana nocturna hoy.',
          dayOnlyText: 'Practica solo en horario diurno.',
        );

        final customized = repository.getMoonCardTexts();
        expect(customized.nightWarningText, 'Evita sadhana nocturna hoy.');
        expect(customized.dayOnlyText, 'Practica solo en horario diurno.');
      },
    );
  });
}
