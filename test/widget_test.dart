import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todoapp/main.dart';
import 'package:todoapp/models/category.dart';
import 'package:todoapp/models/subtask.dart';
import 'package:todoapp/models/task.dart';
import 'package:todoapp/models/task_priority.dart';
import 'package:todoapp/services/database_service.dart';
import 'package:todoapp/services/statistics_service.dart';
import 'package:todoapp/services/task_service.dart';

class _InMemoryTaskStore implements TaskStore {
  _InMemoryTaskStore([Iterable<Task> tasks = const []])
    : _tasks = List<Task>.from(tasks) {
    for (final Task task in _tasks) {
      if (task.id >= _nextTaskId) _nextTaskId = task.id + 1;
      for (final Subtask subtask in task.subtasks) {
        _subtasks.add(subtask);
        if (subtask.id >= _nextSubtaskId) _nextSubtaskId = subtask.id + 1;
      }
    }
  }

  final List<Task> _tasks;
  final List<Category> _categories = [];
  final List<Subtask> _subtasks = [];

  int _nextTaskId = 1;
  int _nextCategoryId = 1;
  int _nextSubtaskId = 1;

  List<Task> get tasks => List<Task>.unmodifiable(_tasks);
  List<Category> get categories => List<Category>.unmodifiable(_categories);

  List<Subtask> _subtasksFor(int taskId) {
    return _subtasks
        .where((subtask) => subtask.taskId == taskId)
        .toList(growable: false);
  }

  @override
  Future<List<Task>> getTasks() async {
    return _tasks
        .map((task) => task.copyWith(subtasks: _subtasksFor(task.id)))
        .toList(growable: false);
  }

  @override
  Future<Task?> getTaskById(int id) async {
    for (final Task task in _tasks) {
      if (task.id == id) {
        return task.copyWith(subtasks: _subtasksFor(task.id));
      }
    }
    return null;
  }

  @override
  Future<Task> insertTask(Task task) async {
    final Task saved = task.copyWith(id: _nextTaskId++);
    _tasks.add(saved);
    return saved;
  }

  @override
  Future<void> updateTask(Task task) async {
    final int index = _tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      throw StateError('Task with id ${task.id} was not found');
    }
    _tasks[index] = task;
  }

  @override
  Future<void> deleteTask(int id) async {
    _tasks.removeWhere((task) => task.id == id);
    _subtasks.removeWhere((subtask) => subtask.taskId == id);
  }

  @override
  Future<List<Category>> getCategories() async {
    return List<Category>.from(_categories);
  }

  @override
  Future<Category> insertCategory(Category category) async {
    final Category saved = category.copyWith(id: _nextCategoryId++);
    _categories.add(saved);
    return saved;
  }

  @override
  Future<void> updateCategory(Category category) async {
    final int index = _categories.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      throw StateError('Category with id ${category.id} was not found');
    }
    _categories[index] = category;
  }

  @override
  Future<void> deleteCategory(int id) async {
    _categories.removeWhere((category) => category.id == id);
    for (int index = 0; index < _tasks.length; index++) {
      if (_tasks[index].categoryId == id) {
        _tasks[index] = _tasks[index].copyWith(categoryId: null);
      }
    }
  }

  @override
  Future<List<Subtask>> getSubtasksForTask(int taskId) async {
    return _subtasksFor(taskId);
  }

  @override
  Future<Subtask> insertSubtask(Subtask subtask) async {
    final Subtask saved = subtask.copyWith(id: _nextSubtaskId++);
    _subtasks.add(saved);
    return saved;
  }

  @override
  Future<void> updateSubtask(Subtask subtask) async {
    final int index = _subtasks.indexWhere((item) => item.id == subtask.id);
    if (index == -1) {
      throw StateError('Subtask with id ${subtask.id} was not found');
    }
    _subtasks[index] = subtask;
  }

  @override
  Future<void> deleteSubtask(int id) async {
    _subtasks.removeWhere((subtask) => subtask.id == id);
  }

  @override
  Future<void> clearCompletedTasks() async {
    final List<int> completedIds = _tasks
        .where((task) => task.isCompleted)
        .map((task) => task.id)
        .toList();
    _tasks.removeWhere((task) => task.isCompleted);
    _subtasks.removeWhere((subtask) => completedIds.contains(subtask.taskId));
  }
}

