import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';

const String dailyClosureTask = 'daily_closure_task';

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final datasource = LocalStorageDatasource();
    await datasource.init();

    final repository = SadhanaRepository(datasource);
    await repository.closePendingDaysUntilYesterday();
    return Future.value(true);
  });
}

class BackgroundService {
  Future<void> initialize() async {
    await Workmanager().initialize(workmanagerCallbackDispatcher);

    await Workmanager().registerPeriodicTask(
      'sadhana_daily_worker',
      dailyClosureTask,
      frequency: const Duration(hours: 24),
      initialDelay: const Duration(minutes: 15),
    );
  }
}
