import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../services/recurrence_service.dart';

class OccurrenceUtils {
  static const RecurrenceService recurrence = RecurrenceService();

  static bool isCompletedFor(
    Task task,
    DateTime occurrenceAt,
    Map<String, TaskOccurrenceState> states,
  ) {
    if (task.seriesCompleted) return true;
    final DateTime at = occurrenceAt.toLocal();
    final DateTime? from = task.seriesCompletedFrom?.toLocal();
    if (from != null) {
      final DateTime normAt = DateTime(at.year, at.month, at.day, at.hour, at.minute, at.second, at.millisecond, at.microsecond);
      final DateTime normFrom = DateTime(from.year, from.month, from.day, from.hour, from.minute, from.second, from.millisecond, from.microsecond);
      if (!normAt.isBefore(normFrom)) return true;
    }
    final TaskOccurrenceState? state = states[TaskOccurrenceState.keyFor(task.id, at)];
    if (state?.isExcluded == true) return false;
    return state?.isCompleted ?? false;
  }

  static List<TaskOccurrence> expandTask(
    Task task, {
    required DateTime from,
    required DateTime until,
    required Map<String, TaskOccurrenceState> states,
  }) {
    if (task.dueDate == null) return const [];

    if (!task.isRecurring) {
      final DateTime at = task.dueDate!.toLocal();
      if (at.isBefore(from) || at.isAfter(until)) return const [];
      return [
        TaskOccurrence(task: task, occurrenceAt: at, isCompleted: task.isCompleted),
      ];
    }

    final List<DateTime> dates = recurrence.occurrences(
      task,
      from: from,
      until: until,
    );
    final List<TaskOccurrence> result = <TaskOccurrence>[];
    for (final DateTime date in dates) {
      final DateTime at = date.toLocal();
      final TaskOccurrenceState? state = states[TaskOccurrenceState.keyFor(task.id, at)];
      if (state?.isExcluded == true) continue;
      result.add(
        TaskOccurrence(
          task: task,
          occurrenceAt: at,
          isCompleted: isCompletedFor(task, at, states),
        ),
      );
    }
    result.sort((a, b) => a.occurrenceAt.compareTo(b.occurrenceAt));
    return result;
  }
}
