import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/services/background_service.dart';
import 'package:sadhana/core/services/ios_background_fetch_service.dart';
import 'package:sadhana/core/services/notification_service.dart';
import 'package:sadhana/core/theme/app_theme.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/features/app_shell/presentation/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final datasource = LocalStorageDatasource();
  await datasource.init();

  final notificationService = NotificationService();
  await notificationService.initialize();

  final backgroundService = BackgroundService();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await backgroundService.initialize();
  }

  final iosBackgroundFetchService = IosBackgroundFetchService();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    await iosBackgroundFetchService.initialize();
  }

  runApp(
    ProviderScope(
      overrides: [
        localStorageDatasourceProvider.overrideWithValue(datasource),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const SadhanaApp(),
    ),
  );
}

class SadhanaApp extends StatelessWidget {
  const SadhanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sadhana',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: const HomeShell(),
    );
  }
}
