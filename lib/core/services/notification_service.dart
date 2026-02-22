import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
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
  }) async {
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

    for (var i = 0; i < normalized.length; i++) {
      final id = 100 + i;
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        'Sadhana',
        'Tienes tareas pendientes. Cierra tu dia con enfoque.',
        _nextTime(normalized[i]),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // Cancela los recordatorios pendientes del dia (usados cuando el usuario
  // completo todas sus tareas antes de que llegue el proximo recordatorio).
  Future<void> cancelDailyReminders() async {
    for (var i = 0; i < 12; i++) {
      await _plugin.cancel(100 + i);
    }
  }

  Future<void> showCompletionNotification() async {
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
}
