import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/core/services/daily_closure_service.dart';

void main() {
  final service = DailyClosureService();

  test('retorna tiempo hasta las 23:59 del mismo dia si no ha pasado', () {
    final now = DateTime(2026, 3, 1, 10, 0); // 10:00 am
    final wait = service.timeUntilNextClosure(now);
    expect(wait, const Duration(hours: 13, minutes: 59));
  });

  test('retorna tiempo hasta las 23:59 del dia siguiente si ya paso', () {
    final now = DateTime(2026, 3, 1, 23, 59, 30); // pasadas las 23:59
    final wait = service.timeUntilNextClosure(now);
    // debe apuntar al 23:59 del dia siguiente
    expect(wait.inHours, closeTo(23, 1));
  });

  test('exactamente a las 23:59:00 retorna 0 segundos de espera', () {
    final now = DateTime(2026, 3, 1, 23, 59, 0);
    final wait = service.timeUntilNextClosure(now);
    expect(wait.inSeconds, 0);
  });
}
