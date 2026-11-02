/// Priority of a task. The [value] is what is stored in SQLite.
enum TaskPriority {
  low(0, 'Low'),
  medium(1, 'Medium'),
  high(2, 'High');

  const TaskPriority(this.value, this.label);

  final int value;
  final String label;

  static TaskPriority fromValue(Object? value) {
    final int parsed = value is num ? value.toInt() : 1;
    return TaskPriority.values.firstWhere(
      (priority) => priority.value == parsed,
      orElse: () => TaskPriority.medium,
    );
  }

  static TaskPriority fromName(String? name) {
    return TaskPriority.values.firstWhere(
      (priority) => priority.name == name,
      orElse: () => TaskPriority.medium,
    );
  }
}
