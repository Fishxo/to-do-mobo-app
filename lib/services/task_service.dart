import '../models/task.dart';

/// Manages all task data.
///
/// For now everything is stored in memory (nothing survives an app restart).
/// Every task operation of the app goes through this service, so when the
/// backend is ready these methods can be replaced by HTTP calls
/// without changing the UI code.
class TaskService {
  TaskService._() {
    _tasks.addAll(_sampleTasks());
    _nextId = _tasks.length + 1;
  }

  /// Single shared instance so every screen works with the same task list.
  static final TaskService instance = TaskService._();

  final List<Task> _tasks = [];
  int _nextId = 1;

  /// Returns all tasks.
  Future<List<Task>> getTasks() async {
    return List<Task>.from(_tasks);
  }

  /// Creates a new task.
  Future<Task> addTask({
    required String title,
    String description = '',
  }) async {
    final task = Task(
      id: _nextId++,
      title: title,
      description: description,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
    _tasks.add(task);
    return task;
  }

  /// Updates the title and description of an existing task.
  Future<Task> updateTask(
    int id, {
    required String title,
    required String description,
  }) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) {
      throw StateError('Task with id $id was not found');
    }
    final updated = _tasks[index].copyWith(
      title: title,
      description: description,
    );
    _tasks[index] = updated;
    return updated;
  }

  /// Removes a task.
  Future<void> deleteTask(int id) async {
    _tasks.removeWhere((task) => task.id == id);
  }

  /// Switches a task between active and completed.
  Future<Task> toggleTask(int id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) {
      throw StateError('Task with id $id was not found');
    }
    final updated = _tasks[index].copyWith(
      isCompleted: !_tasks[index].isCompleted,
    );
    _tasks[index] = updated;
    return updated;
  }

  /// A few sample tasks so the app is not empty on first launch.
  List<Task> _sampleTasks() {
    final now = DateTime.now();
    return [
      Task(
        id: 1,
        title: 'Study Flutter',
        description: 'Learn widgets and navigation',
        isCompleted: true,
        createdAt: now,
      ),
      Task(
        id: 2,
        title: 'Build To-Do UI',
        description: 'Create the first mobile interface',
        isCompleted: false,
        createdAt: now,
      ),
      Task(
        id: 3,
        title: 'Connect API',
        description: 'Later connect the Flutter app to the backend',
        isCompleted: false,
        createdAt: now,
      ),
    ];
  }
}
