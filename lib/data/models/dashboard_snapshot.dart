import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';

class DashboardSnapshot {
  DashboardSnapshot({
    required this.activeCycle,
    required this.tasks,
    required this.todayLog,
    required this.completionRatio,
  });

  final CycleModel? activeCycle;
  final List<TaskModel> tasks;
  final DayLogModel? todayLog;
  final double completionRatio;
}
