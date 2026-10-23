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
  });

  /// `0` is used for a task that has not been saved yet.
  /// SQLite assigns the real id when the row is inserted.
  final int id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;

  /// Creates a Task from a row returned by SQLite.
  ///
  /// SQLite column names use snake_case, and booleans are stored as integers
  /// (`0` = false, `1` = true), so both are converted here.
  factory Task.fromMap(Map<String, dynamic> map) {
    final int completedValue = (map['is_completed'] as num?)?.toInt() ?? 0;

    return Task(
      id: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      isCompleted: completedValue == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
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
    };
  }

  /// Returns a copy of the task with the given fields replaced.
  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
