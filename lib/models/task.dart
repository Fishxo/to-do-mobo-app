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
    this.reminderAt,
    DateTime? updatedAt,
    this.completedAt,
    this.subtasks = const [],
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
  final DateTime? reminderAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final List<Subtask> subtasks;

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
    final DateTime createdAt = DateTime.parse(createdAtValue);

    return Task(
      id: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      isCompleted: completedValue == 1,
      createdAt: createdAt,
      categoryId: (map['category_id'] as num?)?.toInt(),
      priority: TaskPriority.fromValue(map['priority']),
      dueDate: _parseOptionalDate(map['due_at']),
      reminderAt: _parseOptionalDate(map['reminder_at']),
      updatedAt: _parseOptionalDate(map['updated_at']) ?? createdAt,
      completedAt: _parseOptionalDate(map['completed_at']),
    );
  }

  static DateTime? _parseOptionalDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return null;
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
      'reminder_at': reminderAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      categoryId: (json['categoryId'] as num?)?.toInt(),
      priority: TaskPriority.fromName(json['priority'] as String?),
      dueDate: _parseOptionalDate(json['dueDate']),
      reminderAt: _parseOptionalDate(json['reminderAt']),
      updatedAt: _parseOptionalDate(json['updatedAt']),
      completedAt: _parseOptionalDate(json['completedAt']),
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
      'reminderAt': reminderAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
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
    Object? reminderAt = _unset,
    DateTime? updatedAt,
    Object? completedAt = _unset,
    List<Subtask>? subtasks,
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
      reminderAt: identical(reminderAt, _unset)
          ? this.reminderAt
          : reminderAt as DateTime?,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}
