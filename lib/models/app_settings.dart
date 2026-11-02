import 'package:flutter/material.dart';

import 'task_priority.dart';

/// How the task list is ordered by default.
enum TaskSortOption {
  dueDate('Due date'),
  priority('Priority'),
  createdDate('Creation date');

  const TaskSortOption(this.label);

  final String label;

  static TaskSortOption fromName(String? name) {
    return TaskSortOption.values.firstWhere(
      (option) => option.name == name,
      orElse: () => TaskSortOption.dueDate,
    );
  }
}

/// User preferences persisted outside SQLite (in shared preferences).
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.defaultPriority = TaskPriority.medium,
    this.startOfWeek = DateTime.monday,
    this.sortOption = TaskSortOption.dueDate,
  });

  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final TaskPriority defaultPriority;

  /// ISO weekday number (1 = Monday, 7 = Sunday).
  final int startOfWeek;
  final TaskSortOption sortOption;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    TaskPriority? defaultPriority,
    int? startOfWeek,
    TaskSortOption? sortOption,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      startOfWeek: startOfWeek ?? this.startOfWeek,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}
