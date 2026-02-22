import 'package:sadhana/core/services/notification_service.dart';

class NotificationCoordinator {
  NotificationCoordinator(this._service);

  final NotificationService _service;

  Future<void> bootstrap() => _service.initialize();
}
