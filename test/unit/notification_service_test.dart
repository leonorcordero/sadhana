import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/core/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

class _FakeNotificationsPlugin implements FlutterLocalNotificationsPlugin {
  bool cancelAllCalled = false;
  final List<int> cancelledIds = <int>[];
  final List<int> scheduledIds = <int>[];
  List<PendingNotificationRequest> pending = <PendingNotificationRequest>[];

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    return true;
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return pending;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation
    uiLocalNotificationDateInterpretation,
    bool androidAllowWhileIdle = false,
    AndroidScheduleMode? androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduledIds.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test(
    'reprogramar recordatorios diarios no cancela recordatorios de inicio',
    () async {
      final fakePlugin = _FakeNotificationsPlugin()
        ..pending = <PendingNotificationRequest>[
          const PendingNotificationRequest(100, 'A', 'B', ''),
          const PendingNotificationRequest(500010, 'Start', 'C', ''),
        ];
      final service = NotificationService(plugin: fakePlugin);
      await service.initialize();

      await service.scheduleDailyReminders(hours: const [9, 14], enabled: true);

      expect(fakePlugin.cancelAllCalled, isFalse);
      expect(fakePlugin.cancelledIds, contains(100));
      expect(fakePlugin.cancelledIds, isNot(contains(500010)));
      expect(fakePlugin.scheduledIds, containsAll(<int>[100, 101]));
    },
  );
}