List<Task> _sampleTasks() {
  final DateTime now = DateTime.now();
  final DateTime base = DateTime(2026, 1, 1);
  return [
    Task(
      id: 1,
      title: 'Study Flutter',
      description: 'Learn widgets and navigation',
      isCompleted: true,
      createdAt: base,
      dueDate: now,
    ),
    Task(
      id: 2,
      title: 'Build To-Do UI',
      description: 'Create the first mobile interface',
      isCompleted: false,
      createdAt: base.add(const Duration(minutes: 1)),
      dueDate: now.add(const Duration(days: 1)),
    ),
    Task(
      id: 3,
      title: 'Connect API',
      description: 'Later connect the Flutter app to the backend',
      isCompleted: false,
      createdAt: base.add(const Duration(minutes: 2)),
      dueDate: now.subtract(const Duration(days: 2)),
    ),
  ];
}

Future<void> _pumpApp(WidgetTester tester, _InMemoryTaskStore store) async {
  await tester.binding.setSurfaceSize(const Size(430, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MyApp(taskService: TaskService(store: store)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Task converts to and from a SQLite map', () {
    final DateTime createdAt = DateTime.utc(2026, 2, 3, 4, 5, 6);
    final DateTime dueDate = DateTime.utc(2026, 2, 5, 12);
    final DateTime reminderAt = DateTime.utc(2026, 2, 5, 8);
    final DateTime completedAt = DateTime.utc(2026, 2, 4, 9);
    final Task task = Task(
      id: 7,
      title: 'Read a chapter',
      description: 'Chapter 1',
      isCompleted: true,
      createdAt: createdAt,
      categoryId: 2,
      priority: TaskPriority.high,
      dueDate: dueDate,
      reminderAt: reminderAt,
      updatedAt: completedAt,
      completedAt: completedAt,
    );

    final Map<String, dynamic> map = task.toMap();

    expect(map['id'], 7);
    expect(map['title'], 'Read a chapter');
    expect(map['description'], 'Chapter 1');
    expect(map['is_completed'], 1);
    expect(map['category_id'], 2);
    expect(map['priority'], TaskPriority.high.value);
    expect(map['due_at'], dueDate.toIso8601String());
    expect(map['reminder_at'], reminderAt.toIso8601String());
    expect(map['completed_at'], completedAt.toIso8601String());
    expect(map['created_at'], '2026-02-03T04:05:06.000Z');

    final Task restored = Task.fromMap(map);

    expect(restored.id, 7);
    expect(restored.title, 'Read a chapter');
    expect(restored.isCompleted, isTrue);
    expect(restored.categoryId, 2);
    expect(restored.priority, TaskPriority.high);
    expect(restored.dueDate, dueDate);
    expect(restored.reminderAt, reminderAt);
    expect(restored.createdAt, createdAt);
  });

  test('Task can omit its id when inserting into SQLite', () {
    final Task task = Task(
      id: 0,
      title: 'New task',
      description: '',
      isCompleted: false,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    expect(task.toMap(includeId: false).containsKey('id'), isFalse);
    expect(task.toMap()['is_completed'], 0);
    expect(task.toMap()['priority'], TaskPriority.medium.value);
  });

  test('Subtask converts to and from a SQLite map', () {
    final DateTime createdAt = DateTime.utc(2026, 2, 3, 4, 5, 6);
    final Subtask subtask = Subtask(
      id: 3,
      taskId: 7,
      title: 'Write outline',
      isCompleted: true,
      createdAt: createdAt,
    );

    final Subtask restored = Subtask.fromMap(subtask.toMap());
    expect(restored.id, 3);
    expect(restored.taskId, 7);
    expect(restored.title, 'Write outline');
    expect(restored.isCompleted, isTrue);
    expect(restored.createdAt, createdAt);
  });

  test('statistics use real task records', () {
    final TaskStatistics stats = const StatisticsService().calculate(
      _sampleTasks(),
    );

    expect(stats.total, 3);
    expect(stats.completed, 1);
    expect(stats.pending, 2);
    expect(stats.overdue, 1);
    expect(stats.lastSevenDays, hasLength(7));
    expect(stats.weeklyCompletionPercentage, inInclusiveRange(0, 100));
  });

  testWidgets('home screen loads tasks and shows the dashboard', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);

    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('Study Flutter'), findsOneWidget);
    expect(find.text('Build To-Do UI'), findsOneWidget);
    expect(find.text('Connect API'), findsOneWidget);
    expect(find.text('Overdue'), findsWidgets);
    expect(find.text('New Task'), findsOneWidget);
  });

  testWidgets('filters switch the visible tasks', (WidgetTester tester) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Study Flutter'), findsOneWidget);
    expect(find.text('Build To-Do UI'), findsNothing);

    await tester.tap(find.text('Overdue (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Connect API'), findsOneWidget);
    expect(find.text('Study Flutter'), findsNothing);

    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();

    expect(find.text('Study Flutter'), findsOneWidget);
    expect(find.text('Build To-Do UI'), findsOneWidget);
    expect(find.text('Connect API'), findsOneWidget);
  });

  testWidgets('empty state is shown when there are no tasks', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore();

    await _pumpApp(tester, store);

    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('add task screen validates an empty title', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore();

    await _pumpApp(tester, store);

    await tester.tap(find.text('New Task'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Task'));
    await tester.pump();

    expect(find.text('Title cannot be empty'), findsOneWidget);
    expect(store.tasks, isEmpty);
  });

  testWidgets('adding a task saves it through the task service', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore();

    await _pumpApp(tester, store);

    await tester.tap(find.text('New Task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Write tests');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Cover the SQLite flow',
    );
    await tester.tap(find.text('Create Task'));
    await tester.pumpAndSettle();

    expect(find.text('Write tests'), findsOneWidget);
    expect(store.tasks, hasLength(1));
    expect(store.tasks.single.description, 'Cover the SQLite flow');
    expect(store.tasks.single.isCompleted, isFalse);
  });

  testWidgets('editing a task updates the saved task', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);

    final Finder taskCard = find.ancestor(
      of: find.text('Build To-Do UI'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(
        of: taskCard,
        matching: find.byIcon(Icons.more_vert_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Task'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Build a better UI',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Build a better UI'), findsOneWidget);
    expect(find.text('Build To-Do UI'), findsNothing);
    expect(
      store.tasks.firstWhere((task) => task.id == 2).title,
      'Build a better UI',
    );
  });

  testWidgets('toggling a task saves its completed state', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);

    final Finder taskCard = find.ancestor(
      of: find.text('Build To-Do UI'),
      matching: find.byType(Card),
    );

    await tester.tap(
      find.descendant(of: taskCard, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();

    expect(store.tasks.firstWhere((task) => task.id == 2).isCompleted, isTrue);
    expect(
      store.tasks.firstWhere((task) => task.id == 2).completedAt,
      isNotNull,
    );
  });

  testWidgets('deleting a task removes it after confirmation', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);

    final Finder taskCard = find.ancestor(
      of: find.text('Connect API'),
      matching: find.byType(Card),
    );

    await tester.tap(
      find.descendant(
        of: taskCard,
        matching: find.byIcon(Icons.more_vert_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();

    expect(find.text('Delete task?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Connect API'), findsNothing);
    expect(store.tasks.any((task) => task.id == 3), isFalse);
  });

  testWidgets('task details can add a subtask and update progress', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);

    await tester.tap(find.text('Build To-Do UI'));
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Create layout');
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    expect(find.text('Create layout'), findsWidgets);
    expect(find.text('0 of 1 completed'), findsOneWidget);
  });

  testWidgets('bottom navigation opens categories with default data', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore();

    await _pumpApp(tester, store);

    await tester.tap(find.byIcon(Icons.category_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsWidgets);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);

    await tester.tap(find.text('New Category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Finance');
    await tester.tap(find.text('Create Category'));
    await tester.pumpAndSettle();

    expect(find.text('Finance'), findsOneWidget);
    expect(
      store.categories.any((category) => category.name == 'Finance'),
      isTrue,
    );
  });

  testWidgets('settings can switch to the dark theme', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore();

    await _pumpApp(tester, store);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });
}
