import '../models/task.dart';
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

  /// Returns every saved task, newest last.
  Future<List<Task>> getTasks() {
    return _store.getTasks();
  }

  /// Creates and saves a new task. SQLite assigns the real id.
  Future<Task> addTask({required String title, String? description}) {
    final String trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Title cannot be empty');
    }

    final Task task = Task(
      id: 0,
      title: trimmedTitle,
      description: description?.trim() ?? '',
      isCompleted: false,
      createdAt: DateTime.now(),
    );

    return _store.insertTask(task);
  }

  /// Finds one task by id, or returns `null` when it does not exist.
  Future<Task?> getTaskById(int id) {
    return _store.getTaskById(id);
  }

  /// Saves changes to an existing task.
  Future<void> updateTask(Task task) {
    return _store.updateTask(task);
  }

  /// Deletes a task by id.
  Future<void> deleteTask(int id) {
    return _store.deleteTask(id);
  }

  /// Flips a task between active and completed and saves the new value.
  Future<Task> toggleTask(int id) async {
    final Task? task = await _store.getTaskById(id);
    if (task == null) {
      throw StateError('Task with id $id was not found');
    }

    final Task updated = task.copyWith(isCompleted: !task.isCompleted);
    await _store.updateTask(updated);
    return updated;
  }
}
