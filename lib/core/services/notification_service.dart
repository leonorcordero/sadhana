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

  Future<void> scheduleDailyReminders() async {
    const android = AndroidNotificationDetails(
      'sadhana_reminders',
      'Recordatorios diarios',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    // 3 recordatorios diarios.
    final hours = [9, 14, 20];
    for (var i = 0; i < hours.length; i++) {
      final id = 100 + i;
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        'Sadhana',
        'Tienes tareas pendientes. Cierra tu dia con enfoque.',
        _nextTime(hours[i]),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
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
