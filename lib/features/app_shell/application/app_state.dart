import 'package:sadhana/data/models/cycle_model.dart';
import 'package:sadhana/data/models/day_log_model.dart';
import 'package:sadhana/data/models/task_model.dart';

class AppState {
  const AppState({
    required this.cycles,
    required this.tasks,
    required this.logs,
    required this.selectedDate,
    required this.error,
  });

  factory AppState.initial() {
    final now = DateTime.now();
    return AppState(
      cycles: const [],
      tasks: const [],
      logs: const [],
      selectedDate: DateTime(now.year, now.month, now.day),
      error: null,
    );
  }

  final List<CycleModel> cycles;
  final List<TaskModel> tasks;
  final List<DayLogModel> logs;
  final DateTime selectedDate;
  final String? error;

  List<CycleModel> get activeCycles => cycles.where((c) => c.isActive).toList();

  CycleModel? get activeCycle => activeCycles.firstOrNull;

  AppState copyWith({
    List<CycleModel>? cycles,
    List<TaskModel>? tasks,
    List<DayLogModel>? logs,
    DateTime? selectedDate,
    String? error,
    bool clearError = false,
  }) {
    return AppState(
      cycles: cycles ?? this.cycles,
      tasks: tasks ?? this.tasks,
      logs: logs ?? this.logs,
      selectedDate: selectedDate ?? this.selectedDate,
      error: clearError ? null : error ?? this.error,
    );
  }
}
