import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/services/daily_closure_service.dart';
import 'package:sadhana/core/services/google_drive_sync_service.dart';
import 'package:sadhana/core/services/notification_service.dart';
import 'package:sadhana/core/settings/app_settings.dart';
import 'package:sadhana/core/settings/app_settings_notifier.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:sadhana/features/app_shell/application/app_controller.dart';
import 'package:sadhana/features/app_shell/application/app_state.dart';
import 'package:sadhana/features/resources/application/resources_audio_controller.dart';
import 'package:sadhana/features/utilities/application/counter_controller.dart';
import 'package:sadhana/features/utilities/application/recorder_controller.dart';
import 'package:sadhana/features/utilities/application/stopwatch_controller.dart';

final localStorageDatasourceProvider = Provider<LocalStorageDatasource>((ref) {
  return LocalStorageDatasource();
});

final repositoryProvider = Provider<SadhanaRepository>((ref) {
  return SadhanaRepository(ref.read(localStorageDatasourceProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final dailyClosureServiceProvider = Provider<DailyClosureService>((ref) {
  return DailyClosureService();
});

final driveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  return GoogleDriveSyncService(
    ref.read(localStorageDatasourceProvider),
    ref.read(repositoryProvider),
  );
});

final resourcesAudioControllerProvider = Provider<ResourcesAudioController>((
  ref,
) {
  final controller = ResourcesAudioController();
  ref.onDispose(controller.dispose);
  return controller;
});

final stopwatchControllerProvider = Provider<StopwatchController>((ref) {
  final controller = StopwatchController();
  ref.onDispose(controller.dispose);
  return controller;
});

final counterControllerProvider = Provider<CounterController>((ref) {
  final controller = CounterController();
  ref.onDispose(controller.dispose);
  return controller;
});

final recorderControllerProvider = Provider<RecorderController>((ref) {
  final controller = RecorderController();
  ref.onDispose(controller.dispose);
  return controller;
});

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
      return AppSettingsNotifier(ref.read(localStorageDatasourceProvider));
    });

final appControllerProvider = StateNotifierProvider<AppController, AppState>((
  ref,
) {
  return AppController(
    ref.read(repositoryProvider),
    ref.read(dailyClosureServiceProvider),
    ref.read(notificationServiceProvider),
    ref.read(driveSyncServiceProvider),
  );
});
