import '../models/recurrence.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../models/task_priority.dart';
import 'database_service.dart';

/// The single entry point for task operations.
///
/// The UI only calls this class. It does not know whether the data comes from
/// SQLite today or from a future REST API. Because the storage is hidden behind
/// [TaskStore], an API data source can be added later without touching widgets.
class TaskService {
  TaskService({TaskStore? store}) : _store = store ?? DatabaseService.instance;

  /// Shared instance used by the screens in the real app.
  static final TaskService instance = TaskService();

  final TaskStore _store;

  /// Exposes the shared store so the category service can use the same
  /// database (or the same in-memory store in tests).
  TaskStore get store => _store;

  /// Returns every saved task, newest last, including their subtasks.
  Future<List<Task>> getTasks() {
    return _store.getTasks();
  }

  /// Finds one task by id, or returns `null` when it does not exist.
  Future<Task?> getTaskById(int id) {
    return _store.getTaskById(id);
  }

  /// Creates and saves a new task. SQLite assigns the real id.
  Future<Task> addTask({
    required String title,
    String? description,
    int? categoryId,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    DateTime? endAt,
    DateTime? reminderAt,
    bool isAllDay = false,
    RecurrencePattern recurrence = RecurrencePattern.never,
    int recurrenceInterval = 1,
    RecurrenceUnit recurrenceUnit = RecurrenceUnit.day,
    List<int> recurrenceWeekdays = const [],
    DateTime? recurrenceEndDate,
    int? recurrenceCount,
    List<String> subtaskTitles = const [],
  }) async {
    final String trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Title cannot be empty');
    }

    final DateTime now = DateTime.now();
    final Task task = Task(
      id: 0,
      title: trimmedTitle,
      description: description?.trim() ?? '',
      isCompleted: false,
      createdAt: now,
      categoryId: categoryId,
      priority: priority,
      dueDate: dueDate,
      endAt: endAt,
      reminderAt: reminderAt,
      isAllDay: isAllDay,
      recurrence: recurrence,
      recurrenceInterval: recurrenceInterval,
      recurrenceUnit: recurrenceUnit,
      recurrenceWeekdays: recurrenceWeekdays,
      recurrenceEndDate: recurrenceEndDate,
      recurrenceCount: recurrenceCount,
      updatedAt: now,
    );

    final Task saved = await _store.insertTask(task);
    final List<Subtask> subtasks = [];

    for (final String subtaskTitle in subtaskTitles) {
      final String trimmed = subtaskTitle.trim();
      if (trimmed.isEmpty) continue;
      subtasks.add(
        await _store.insertSubtask(
          Subtask(
            id: 0,
            taskId: saved.id,
            title: trimmed,
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
        ),
      );
    }

    return saved.copyWith(subtasks: subtasks);
  }

  /// Saves changes to an existing task.
  Future<void> updateTask(Task task) async {
    final String trimmedTitle = task.title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(task.title, 'title', 'Title cannot be empty');
    }

    final DateTime now = DateTime.now();
    await _store.updateTask(
      task.copyWith(
        title: trimmedTitle,
        description: task.description.trim(),
        updatedAt: now,
        completedAt: task.isCompleted ? task.completedAt ?? now : null,
      ),
    );
  }

  /// Deletes a task by id. Its subtasks are removed by the database cascade.
  Future<void> deleteTask(int id) {
    return _store.deleteTask(id);
  }

  /// Flips a task between active and completed and saves the new value.
  Future<Task> toggleTask(int id) async {
    final Task? task = await _store.getTaskById(id);
    if (task == null) {
      throw StateError('Task with id $id was not found');
    }

    final DateTime now = DateTime.now();
    final bool completed = !task.isCompleted;
    final Task updated = task.copyWith(
      isCompleted: completed,
      completedAt: completed ? now : null,
      updatedAt: now,
    );
    await _store.updateTask(updated);
    return updated;
  }

  /// Inserts a task from an import file. The id is always regenerated so the
  /// import cannot overwrite existing rows.
  Future<Task> importTask(Task task) async {
    final Task saved = await _store.insertTask(task.copyWith(id: 0));
    final List<Subtask> subtasks = [];

    for (final Subtask subtask in task.subtasks) {
      subtasks.add(
        await _store.insertSubtask(
          Subtask(
            id: 0,
            taskId: saved.id,
            title: subtask.title,
            isCompleted: subtask.isCompleted,
            createdAt: subtask.createdAt,
          ),
        ),
      );
    }

    return saved.copyWith(subtasks: subtasks);
  }

  Future<Subtask> addSubtask({
    required int taskId,
    required String title,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Subtask title cannot be empty',
      );
    }

    return _store.insertSubtask(
      Subtask(
        id: 0,
        taskId: taskId,
        title: trimmed,
        isCompleted: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> toggleSubtask(Subtask subtask) {
    return _store.updateSubtask(
      subtask.copyWith(isCompleted: !subtask.isCompleted),
    );
  }

  Future<void> deleteSubtask(int subtaskId) {
    return _store.deleteSubtask(subtaskId);
  }

  Future<void> clearCompletedTasks() {
    return _store.clearCompletedTasks();
  }

  Future<List<TaskOccurrenceState>> getOccurrenceStates() {
    return _store.getOccurrenceStates();
  }

  Future<void> setOccurrenceCompleted(
    int taskId,
    DateTime occurrenceAt,
    bool isCompleted,
  ) {
    return _store.setOccurrenceCompleted(taskId, occurrenceAt, isCompleted);
  }

  Future<void> setOccurrenceExcluded(int taskId, DateTime occurrenceAt) {
    return _store.setOccurrenceExcluded(taskId, occurrenceAt);
  }

  Future<void> setOccurrenceSeriesCompletedFrom(
    int taskId,
    DateTime occurrenceAt,
    bool isCompleted,
  ) {
    return _store.setOccurrenceSeriesCompletedFrom(
      taskId,
      occurrenceAt,
      isCompleted,
    );
  }

  Future<void> setSeriesCompleted(int taskId, bool isCompleted) {
    return _store.setSeriesCompleted(taskId, isCompleted);
  }
}
