import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:sadhana/core/constants/app_constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool get _isWeb => kIsWeb;

  Future<void> initialize() async {
    if (_isWeb) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
  }

  Future<void> scheduleDailyReminders({
    List<int> hours = const [9, 14, 20],
    bool enabled = true,
    String contentType = 'focus',
    String customText = '',
  }) async {
    if (_isWeb) return;
    if (!enabled) {
      await cancelDailyReminders();
      return;
    }

    const android = AndroidNotificationDetails(
      'sadhana_reminders',
      'Recordatorios diarios',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    final normalized = List<int>.from(hours)
      ..sort()
      ..retainWhere((h) => h >= 0 && h <= 23);
    if (normalized.isEmpty) return;

    // Elimina el archivo de SharedPreferences de notificaciones antiguas
    // para limpiar datos en formato incompatible de versiones anteriores.
    // Esto permite que cancelAll() y zonedSchedule() funcionen sin errores.
    await _clearLegacyNotificationPrefs();

    try {
      await _plugin.cancelAll();
    } on PlatformException {
      // Si aún falla (p. ej. el archivo estaba en caché), continuamos.
    }

    final body = _buildReminderBody(
      contentType: contentType,
      customText: customText,
    );

    for (var i = 0; i < normalized.length; i++) {
      final id = 100 + i;
      try {
        await _plugin.zonedSchedule(
          id,
          'Sadhana',
          body,
          _nextTime(normalized[i]),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } on PlatformException catch (e) {
        if (e.code == 'exact_alarms_not_permitted') {
          // Android 14+ puede bloquear alarmas exactas; usamos modo inexacto.
          try {
            await _plugin.zonedSchedule(
              id,
              'Sadhana',
              body,
              _nextTime(normalized[i]),
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.time,
            );
          } on PlatformException {
            // Silenciamos si el modo inexacto también falla.
          }
        }
        // Otros errores se ignoran para no bloquear la app.
      }
    }
  }

  // Cancela los recordatorios pendientes del dia (usados cuando el usuario
  // completo todas sus tareas antes de que llegue el proximo recordatorio).
  Future<void> cancelDailyReminders() async {
    if (_isWeb) return;
    await _clearLegacyNotificationPrefs();
    for (var i = 0; i < 12; i++) {
      try {
        await _plugin.cancel(100 + i);
      } on PlatformException {
        // Silencioso si los datos guardados son incompatibles.
      }
    }
  }

  Future<void> showCompletionNotification() async {
    if (_isWeb) return;
    const android = AndroidNotificationDetails(
      'sadhana_rewards',
      'Recompensas',
      importance: Importance.max,
      priority: Priority.max,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await _plugin.show(
      201,
      'Dia completo',
      'Excelente. Completaste todas tus tareas de hoy.',
      details,
    );
  }

  tz.TZDateTime _nextTime(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _buildReminderBody({
    required String contentType,
    required String customText,
  }) {
    switch (contentType) {
      case 'pending':
        return 'Tienes tareas pendientes. Vuelve a tu practica ahora.';
      case 'motivational':
        final seed = DateTime.now().day % AppConstants.reminderQuotes.length;
        return AppConstants.reminderQuotes[seed];
      case 'custom':
        final normalized = customText.trim();
        if (normalized.isNotEmpty) return normalized;
        return 'Tienes tareas pendientes. Cierra tu dia con enfoque.';
      case 'focus':
      default:
        return 'Tienes tareas pendientes. Cierra tu dia con enfoque.';
    }
  }

  /// Borra el archivo XML de SharedPreferences que usa flutter_local_notifications
  /// para persistir las notificaciones programadas. Necesario cuando los datos
  /// guardados con una versión anterior del plugin son incompatibles con la
  /// versión actual y causan un RuntimeException al deserializarse.
  Future<void> _clearLegacyNotificationPrefs() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      // getApplicationDocumentsDirectory() devuelve <app>/app_flutter/
      // el directorio shared_prefs está un nivel arriba: <app>/shared_prefs/
      final file = File(
        '${dir.parent.path}/shared_prefs/scheduled_notifications.xml',
      );
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Si no se puede borrar, continuamos; el try/catch del plugin manejará
      // cualquier error posterior.
    }
  }
}
