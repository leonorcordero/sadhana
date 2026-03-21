import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:sadhana/core/constants/app_constants.dart';
import 'package:sadhana/core/utils/date_utils.dart';
import 'package:sadhana/data/models/cycle_model.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _dailyReminderBaseId = 100;
  static const _dailyReminderRange = 50000;
  static const _startReminderBaseId = 500000;
  static const _startReminderRange = 50000;
  final FlutterLocalNotificationsPlugin _plugin;
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

    try {
      await cancelDailyReminders();
    } on PlatformException {
      // Si aún falla (p. ej. datos viejos en caché), continuamos.
    }

    final body = _buildReminderBody(
      contentType: contentType,
      customText: customText,
    );

    for (var i = 0; i < normalized.length; i++) {
      final id = _dailyReminderBaseId + i;
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
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final req in pending) {
        final id = req.id;
        if (id < _dailyReminderBaseId) continue;
        if (id >= _dailyReminderBaseId + _dailyReminderRange) continue;
        await _plugin.cancel(id);
      }
    } on PlatformException {
      // Silencioso si los datos guardados son incompatibles.
    } catch (_) {}
    // Compatibilidad defensiva para instalaciones viejas.
    for (var i = 0; i < 12; i++) {
      try {
        await _plugin.cancel(_dailyReminderBaseId + i);
      } catch (_) {}
    }
  }

  Future<void> scheduleMandalaStartReminders({
    required List<CycleModel> cycles,
    required bool enabled,
  }) async {
    if (_isWeb) return;
    try {
      await _cancelExistingMandalaStartReminders();
      if (!enabled) return;
      const android = AndroidNotificationDetails(
        'sadhana_start_reminders',
        'Recordatorios de inicio',
        importance: Importance.high,
        priority: Priority.high,
      );
      const ios = DarwinNotificationDetails();
      const details = NotificationDetails(android: android, iOS: ios);
      final now = tz.TZDateTime.now(tz.local);
      for (final cycle in cycles) {
        if (cycle.isActive) continue;
        final plannedKey = cycle.plannedStartDateKey?.trim();
        if (plannedKey == null || plannedKey.isEmpty) continue;
        DateTime plannedDate;
        try {
          plannedDate = DateUtilsX.fromDateKey(plannedKey);
        } catch (_) {
          continue;
        }
        final previousDay = tz.TZDateTime(
          tz.local,
          plannedDate.year,
          plannedDate.month,
          plannedDate.day,
          19,
        ).subtract(const Duration(days: 1));
        final startMorning = tz.TZDateTime(
          tz.local,
          plannedDate.year,
          plannedDate.month,
          plannedDate.day,
          8,
        );
        if (previousDay.isAfter(now)) {
          await _scheduleStartReminder(
            id: _startReminderId(cycle.id, slot: 1),
            when: previousDay,
            details: details,
            title: 'Mañana inicia tu mandala',
            body: '${cycle.name} comienza mañana. Deja lista tu práctica.',
          );
        }
        if (startMorning.isAfter(now)) {
          await _scheduleStartReminder(
            id: _startReminderId(cycle.id, slot: 2),
            when: startMorning,
            details: details,
            title: 'Hoy inicia tu mandala',
            body: '${cycle.name} inicia hoy. Actívalo manualmente y comienza.',
          );
        }
      }
    } catch (_) {
      // No bloquea la app si fallan notificaciones.
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

  Future<void> _scheduleStartReminder({
    required int id,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') return;
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _cancelExistingMandalaStartReminders() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final req in pending) {
        final id = req.id;
        if (id < _startReminderBaseId) continue;
        if (id >= _startReminderBaseId + _startReminderRange) continue;
        await _plugin.cancel(id);
      }
    } catch (_) {}
  }

  int _startReminderId(String cycleId, {required int slot}) {
    final hash = _stableHash(cycleId);
    final perCycle = (hash % (_startReminderRange ~/ 2)) * 2;
    return _startReminderBaseId + perCycle + (slot % 2);
  }

  int _stableHash(String input) {
    var hash = 2166136261;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}
