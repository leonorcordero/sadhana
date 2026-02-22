import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/services/daily_closure_service.dart';
import 'package:sadhana/core/services/notification_service.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';
import 'package:sadhana/features/app_shell/application/app_controller.dart';
import 'package:sadhana/features/app_shell/application/app_state.dart';

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

final appControllerProvider = StateNotifierProvider<AppController, AppState>((
  ref,
) {
  return AppController(
    ref.read(repositoryProvider),
    ref.read(dailyClosureServiceProvider),
    ref.read(notificationServiceProvider),
  );
});
