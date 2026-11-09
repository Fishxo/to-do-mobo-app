import 'package:intl/intl.dart';

import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../models/task_priority.dart';
import '../utils/occurrence_utils.dart';

/// The reporting periods offered by the Reports & Insights section.
enum ReportPeriod { weekly, monthly, yearly }

extension ReportPeriodInfo on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.weekly:
        return 'Weekly';
      case ReportPeriod.monthly:
        return 'Monthly';
      case ReportPeriod.yearly:
        return 'Yearly';
    }
  }
}

/// How a task is represented inside a report.
enum ReportTaskStatus { completed, pending, overdue }

extension ReportTaskStatusInfo on ReportTaskStatus {
  String get label {
    switch (this) {
      case ReportTaskStatus.completed:
        return 'Completed';
      case ReportTaskStatus.pending:
        return 'Pending';
      case ReportTaskStatus.overdue:
        return 'Overdue';
    }
  }
}

/// A half-open date range: [start] is included, [end] is not.
class ReportRange {
  const ReportRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    return !date.isBefore(start) && date.isBefore(end);
  }
}

/// One bucket in the created/completed activity chart.
class ReportActivityPoint {
  const ReportActivityPoint({
    required this.date,
    required this.label,
    required this.created,
    required this.completed,
  });

  final DateTime date;
  final String label;
  final int created;
  final int completed;
}

/// A task together with the date and status used in a report.
class ReportTaskEntry {
  const ReportTaskEntry({
    required this.task,
    required this.date,
    required this.status,
  });

  final Task task;
  final DateTime date;
  final ReportTaskStatus status;
}

/// Read-only report calculated from the tasks already stored in SQLite.
class TaskReport {
  const TaskReport({
    required this.period,
    required this.range,
    required this.isCurrent,
    required this.entries,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.byPriority,
    required this.activity,
  });

  final ReportPeriod period;
  final ReportRange range;
  final bool isCurrent;
  final List<ReportTaskEntry> entries;
  final int completed;
  final int pending;
  final int overdue;
  final Map<TaskPriority, int> byPriority;
  final List<ReportActivityPoint> activity;

  int get total => entries.length;

  int get completionPercentage =>
      total == 0 ? 0 : ((completed / total) * 100).round();

  double get completionRate => total == 0 ? 0 : completed / total;

  int get createdActivity =>
      activity.fold(0, (sum, item) => sum + item.created);

  int get completedActivity =>
      activity.fold(0, (sum, item) => sum + item.completed);
}

class ReportService {
  const ReportService();

