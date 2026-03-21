import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/cycle_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final testPath = Directory.systemTemp.path;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return testPath;
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test(
    'migracion schema v2 agrega parentId a resource_folders antiguos',
    () async {
      final ds = LocalStorageDatasource();
      await ds.init();

      await ds.saveSetting('resource_folders', [
        {
          'id': 'legacy-folder',
          'name': 'Legacy',
          'circle': 0,
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
      ]);
      await ds.saveSetting('schema_version', 1);

      await ds.init();

      final folders = ds.getSetting('resource_folders') as List?;
      expect(folders, isNotNull);
      expect(folders, isNotEmpty);
      final first = Map<String, dynamic>.from(folders!.first as Map);
      expect(first.containsKey('parentId'), isTrue);
      expect(first['parentId'], isNull);

      await Hive.close();
    },
  );

  test(
    'al reinicializar (actualizacion) conserva recursos y configuraciones del usuario',
    () async {
      final ds = LocalStorageDatasource();
      await ds.init();

      final expectedResources = [
        {
          'id': 'res-1',
          'cycleId': 'c-1',
          'folderId': 'folder-1',
          'title': 'Audio personal',
          'type': 'audio',
          'createdAt': '2026-03-01T10:00:00.000Z',
          'filePath': '/tmp/audio.mp3',
          'inlineText': null,
        },
        {
          'id': 'res-2',
          'cycleId': 'c-1',
          'folderId': 'folder-1',
          'title': 'Texto personal',
          'type': 'text',
          'createdAt': '2026-03-01T10:10:00.000Z',
          'filePath': null,
          'inlineText': 'contenido',
        },
      ];
      await ds.saveMandalaResourcesRaw(expectedResources);
      await ds.saveSetting('resource_folders', [
        {
          'id': 'folder-1',
          'name': 'Mis recursos',
          'circle': 0,
          'createdAt': '2026-03-01T09:00:00.000Z',
          'parentId': null,
        },
      ]);
      await ds.saveSetting('task_order_by_cycle', {
        'c-1': ['t-2', 't-1'],
      });
      await ds.saveSetting('home_phrase_text', 'Mi frase personal');
      await ds.saveSetting('schema_version', 2);

      // Simula abrir la app después de instalar actualización.
      await ds.init();

      final resources = ds.getMandalaResourcesRaw();
      final folders = ds.getSetting('resource_folders') as List?;
      final taskOrder = ds.getSetting('task_order_by_cycle') as Map?;
      final homePhrase = ds.getSetting('home_phrase_text') as String?;

      expect(resources, isNotNull);
      expect(resources.length, 2);
      expect(resources.first['id'], 'res-1');
      expect(resources.last['id'], 'res-2');
      expect(folders, isNotNull);
      expect(folders, isNotEmpty);
      expect(taskOrder, isNotNull);
      expect(taskOrder!['c-1'], ['t-2', 't-1']);
      expect(homePhrase, 'Mi frase personal');

      await Hive.close();
    },
  );

  test('import fallido no destruye datos existentes', () async {
    final ds = LocalStorageDatasource();
    await ds.init();

    final existing = CycleModel.create(
      name: 'Original',
      duration: 21,
      customDuration: false,
      sankalpa: 'S',
    );
    await ds.saveCycle(existing);
    await ds.saveSetting('home_phrase_text', 'Texto original');
    final idsBeforeImport = ds.getCycles().map((cycle) => cycle.id).toSet();

    final invalidPayload = <String, dynamic>{
      'cycles': [
        {
          'id': 'new-cycle',
          'name': 'Nuevo',
          'duration': 21,
          'customDuration': false,
          'startDay': 1,
          'currentDay': 1,
          'sankalpa': 'N',
          'streakCurrent': 0,
          'streakMax': 0,
          'isActive': false,
          'circle': 0,
          'linkedResourceFolderIds': <String>[],
        },
      ],
      'tasks': <Map<String, dynamic>>[],
      'dayLogs': <Map<String, dynamic>>[],
      'settings': {'broken': Object()},
    };

    expect(
      () => ds.importAllFromJsonMap(invalidPayload),
      throwsA(isA<Object>()),
    );

    final idsAfterImport = ds.getCycles().map((cycle) => cycle.id).toSet();
    expect(idsAfterImport, idsBeforeImport);
    expect(ds.getSetting('home_phrase_text'), 'Texto original');

    await Hive.close();
  });

  test('import con ciclos invalidos falla y conserva datos actuales', () async {
    final ds = LocalStorageDatasource();
    await ds.init();

    final existing = CycleModel.create(
      name: 'Base',
      duration: 21,
      customDuration: false,
      sankalpa: 'S',
    );
    await ds.saveCycle(existing);
    final idsBeforeImport = ds.getCycles().map((cycle) => cycle.id).toSet();

    final invalidPayload = <String, dynamic>{
      'cycles': [
        {'id': 'broken-cycle', 'name': 'Roto'},
      ],
      'tasks': <Map<String, dynamic>>[],
      'dayLogs': <Map<String, dynamic>>[],
      'settings': <String, dynamic>{},
    };

    expect(
      () => ds.importAllFromJsonMap(invalidPayload),
      throwsA(isA<FormatException>()),
    );

    final idsAfterImport = ds.getCycles().map((cycle) => cycle.id).toSet();
    expect(idsAfterImport, idsBeforeImport);

    await Hive.close();
  });
}
