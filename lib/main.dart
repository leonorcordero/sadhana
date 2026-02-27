import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sadhana/core/providers.dart';
import 'package:sadhana/core/services/background_service.dart';
import 'package:sadhana/core/services/ios_background_fetch_service.dart';
import 'package:sadhana/core/services/notification_service.dart';
import 'package:sadhana/core/theme/app_theme.dart';
import 'package:sadhana/core/utils/responsive_utils.dart';
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

class SadhanaApp extends ConsumerWidget {
  const SadhanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      title: settings.name,
      theme: AppTheme.light(seed: settings.themeColor),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final typeScale =
            (ResponsiveUtils.typographyScale(context) * settings.textScale)
                .clamp(0.78, 1.06);
        final textScale =
            (ResponsiveUtils.textScaleFactor(context) * settings.textScale)
                .clamp(0.85, 1.12);
        final theme = Theme.of(context);
        final scaledTheme = theme.copyWith(
          textTheme: ResponsiveUtils.scaledTextTheme(
            theme.textTheme,
            typeScale,
          ),
          primaryTextTheme: ResponsiveUtils.scaledTextTheme(
            theme.primaryTextTheme,
            typeScale,
          ),
        );
        final media = MediaQuery.of(context);

        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: Theme(data: scaledTheme, child: child ?? const SizedBox()),
        );
      },
      home: const HomeShell(),
    );
  }
}
