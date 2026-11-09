import 'recurrence.dart';
import 'subtask.dart';
import 'task_priority.dart';

/// Task data model.
///
/// This class is deliberately independent from SQLite and from the API.
/// It only knows how to move its data between a Dart object, a SQLite row
/// (`toMap` / `fromMap`) and API JSON (`toJson` / `fromJson`).
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.createdAt,
    this.categoryId,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.endAt,
    this.reminderAt,
    this.isAllDay = false,
    this.recurrence = RecurrencePattern.never,
    this.recurrenceInterval = 1,
    this.recurrenceUnit = RecurrenceUnit.day,
    this.recurrenceWeekdays = const [],
    this.recurrenceEndDate,
    this.recurrenceCount,
    DateTime? updatedAt,
    this.completedAt,
    this.subtasks = const [],
    this.seriesCompleted = false,
    this.seriesCompletedFrom,
  }) : updatedAt = updatedAt ?? createdAt;

  static const Object _unset = Object();

  /// `0` is used for a task that has not been saved yet.
  /// SQLite assigns the real id when the row is inserted.
  final int id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  final int? categoryId;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime? endAt;
  final DateTime? reminderAt;
  final bool isAllDay;
  final RecurrencePattern recurrence;
  final int recurrenceInterval;
  final RecurrenceUnit recurrenceUnit;
  final List<int> recurrenceWeekdays;
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final List<Subtask> subtasks;
  final bool seriesCompleted;
  final DateTime? seriesCompletedFrom;

  bool get isOverdue {
    final DateTime? due = dueDate;
    if (isCompleted || due == null) return false;
    final DateTime now = DateTime.now();
    final DateTime endOfDueDay = DateTime(
      due.year,
      due.month,
      due.day,
    ).add(const Duration(days: 1));
    return now.isAfter(endOfDueDay);
  }

  bool get isDueToday {
    final DateTime? due = dueDate;
    if (due == null) return false;
    final DateTime now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }

  bool get hasReminder => reminderAt != null;

  bool get isRecurring => recurrence != RecurrencePattern.never;

  bool get hasEndTime => !isAllDay && endAt != null;

  DateTime? get effectiveEndAt => isAllDay ? null : endAt;

  String get recurrenceDescription {
    if (recurrence == RecurrencePattern.never) return 'Does not repeat';
    if (recurrence != RecurrencePattern.custom) return recurrence.label;

    final String intervalText = recurrenceInterval == 1
        ? 'Every ${recurrenceUnit.singularLabel}'
        : 'Every $recurrenceInterval ${recurrenceUnit.label.toLowerCase()}';
    if (recurrenceWeekdays.isEmpty) return intervalText;
    final String days = recurrenceWeekdays
        .map(recurrenceWeekdayShortLabel)
        .where((label) => label.isNotEmpty)
        .join(', ');
    return '$intervalText on $days';
  }

  int get completedSubtaskCount =>
      subtasks.where((subtask) => subtask.isCompleted).length;

  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : completedSubtaskCount / subtasks.length;

  /// Creates a Task from a row returned by SQLite.
  ///
  /// SQLite column names use snake_case, and booleans are stored as integers
  /// (`0` = false, `1` = true), so both are converted here.
  factory Task.fromMap(Map<String, dynamic> map) {
    final int completedValue = (map['is_completed'] as num?)?.toInt() ?? 0;
    final String createdAtValue = map['created_at'] as String;
    final DateTime createdAt = DateTime.parse(createdAtValue).toLocal();

    return Task(
      id: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      isCompleted: completedValue == 1,
      createdAt: createdAt,
      categoryId: (map['category_id'] as num?)?.toInt(),
      priority: TaskPriority.fromValue(map['priority']),
      dueDate: _parseOptionalDate(map['due_at']),
      endAt: _parseOptionalDate(map['end_at']),
      reminderAt: _parseOptionalDate(map['reminder_at']),
      isAllDay: _parseBool(map['is_all_day']),
      recurrence: RecurrencePattern.fromValue(map['recurrence']),
      recurrenceInterval: _parseInterval(map['recurrence_interval']),
      recurrenceUnit: RecurrenceUnit.fromValue(map['recurrence_unit']),
      recurrenceWeekdays: _parseWeekdays(map['recurrence_weekdays']),
      recurrenceEndDate: _parseOptionalDate(map['recurrence_end_at']),
      recurrenceCount: (map['recurrence_count'] as num?)?.toInt(),
      updatedAt: _parseOptionalDate(map['updated_at']) ?? createdAt,
      completedAt: _parseOptionalDate(map['completed_at']),
      seriesCompleted: _parseBool(map['series_completed']),
      seriesCompletedFrom: _parseOptionalDate(map['series_completed_from']),
    );
  }

  static DateTime? _parseOptionalDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      // SQLite stores instants as UTC ISO-8601 strings. Task dates are shown
      // and edited as device-local wall time, so restore them in local time.
      return DateTime.parse(value).toLocal();
    }
    return null;
  }

  static bool _parseBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return false;
  }

  static int _parseInterval(Object? value) {
    final int interval = (value as num?)?.toInt() ?? 1;
    return interval < 1 ? 1 : interval;
  }

  static List<int> _parseWeekdays(Object? value) {
    final Set<int> days = <int>{};
    if (value is List) {
      for (final Object? item in value) {
        if (item is num) days.add(item.toInt());
      }
    } else if (value is String && value.trim().isNotEmpty) {
      for (final String part in value.split(',')) {
        final int? day = int.tryParse(part.trim());
        if (day != null) days.add(day);
      }
    }
    final List<int> result = days
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toList()
      ..sort();
    return List<int>.unmodifiable(result);
  }

  /// Converts the Task into a SQLite-compatible map.
  ///
  /// Set [includeId] to `false` when inserting a new row so SQLite can
  /// generate the id with AUTOINCREMENT.
  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'title': title,
      'description': description,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'category_id': categoryId,
      'priority': priority.value,
      'due_at': dueDate?.toUtc().toIso8601String(),
      'end_at': endAt?.toUtc().toIso8601String(),
      'reminder_at': reminderAt?.toUtc().toIso8601String(),
      'is_all_day': isAllDay ? 1 : 0,
      'recurrence': recurrence.value,
      'recurrence_interval': recurrenceInterval,
      'recurrence_unit': recurrenceUnit.value,
      'recurrence_weekdays': recurrenceWeekdays.join(','),
      'recurrence_end_at': recurrenceEndDate?.toUtc().toIso8601String(),
      'recurrence_count': recurrenceCount,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'series_completed': seriesCompleted ? 1 : 0,
      'series_completed_from': seriesCompletedFrom?.toUtc().toIso8601String(),
    };
  }

  /// Creates a Task from API JSON data.
  ///
  /// This is not used yet. It is kept for the future NestJS integration.
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      categoryId: (json['categoryId'] as num?)?.toInt(),
      priority: TaskPriority.fromName(json['priority'] as String?),
      dueDate: _parseOptionalDate(json['dueDate']),
      endAt: _parseOptionalDate(json['endAt']),
      reminderAt: _parseOptionalDate(json['reminderAt']),
      isAllDay: _parseBool(json['isAllDay']),
      recurrence: RecurrencePattern.fromValue(json['recurrence']),
      recurrenceInterval: _parseInterval(json['recurrenceInterval']),
      recurrenceUnit: RecurrenceUnit.fromValue(json['recurrenceUnit']),
      recurrenceWeekdays: _parseWeekdays(json['recurrenceWeekdays']),
      recurrenceEndDate: _parseOptionalDate(json['recurrenceEndDate']),
      recurrenceCount: (json['recurrenceCount'] as num?)?.toInt(),
      updatedAt: _parseOptionalDate(json['updatedAt']),
      completedAt: _parseOptionalDate(json['completedAt']),
      seriesCompleted: _parseBool(json['seriesCompleted']),
      seriesCompletedFrom: _parseOptionalDate(json['seriesCompletedFrom']),
      subtasks: (json['subtasks'] as List<dynamic>? ?? const [])
          .map((item) => Subtask.fromMap(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  /// Converts the Task into API JSON data.
  ///
  /// This is not used yet. It is kept for the future NestJS integration.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'categoryId': categoryId,
      'priority': priority.name,
      'dueDate': dueDate?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'reminderAt': reminderAt?.toIso8601String(),
      'isAllDay': isAllDay,
      'recurrence': recurrence.value,
      'recurrenceInterval': recurrenceInterval,
      'recurrenceUnit': recurrenceUnit.value,
      'recurrenceWeekdays': recurrenceWeekdays,
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'recurrenceCount': recurrenceCount,
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'seriesCompleted': seriesCompleted,
      'seriesCompletedFrom': seriesCompletedFrom?.toIso8601String(),
      'subtasks': subtasks.map((subtask) => subtask.toMap()).toList(),
    };
  }

  /// Returns a copy of the task with the given fields replaced.
  ///
  /// Nullable fields use a sentinel so callers can explicitly clear a value,
  /// for example `task.copyWith(dueDate: null)`.
  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    Object? categoryId = _unset,
    TaskPriority? priority,
    Object? dueDate = _unset,
    Object? endAt = _unset,
    Object? reminderAt = _unset,
    bool? isAllDay,
    RecurrencePattern? recurrence,
    int? recurrenceInterval,
    RecurrenceUnit? recurrenceUnit,
    List<int>? recurrenceWeekdays,
    Object? recurrenceEndDate = _unset,
    Object? recurrenceCount = _unset,
    DateTime? updatedAt,
    Object? completedAt = _unset,
    List<Subtask>? subtasks,
    bool? seriesCompleted,
    Object? seriesCompletedFrom = _unset,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as int?,
      priority: priority ?? this.priority,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      endAt: identical(endAt, _unset) ? this.endAt : endAt as DateTime?,
      reminderAt: identical(reminderAt, _unset)
          ? this.reminderAt
          : reminderAt as DateTime?,
      isAllDay: isAllDay ?? this.isAllDay,
      recurrence: recurrence ?? this.recurrence,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceUnit: recurrenceUnit ?? this.recurrenceUnit,
      recurrenceWeekdays:
          recurrenceWeekdays ?? this.recurrenceWeekdays,
      recurrenceEndDate: identical(recurrenceEndDate, _unset)
          ? this.recurrenceEndDate
          : recurrenceEndDate as DateTime?,
      recurrenceCount: identical(recurrenceCount, _unset)
          ? this.recurrenceCount
          : recurrenceCount as int?,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      subtasks: subtasks ?? this.subtasks,
      seriesCompleted: seriesCompleted ?? this.seriesCompleted,
      seriesCompletedFrom: identical(seriesCompletedFrom, _unset)
          ? this.seriesCompletedFrom
          : seriesCompletedFrom as DateTime?,
    );
  }
}
