import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/models/category.dart';
import 'package:todoapp/models/recurrence.dart';
import 'package:todoapp/models/subtask.dart';
import 'package:todoapp/models/task.dart';
import 'package:todoapp/models/task_occurrence.dart';
import 'package:todoapp/services/database_service.dart';
import 'package:todoapp/services/task_service.dart';

class _MemoryTaskStore implements TaskStore {
  final List<Task> _tasks = [];
  final Map<String, TaskOccurrenceState> _states = {};
  int _nextId = 1;

  @override
  Future<List<Task>> getTasks() async => List.unmodifiable(_tasks);
  @override
  Future<Task?> getTaskById(int id) async {
    for (final Task task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }
  @override
  Future<Task> insertTask(Task task) async {
    final saved = task.copyWith(id: _nextId++);
    _tasks.add(saved);
    return saved;
  }
  @override
  Future<void> updateTask(Task task) async {
    final i = _tasks.indexWhere((t) => t.id == task.id);
    if (i >= 0) _tasks[i] = task;
  }
  @override
  Future<void> deleteTask(int id) async => _tasks.removeWhere((t) => t.id == id);
  @override Future<List<Category>> getCategories() async => const [];
  @override Future<Category> insertCategory(Category category) async => category;
  @override Future<void> updateCategory(Category category) async {}
  @override Future<void> deleteCategory(int id) async {}
  @override Future<List<Subtask>> getSubtasksForTask(int taskId) async => const [];
  @override Future<Subtask> insertSubtask(Subtask subtask) async => subtask;
  @override Future<void> updateSubtask(Subtask subtask) async {}
  @override Future<void> deleteSubtask(int id) async {}
  @override Future<void> clearCompletedTasks() async {}
  @override
  Future<List<TaskOccurrenceState>> getOccurrenceStates() async => _states.values.toList();
  @override
  Future<void> setOccurrenceCompleted(int taskId, DateTime occurrenceAt, bool isCompleted) async {
    final s = TaskOccurrenceState(
      taskId: taskId,
      occurrenceAt: occurrenceAt,
      isCompleted: isCompleted,
      updatedAt: DateTime.now().toUtc(),
      completedAt: isCompleted ? DateTime.now().toUtc() : null,
    );
    _states[s.key] = s;
  }
  @override
  Future<void> setOccurrenceExcluded(int taskId, DateTime occurrenceAt) async {
    final s = TaskOccurrenceState(
      taskId: taskId,
      occurrenceAt: occurrenceAt,
      isExcluded: true,
      updatedAt: DateTime.now().toUtc(),
    );
    _states[s.key] = s;
  }

  @override
  Future<void> setOccurrenceSeriesCompletedFrom(
    int taskId,
    DateTime occurrenceAt,
    bool isCompleted,
  ) async {
    final DateTime from = occurrenceAt.toUtc();
    final int index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        seriesCompletedFrom: isCompleted ? from : null,
        seriesCompleted: false,
      );
    }
    _states.removeWhere(
      (key, state) => state.taskId == taskId && !state.isExcluded && !state.occurrenceAt.toUtc().isBefore(from),
    );
  }

  @override
  Future<void> setSeriesCompleted(int taskId, bool isCompleted) async {
    final int index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        seriesCompleted: isCompleted,
        seriesCompletedFrom: null,
      );
    }
    _states.removeWhere(
      (key, state) => state.taskId == taskId && !state.isExcluded,
    );
  }
}

void main() {
  test('occurrence completion state is keyed per occurrence and persisted via store', () async {
    final store = _MemoryTaskStore();
    final service = TaskService(store: store);
    final task = await service.addTask(
      title: 'Daily',
      dueDate: DateTime(2026, 1, 1, 9),
      recurrence: RecurrencePattern.daily,
    );
    final a = DateTime(2026, 1, 2, 9);
    final b = DateTime(2026, 1, 3, 9);
    await service.setOccurrenceCompleted(task.id, a, true);
    final states = await service.getOccurrenceStates();
    expect(states.any((s) => s.taskId == task.id && s.isCompleted), isTrue);
    expect(
      states.firstWhere((s) => TaskOccurrenceState.keyFor(s.taskId, s.occurrenceAt) == TaskOccurrenceState.keyFor(task.id, a)).isCompleted,
      isTrue,
    );
    expect(states.where((s) => TaskOccurrenceState.keyFor(task.id, b) == s.key && s.isCompleted), isEmpty);
    await service.setOccurrenceExcluded(task.id, b);
    final after = await service.getOccurrenceStates();
    expect(after.firstWhere((s) => s.key == TaskOccurrenceState.keyFor(task.id, b)).isExcluded, isTrue);
  });
}
