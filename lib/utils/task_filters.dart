import '../models/task.dart';

/// Task filters shared by dashboard cards and task lists.
enum TaskFilter { all, today, upcoming, pending, completed, overdue }

/// A task is pending when it is incomplete and not overdue.
bool isPendingTask(Task task) => !task.isCompleted && !task.isOverdue;

/// Returns the tasks matching a dashboard or list filter.
List<Task> filterTasks(List<Task> tasks, TaskFilter filter) {
  final DateTime now = DateTime.now();
  final DateTime startOfTomorrow = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1));

  Iterable<Task> result;
  switch (filter) {
    case TaskFilter.all:
      result = tasks;
    case TaskFilter.today:
      result = tasks.where((task) {
        final DateTime? due = task.dueDate;
        return due != null &&
            due.year == now.year &&
            due.month == now.month &&
            due.day == now.day;
      });
    case TaskFilter.upcoming:
      result = tasks.where((task) {
        final DateTime? due = task.dueDate;
        return !task.isCompleted && due != null && due.isAfter(startOfTomorrow);
      });
    case TaskFilter.pending:
      result = tasks.where(isPendingTask);
    case TaskFilter.completed:
      result = tasks.where((task) => task.isCompleted);
    case TaskFilter.overdue:
      result = tasks.where((task) => task.isOverdue);
  }

  return result.toList(growable: false);
}
