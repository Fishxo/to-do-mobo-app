import '../models/task.dart';

/// One day in the completion history chart.
class DailyTaskActivity {
  const DailyTaskActivity({
    required this.date,
    required this.created,
    required this.completed,
  });

  final DateTime date;
  final int created;
  final int completed;
}

/// Read-only statistics calculated from real task records.
class TaskStatistics {
  const TaskStatistics({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.weeklyCompletionPercentage,
    required this.weeklyDueTasks,
    required this.weeklyCompletedDueTasks,
    required this.lastSevenDays,
  });

  final int total;
  final int completed;
  final int pending;
  final int overdue;
  final int weeklyCompletionPercentage;
  final int weeklyDueTasks;
  final int weeklyCompletedDueTasks;
  final List<DailyTaskActivity> lastSevenDays;

  double get completionRate => total == 0 ? 0 : completed / total;
}

class StatisticsService {
  const StatisticsService();

  TaskStatistics calculate(List<Task> tasks) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime weekStart = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );

    int completed = 0;
    int overdue = 0;
    int dueThisWeek = 0;
    int completedDueThisWeek = 0;

    final Map<DateTime, int> createdByDay = {};
    final Map<DateTime, int> completedByDay = {};

    for (final Task task in tasks) {
      if (task.isCompleted) {
        completed++;
      } else if (task.isOverdue) {
        overdue++;
      }

      final DateTime? dueDate = task.dueDate;
      if (dueDate != null && !dueDate.isBefore(weekStart)) {
        dueThisWeek++;
        if (task.isCompleted) completedDueThisWeek++;
      }

      final DateTime createdDay = DateTime(
        task.createdAt.year,
        task.createdAt.month,
        task.createdAt.day,
      );
      createdByDay[createdDay] = (createdByDay[createdDay] ?? 0) + 1;

      if (task.isCompleted) {
        final DateTime completedAt = task.completedAt ?? task.updatedAt;
        final DateTime completedDay = DateTime(
          completedAt.year,
          completedAt.month,
          completedAt.day,
        );
        completedByDay[completedDay] = (completedByDay[completedDay] ?? 0) + 1;
      }
    }

    final int weeklyPercentage;
    if (dueThisWeek > 0) {
      weeklyPercentage = ((completedDueThisWeek / dueThisWeek) * 100).round();
    } else if (tasks.isNotEmpty) {
      weeklyPercentage = ((completed / tasks.length) * 100).round();
    } else {
      weeklyPercentage = 0;
    }

    final List<DailyTaskActivity> history = List.generate(7, (index) {
      final DateTime day = today.subtract(Duration(days: 6 - index));
      return DailyTaskActivity(
        date: day,
        created: createdByDay[day] ?? 0,
        completed: completedByDay[day] ?? 0,
      );
    });

    return TaskStatistics(
      total: tasks.length,
      completed: completed,
      pending: tasks.length - completed,
      overdue: overdue,
      weeklyCompletionPercentage: weeklyPercentage,
      weeklyDueTasks: dueThisWeek,
      weeklyCompletedDueTasks: completedDueThisWeek,
      lastSevenDays: history,
    );
  }
}
