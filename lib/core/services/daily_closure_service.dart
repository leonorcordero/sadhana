class DailyClosureService {
  Duration timeUntilNextClosure(DateTime now) {
    final target = DateTime(now.year, now.month, now.day, 23, 59);
    final next = now.isAfter(target)
        ? target.add(const Duration(days: 1))
        : target;
    return next.difference(now);
  }
}
