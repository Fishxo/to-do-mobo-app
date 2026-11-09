import 'task.dart';

class TaskOccurrenceState {
  const TaskOccurrenceState({
    required this.taskId,
    required this.occurrenceAt,
    this.isCompleted = false,
    this.isExcluded = false,
    this.completedAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? occurrenceAt;

  final int taskId;
  final DateTime occurrenceAt;
  final bool isCompleted;
  final bool isExcluded;
  final DateTime? completedAt;
  final DateTime updatedAt;

  static DateTime normalize(DateTime value) => value.toUtc();

  static String keyFor(int taskId, DateTime occurrenceAt) {
    return '$taskId|${normalize(occurrenceAt).toIso8601String()}';
  }

  String get key => keyFor(taskId, occurrenceAt);

  factory TaskOccurrenceState.fromMap(Map<String, dynamic> map) {
    final DateTime occurrenceAt = DateTime.parse(
      map['occurrence_at'] as String,
    );
    return TaskOccurrenceState(
      taskId: (map['task_id'] as num).toInt(),
      occurrenceAt: occurrenceAt,
      isCompleted: (map['is_completed'] as num?)?.toInt() == 1,
      isExcluded: (map['is_excluded'] as num?)?.toInt() == 1,
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
      updatedAt: map['updated_at'] == null
          ? DateTime.now().toUtc()
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'task_id': taskId,
      'occurrence_at': normalize(occurrenceAt).toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'is_excluded': isExcluded ? 1 : 0,
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  TaskOccurrenceState copyWith({
    int? taskId,
    DateTime? occurrenceAt,
    bool? isCompleted,
    bool? isExcluded,
    Object? completedAt = _unset,
    DateTime? updatedAt,
  }) {
    return TaskOccurrenceState(
      taskId: taskId ?? this.taskId,
      occurrenceAt: occurrenceAt ?? this.occurrenceAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isExcluded: isExcluded ?? this.isExcluded,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _unset = Object();
}

class TaskOccurrence {
  const TaskOccurrence({
    required this.task,
    required this.occurrenceAt,
    this.isCompleted = false,
  });

  final Task task;
  final DateTime occurrenceAt;
  final bool isCompleted;

  bool get isRecurring => task.isRecurring;

  DateTime? get endAt {
    if (task.isAllDay || task.endAt == null || task.dueDate == null) return null;
    final Duration duration = task.endAt!.difference(task.dueDate!);
    if (duration.isNegative) return null;
    return occurrenceAt.add(duration);
  }

  bool get isOverdue {
    if (isCompleted) return false;
    final DateTime now = DateTime.now();
    if (task.isAllDay) {
      final DateTime endOfDay = DateTime(
        occurrenceAt.year,
        occurrenceAt.month,
        occurrenceAt.day,
      ).add(const Duration(days: 1));
      return now.isAfter(endOfDay);
    }
    final DateTime? end = endAt ?? task.dueDate;
    final DateTime reference = end ?? occurrenceAt;
    return now.isAfter(reference);
  }

  bool get isPending => !isCompleted && !isOverdue;
}
