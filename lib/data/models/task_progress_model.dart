class TaskProgressModel {
  const TaskProgressModel({
    required this.taskId,
    required this.totalTrackedDays,
    required this.completedDays,
    required this.failedDays,
    required this.currentStreak,
    required this.maxStreak,
  });

  final String taskId;
  final int totalTrackedDays;
  final int completedDays;
  final int failedDays;
  final int currentStreak;
  final int maxStreak;

  double get completionRate =>
      totalTrackedDays == 0 ? 0 : completedDays / totalTrackedDays;
}
