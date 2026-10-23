import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/main.dart';
import 'package:todoapp/models/task.dart';
import 'package:todoapp/services/database_service.dart';
import 'package:todoapp/services/task_service.dart';

class _InMemoryTaskStore implements TaskStore {
  _InMemoryTaskStore([Iterable<Task> tasks = const []])
    : _tasks = List<Task>.from(tasks) {
    for (final Task task in _tasks) {
      if (task.id >= _nextId) {
        _nextId = task.id + 1;
      }
    }
  }

  final List<Task> _tasks;
  int _nextId = 1;

  List<Task> get tasks => List<Task>.unmodifiable(_tasks);

  @override
  Future<List<Task>> getTasks() async => List<Task>.from(_tasks);

  @override
  Future<Task?> getTaskById(int id) async {
    for (final Task task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  Future<Task> insertTask(Task task) async {
    final Task saved = task.copyWith(id: _nextId++);
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
  }
}

List<Task> _sampleTasks() {
  final DateTime base = DateTime.utc(2026, 1, 1);
  return [
    Task(
      id: 1,
      title: 'Study Flutter',
      description: 'Learn widgets and navigation',
      isCompleted: true,
      createdAt: base,
    ),
    Task(
      id: 2,
      title: 'Build To-Do UI',
      description: 'Create the first mobile interface',
      isCompleted: false,
      createdAt: base.add(const Duration(minutes: 1)),
    ),
    Task(
      id: 3,
      title: 'Connect API',
      description: 'Later connect the Flutter app to the backend',
      isCompleted: false,
      createdAt: base.add(const Duration(minutes: 2)),
    ),
  ];
}

Future<void> _pumpApp(WidgetTester tester, _InMemoryTaskStore store) async {
  await tester.pumpWidget(MyApp(taskService: TaskService(store: store)));
  await tester.pumpAndSettle();
}

void main() {
  test('Task converts to and from a SQLite map', () {
    final DateTime createdAt = DateTime.utc(2026, 2, 3, 4, 5, 6);
    final Task task = Task(
      id: 7,
      title: 'Read a chapter',
      description: 'Chapter 1',
      isCompleted: true,
      createdAt: createdAt,
    );

    final Map<String, dynamic> map = task.toMap();

    expect(map['id'], 7);
    expect(map['title'], 'Read a chapter');
    expect(map['description'], 'Chapter 1');
    expect(map['is_completed'], 1);
    expect(map['created_at'], '2026-02-03T04:05:06.000Z');

    final Task restored = Task.fromMap(map);

    expect(restored.id, 7);
    expect(restored.title, 'Read a chapter');
    expect(restored.description, 'Chapter 1');
    expect(restored.isCompleted, isTrue);
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
  });

  testWidgets('home screen loads tasks and shows the counter', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);

    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('2 tasks remaining'), findsOneWidget);
    expect(find.text('Study Flutter'), findsOneWidget);
    expect(find.text('Build To-Do UI'), findsOneWidget);
    expect(find.text('Connect API'), findsOneWidget);
  });

  testWidgets('filters switch the visible tasks', (WidgetTester tester) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Study Flutter'), findsOneWidget);
    expect(find.text('Build To-Do UI'), findsNothing);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();

    expect(find.text('Study Flutter'), findsNothing);
    expect(find.text('Build To-Do UI'), findsOneWidget);
    expect(find.text('Connect API'), findsOneWidget);
  });

  testWidgets('empty state is shown when there are no tasks', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore();

    await _pumpApp(tester, store);

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('0 tasks remaining'), findsOneWidget);
  });

  testWidgets('add task screen validates an empty title', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore();

    await _pumpApp(tester, store);

    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Title cannot be empty'), findsOneWidget);
    expect(store.tasks, isEmpty);
  });

  testWidgets('adding a task saves it through the task service', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore();

    await _pumpApp(tester, store);

    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Write tests');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Cover the SQLite flow',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Write tests'), findsOneWidget);
    expect(find.text('1 tasks remaining'), findsOneWidget);
    expect(store.tasks, hasLength(1));
    expect(store.tasks.single.description, 'Cover the SQLite flow');
    expect(store.tasks.single.isCompleted, isFalse);
  });

  testWidgets('editing a task updates the saved task', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);

    await tester.tap(find.text('Build To-Do UI'));
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

    expect(find.text('1 tasks remaining'), findsOneWidget);
    expect(store.tasks.firstWhere((task) => task.id == 2).isCompleted, isTrue);
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
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Task?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Connect API'), findsNothing);
    expect(store.tasks.any((task) => task.id == 3), isFalse);
  });
}
