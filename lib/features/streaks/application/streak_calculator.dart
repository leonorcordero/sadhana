class StreakCalculator {
  const StreakCalculator();

  ({int current, int max}) next({
    required int current,
    required int max,
    required bool dayComplete,
  }) {
    final nextCurrent = dayComplete ? current + 1 : 0;
    final nextMax = nextCurrent > max ? nextCurrent : max;
    return (current: nextCurrent, max: nextMax);
  }
}
