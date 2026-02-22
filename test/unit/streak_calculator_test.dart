import 'package:flutter_test/flutter_test.dart';
import 'package:sadhana/features/streaks/application/streak_calculator.dart';

void main() {
  test('streak increments and updates max', () {
    const calc = StreakCalculator();
    final result = calc.next(current: 2, max: 2, dayComplete: true);

    expect(result.current, 3);
    expect(result.max, 3);
  });

  test('streak resets when day incomplete', () {
    const calc = StreakCalculator();
    final result = calc.next(current: 4, max: 7, dayComplete: false);

    expect(result.current, 0);
    expect(result.max, 7);
  });
}
