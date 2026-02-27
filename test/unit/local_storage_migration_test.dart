import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';

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
}