  ReportRange rangeFor(
    ReportPeriod period,
    DateTime anchor, {
    int startOfWeek = DateTime.monday,
  }) {
    final DateTime day = DateTime(anchor.year, anchor.month, anchor.day);

    switch (period) {
      case ReportPeriod.weekly:
        final int daysFromStart = (day.weekday - startOfWeek + 7) % 7;
        final DateTime start = day.subtract(Duration(days: daysFromStart));
        return ReportRange(
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case ReportPeriod.monthly:
        return ReportRange(
          start: DateTime(day.year, day.month, 1),
          end: DateTime(day.year, day.month + 1, 1),
        );
      case ReportPeriod.yearly:
        return ReportRange(
          start: DateTime(day.year, 1, 1),
          end: DateTime(day.year + 1, 1, 1),
        );
    }
  }

  bool isCurrentPeriod(
    ReportPeriod period,
    DateTime anchor, {
    int startOfWeek = DateTime.monday,
    DateTime? now,
  }) {
    final ReportRange range = rangeFor(
      period,
      anchor,
      startOfWeek: startOfWeek,
    );
    return range.contains((now ?? DateTime.now()).toLocal());
  }

  TaskReport calculate({
    required List<Task> tasks,
    required ReportPeriod period,
    required DateTime anchor,
    int startOfWeek = DateTime.monday,
    Map<String, TaskOccurrenceState> occurrenceStates = const {},
  }) {
    final ReportRange range = rangeFor(
      period,
      anchor,
      startOfWeek: startOfWeek,
    );

    final List<ReportTaskEntry> entries = [];
    int completed = 0;
    int pending = 0;
    int overdue = 0;
    final Map<TaskPriority, int> byPriority = {};
    final DateTime now = DateTime.now();

    for (final Task task in tasks) {
      final DateTime? dueDate = task.dueDate;

      if (dueDate == null) {
        final DateTime reportDate = task.createdAt.toLocal();
        if (!range.contains(reportDate)) continue;
        final ReportTaskStatus status = _statusFor(
          task,
          reportDate,
          now,
          isCompleted: task.isCompleted,
          hasDueDate: false,
        );
        _addStatus(status, onCompleted: () => completed++, onPending: () => pending++, onOverdue: () => overdue++);
        byPriority[task.priority] = (byPriority[task.priority] ?? 0) + 1;
        entries.add(ReportTaskEntry(task: task, date: reportDate, status: status));
        continue;
      }

      if (task.isRecurring) {
        final List<TaskOccurrence> occurrences = OccurrenceUtils.expandTask(
          task,
          from: range.start,
          until: range.end.subtract(const Duration(microseconds: 1)),
          states: occurrenceStates,
        );
        for (final TaskOccurrence occurrence in occurrences) {
          final DateTime reportDate = occurrence.occurrenceAt.toLocal();
          if (!range.contains(reportDate)) continue;
          final ReportTaskStatus status = _statusFor(
            task,
            reportDate,
            now,
            isCompleted: occurrence.isCompleted,
            hasDueDate: true,
            isAllDay: task.isAllDay,
          );
          _addStatus(status, onCompleted: () => completed++, onPending: () => pending++, onOverdue: () => overdue++);
          byPriority[task.priority] = (byPriority[task.priority] ?? 0) + 1;
          entries.add(ReportTaskEntry(task: task, date: reportDate, status: status));
        }
        continue;
      }

      final DateTime reportDate = dueDate.toLocal();
      if (!range.contains(reportDate)) continue;
      final ReportTaskStatus status = _statusFor(
        task,
        reportDate,
        now,
        isCompleted: task.isCompleted,
        hasDueDate: true,
        isAllDay: task.isAllDay,
      );
      _addStatus(status, onCompleted: () => completed++, onPending: () => pending++, onOverdue: () => overdue++);
      byPriority[task.priority] = (byPriority[task.priority] ?? 0) + 1;
      entries.add(ReportTaskEntry(task: task, date: reportDate, status: status));
    }

    entries.sort((a, b) {
      final int byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.task.priority.value.compareTo(a.task.priority.value);
    });

    return TaskReport(
      period: period,
      range: range,
      isCurrent: range.contains(DateTime.now().toLocal()),
      entries: entries,
      completed: completed,
      pending: pending,
      overdue: overdue,
      byPriority: byPriority,
      activity: _activityFor(tasks, range, period),
    );
  }

  void _addStatus(
    ReportTaskStatus status, {
    required void Function() onCompleted,
    required void Function() onPending,
    required void Function() onOverdue,
  }) {
    switch (status) {
      case ReportTaskStatus.completed:
        onCompleted();
        break;
      case ReportTaskStatus.pending:
        onPending();
        break;
      case ReportTaskStatus.overdue:
        onOverdue();
        break;
    }
  }

  ReportTaskStatus _statusFor(
    Task task,
    DateTime date,
    DateTime now, {
    required bool isCompleted,
    required bool hasDueDate,
    bool isAllDay = false,
  }) {
    if (isCompleted) return ReportTaskStatus.completed;
    if (!hasDueDate) return ReportTaskStatus.pending;
    final DateTime endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(const Duration(days: 1));
    if (now.isAfter(endOfDay)) return ReportTaskStatus.overdue;
    return ReportTaskStatus.pending;
  }

  List<ReportActivityPoint> _activityFor(
    List<Task> tasks,
    ReportRange range,
    ReportPeriod period,
  ) {
    final List<_ActivityBucket> buckets = _bucketsFor(range, period);
    final List<int> created = List<int>.filled(buckets.length, 0);
    final List<int> completed = List<int>.filled(buckets.length, 0);

    for (final Task task in tasks) {
      final DateTime createdAt = task.createdAt.toLocal();
      if (range.contains(createdAt)) {
        final int index = _bucketIndex(buckets, createdAt);
        if (index != -1) created[index]++;
      }

      if (task.isCompleted) {
        final DateTime completedAt = (task.completedAt ?? task.updatedAt)
            .toLocal();
        if (range.contains(completedAt)) {
          final int index = _bucketIndex(buckets, completedAt);
          if (index != -1) completed[index]++;
        }
      }
    }

    return List<ReportActivityPoint>.generate(buckets.length, (index) {
      final _ActivityBucket bucket = buckets[index];
      return ReportActivityPoint(
        date: bucket.start,
        label: _bucketLabel(bucket, period),
        created: created[index],
        completed: completed[index],
      );
    }, growable: false);
  }

  List<_ActivityBucket> _bucketsFor(ReportRange range, ReportPeriod period) {
    switch (period) {
      case ReportPeriod.weekly:
        return List<_ActivityBucket>.generate(7, (index) {
          final DateTime start = range.start.add(Duration(days: index));
          return _ActivityBucket(
            start: start,
            end: start.add(const Duration(days: 1)),
          );
        }, growable: false);
      case ReportPeriod.monthly:
        final int daysInMonth = range.end.subtract(const Duration(days: 1)).day;
        final int bucketCount = ((daysInMonth - 1) ~/ 7) + 1;
        return List<_ActivityBucket>.generate(bucketCount, (index) {
          final DateTime start = range.start.add(Duration(days: index * 7));
          DateTime end = start.add(const Duration(days: 7));
          if (end.isAfter(range.end)) end = range.end;
          return _ActivityBucket(start: start, end: end);
        }, growable: false);
      case ReportPeriod.yearly:
        return List<_ActivityBucket>.generate(12, (index) {
          final DateTime start = DateTime(range.start.year, index + 1, 1);
          return _ActivityBucket(
            start: start,
            end: DateTime(range.start.year, index + 2, 1),
          );
        }, growable: false);
    }
  }

  int _bucketIndex(List<_ActivityBucket> buckets, DateTime date) {
    for (int index = 0; index < buckets.length; index++) {
      if (!date.isBefore(buckets[index].start) &&
          date.isBefore(buckets[index].end)) {
        return index;
      }
    }
    return -1;
  }

  String _bucketLabel(_ActivityBucket bucket, ReportPeriod period) {
    switch (period) {
      case ReportPeriod.weekly:
        return DateFormat('E').format(bucket.start).substring(0, 1);
      case ReportPeriod.monthly:
        final int lastDay = bucket.end.subtract(const Duration(days: 1)).day;
        return '${bucket.start.day}-$lastDay';
      case ReportPeriod.yearly:
        return DateFormat('MMM').format(bucket.start);
    }
  }
}

class _ActivityBucket {
  const _ActivityBucket({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
