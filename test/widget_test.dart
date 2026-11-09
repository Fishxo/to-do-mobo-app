import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:todoapp/main.dart';
import 'package:todoapp/models/app_notification.dart';
import 'package:todoapp/models/category.dart';
import 'package:todoapp/models/subtask.dart';
import 'package:todoapp/models/task.dart';
import 'package:todoapp/models/task_occurrence.dart';
import 'package:todoapp/models/task_priority.dart';
import 'package:todoapp/services/database_service.dart';
import 'package:todoapp/services/notification_service.dart';
import 'package:todoapp/services/statistics_service.dart';
import 'package:todoapp/services/task_service.dart';
import 'package:todoapp/state/app_controller.dart';
import 'package:todoapp/utils/task_filters.dart';

class _InMemoryTaskStore implements TaskStore, NotificationStore {
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
  final List<AppNotification> _notifications = [];
  final Map<String, TaskOccurrenceState> _occurrenceStates = {};

  int _nextTaskId = 1;
  int _nextCategoryId = 1;
  int _nextSubtaskId = 1;
  int _nextNotificationId = 1;

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
    for (int index = 0; index < _notifications.length; index++) {
      if (_notifications[index].taskId == id) {
        _notifications[index] = _notifications[index].copyWith(taskId: null);
      }
    }
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

  @override
  Future<List<AppNotification>> getNotifications() async {
    final List<AppNotification> notifications =
        List<AppNotification>.from(
          _notifications.where((item) => !item.isCleared),
        )..sort((a, b) {
          final int byDate = b.eventAt.compareTo(a.eventAt);
          if (byDate != 0) return byDate;
          return b.id.compareTo(a.id);
        });
    return notifications;
  }

  @override
  Future<bool> insertNotificationIfAbsent(AppNotification notification) async {
    if (_notifications.any(
      (item) => item.dedupeKey == notification.dedupeKey,
    )) {
      return false;
    }
    _notifications.add(notification.copyWith(id: _nextNotificationId++));
    return true;
  }

  @override
  Future<void> markNotificationRead(int id) async {
    final int index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1) return;
    if (_notifications[index].isRead) return;
    _notifications[index] = _notifications[index].copyWith(
      readAt: DateTime.now(),
    );
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final DateTime now = DateTime.now();
    for (int index = 0; index < _notifications.length; index++) {
      if (!_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(readAt: now);
      }
    }
  }

  @override
  Future<void> deleteNotification(int id) async {
    final int index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1 || _notifications[index].isCleared) return;
    _notifications[index] = _notifications[index].copyWith(
      clearedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearNotifications() async {
    final DateTime now = DateTime.now();
    for (int index = 0; index < _notifications.length; index++) {
      if (!_notifications[index].isCleared) {
        _notifications[index] = _notifications[index].copyWith(clearedAt: now);
      }
    }
  }

  @override
  Future<void> clearNotificationsForTask(int taskId) async {
    final DateTime now = DateTime.now();
    for (int index = 0; index < _notifications.length; index++) {
      final AppNotification notification = _notifications[index];
      if (notification.taskId == taskId && !notification.isCleared) {
        _notifications[index] = notification.copyWith(clearedAt: now);
      }
    }
  }

  @override
  Future<List<TaskOccurrenceState>> getOccurrenceStates() async {
    return _occurrenceStates.values.toList(growable: false);
  }

  @override
  Future<void> setOccurrenceCompleted(
    int taskId,
    DateTime occurrenceAt,
    bool isCompleted,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    final TaskOccurrenceState state = TaskOccurrenceState(
      taskId: taskId,
      occurrenceAt: occurrenceAt,
      isCompleted: isCompleted,
      isExcluded: false,
      completedAt: isCompleted ? now : null,
      updatedAt: now,
    );
    _occurrenceStates[state.key] = state;
  }

  @override
  Future<void> setOccurrenceExcluded(int taskId, DateTime occurrenceAt) async {
    final DateTime now = DateTime.now().toUtc();
    final TaskOccurrenceState state = TaskOccurrenceState(
      taskId: taskId,
      occurrenceAt: occurrenceAt,
      isCompleted: false,
      isExcluded: true,
      updatedAt: now,
    );
    _occurrenceStates[state.key] = state;
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
        isCompleted: false,
        completedAt: null,
      );
    }
    _occurrenceStates.removeWhere(
      (key, state) => state.taskId == taskId && !state.isExcluded && !state.occurrenceAt.toUtc().isBefore(from),
    );
    if (!isCompleted) {
      await setOccurrenceCompleted(taskId, occurrenceAt, false);
    }
  }

  @override
  Future<void> setSeriesCompleted(int taskId, bool isCompleted) async {
    final DateTime now = DateTime.now().toUtc();
    final int index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        seriesCompleted: isCompleted,
        seriesCompletedFrom: null,
        isCompleted: isCompleted,
        completedAt: isCompleted ? now : null,
      );
    }
    _occurrenceStates.removeWhere(
      (key, state) => state.taskId == taskId && !state.isExcluded,
    );
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
    expect(restored.dueDate!.toUtc(), dueDate.toUtc());
    expect(restored.reminderAt!.toUtc(), reminderAt.toUtc());
    expect(restored.createdAt.toUtc(), createdAt.toUtc());
  });

  test('13:15 Africa/Addis_Ababa survives persistence and scheduling', () {
    tz_data.initializeTimeZones();
    final tz.Location addis = tz.getLocation('Africa/Addis_Ababa');
    final tz.TZDateTime selectedReminder = tz.TZDateTime(
      addis,
      2026,
      11,
      10,
      13,
      15,
    );
    final Task selectedTask = Task(
      id: 21,
      title: 'Local-time reminder',
      description: '',
      isCompleted: false,
      createdAt: selectedReminder,
      reminderAt: selectedReminder,
    );

    final Map<String, dynamic> sqliteRow = selectedTask.toMap();
    expect(sqliteRow['reminder_at'], '2026-11-10T10:15:00.000Z');

    final Task restoredTask = Task.fromMap(sqliteRow);
    final DateTime restoredReminder = restoredTask.reminderAt!;
    expect(
      restoredReminder.millisecondsSinceEpoch,
      selectedReminder.millisecondsSinceEpoch,
    );
    final tz.TZDateTime restoredInAddis = tz.TZDateTime.from(
      restoredReminder,
      addis,
    );
    expect(restoredInAddis.hour, 13);
    expect(restoredInAddis.minute, 15);

    final tz.TZDateTime scheduled = NotificationService.scheduledDateFor(
      restoredReminder,
    );
    final tz.TZDateTime scheduledInAddis = tz.TZDateTime.from(scheduled, addis);
    expect(scheduledInAddis.hour, 13);
    expect(scheduledInAddis.minute, 15);
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
    expect(stats.pending, 1);
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

    await tester.tap(find.text('Pending (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Build To-Do UI'), findsOneWidget);
    expect(find.text('Connect API'), findsNothing);
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

    expect(find.byKey(const Key('notification-display-settings')), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('calendar opens a date in day view and shows its tasks', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-view-month')), findsOneWidget);
    expect(find.text(DateFormat('MMMM yyyy').format(now)), findsOneWidget);

    await tester.tap(
      find.byKey(Key('calendar-day-${now.year}-${now.month}-${now.day}')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('EEE, MMM d, yyyy').format(now)),
      findsOneWidget,
    );
    expect(find.text('Study Flutter'), findsOneWidget);

    await tester.tap(find.text('Study Flutter'));
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsOneWidget);
  });

  testWidgets('calendar switches to year and week views', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-view-year')));
    await tester.pumpAndSettle();

    expect(find.text('${now.year}'), findsOneWidget);
    expect(find.text('January'), findsOneWidget);

    await tester.tap(find.text('January'));
    await tester.pumpAndSettle();

    expect(find.text('January ${now.year}'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-view-week')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(Key('calendar-week-day-${now.year}-${now.month}-${now.day}')),
      findsOneWidget,
    );
    expect(find.text('Study Flutter'), findsOneWidget);
  });

  testWidgets('calendar previous, next, and today navigation updates period', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime nextMonth = DateTime(now.year, now.month + 1, 1);
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    final String currentLabel = DateFormat('MMMM yyyy').format(now);
    final String nextLabel = DateFormat('MMMM yyyy').format(nextMonth);

    await tester.tap(find.byKey(const Key('calendar-next')));
    await tester.pumpAndSettle();
    expect(find.text(nextLabel), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-previous')));
    await tester.pumpAndSettle();
    expect(find.text(currentLabel), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-today')));
    await tester.pumpAndSettle();
    expect(find.text(currentLabel), findsOneWidget);
  });

  test('pending filter excludes completed, overdue, and includes today/no-date tasks', () {
    final DateTime now = DateTime.now();
    final List<Task> tasks = [
      Task(
        id: 1,
        title: 'Completed today',
        description: '',
        isCompleted: true,
        createdAt: now,
        dueDate: now,
      ),
      Task(
        id: 2,
        title: 'Due today',
        description: '',
        isCompleted: false,
        createdAt: now,
        dueDate: now,
      ),
      Task(
        id: 3,
        title: 'No due date',
        description: '',
        isCompleted: false,
        createdAt: now,
      ),
      Task(
        id: 4,
        title: 'Overdue',
        description: '',
        isCompleted: false,
        createdAt: now,
        dueDate: now.subtract(const Duration(days: 2)),
      ),
    ];

    final List<Task> pending = filterTasks(tasks, TaskFilter.pending);

    expect(
      pending.map((task) => task.title),
      containsAll(['Due today', 'No due date']),
    );
    expect(pending, hasLength(2));
    expect(filterTasks(tasks, TaskFilter.completed), hasLength(1));
    expect(filterTasks(tasks, TaskFilter.overdue), hasLength(1));
  });

  test('notification payloads identify the correct task', () {
    expect(NotificationService.parseTaskIdFromPayload('task:42'), 42);
    expect(NotificationService.parseTaskIdFromPayload('42'), 42);
    expect(NotificationService.parseTaskIdFromPayload('task: 7'), 7);
    expect(NotificationService.parseTaskIdFromPayload(null), isNull);
    expect(NotificationService.parseTaskIdFromPayload(''), isNull);
    expect(NotificationService.parseTaskIdFromPayload('task:'), isNull);
    expect(NotificationService.parseTaskIdFromPayload('task:abc'), isNull);
    expect(NotificationService.parseTaskIdFromPayload('task:0'), isNull);
    expect(NotificationService.parseTaskIdFromPayload('task:-3'), isNull);
  });

  test('Android reminders use a heads-up capable channel', () {
    final channel = NotificationService.androidReminderChannel;

    expect(channel.id, NotificationService.androidChannelId);
    expect(channel.importance.value, greaterThanOrEqualTo(4));
    expect(channel.playSound, isTrue);
    expect(channel.enableVibration, isTrue);
    expect(channel.showBadge, isTrue);
  });

  test('notification content uses the task title and description', () {
    final Task task = Task(
      id: 5,
      title: 'Complete Flutter To-Do App',
      description:
          'Finish implementing notification navigation and test the '
          'reminder functionality.',
      isCompleted: false,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    expect(
      NotificationService.notificationTitleFor(task),
      'Complete Flutter To-Do App',
    );
    expect(
      NotificationService.notificationBodyFor(task),
      'Finish implementing notification navigation and test the reminder '
      'functionality.',
    );
    expect(NotificationService.payloadForTask(task.id), 'task:5');
  });

  test('notification content falls back when a task has no description', () {
    final Task task = Task(
      id: 6,
      title: 'No description',
      description: '   ',
      isCompleted: false,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    expect(
      NotificationService.notificationBodyFor(task),
      NotificationService.emptyDescriptionFallback,
    );
  });

  testWidgets('launching from a reminder opens that task details screen', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MyApp(
        taskService: TaskService(store: store),
        initialNotificationTaskId: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsOneWidget);
    expect(find.text('Build To-Do UI'), findsOneWidget);
    expect(find.text('Create the first mobile interface'), findsOneWidget);
    expect(find.text('My Tasks'), findsNothing);
  });

  testWidgets('a reminder for a deleted task shows a friendly message', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MyApp(
        taskService: TaskService(store: store),
        initialNotificationTaskId: 999,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsOneWidget);
    expect(find.text('This task no longer exists.'), findsOneWidget);
  });

  testWidgets('tapping a reminder while the app is running opens the task', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());
    final AppController controller = AppController(
      taskService: TaskService(store: store),
    );
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MyApp(appController: controller));
    await tester.pumpAndSettle();

    expect(find.text('My Tasks'), findsOneWidget);

    controller.notificationService.handleNotificationPayload('task:3');
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsOneWidget);
    expect(find.text('Connect API'), findsOneWidget);
    expect(
      find.text('Later connect the Flutter app to the backend'),
      findsOneWidget,
    );
  });

  testWidgets('reports tab shows period insights and navigation', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Reports & Insights'), findsOneWidget);
    expect(find.text('Task breakdown'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Study Flutter'), findsWidgets);

    await tester.tap(find.byKey(const Key('reports-previous')));
    await tester.pumpAndSettle();
    expect(find.text('Current'), findsNothing);

    await tester.tap(find.byKey(const Key('reports-next')));
    await tester.pumpAndSettle();
    expect(find.text('Current'), findsOneWidget);

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly report'), findsOneWidget);

    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.text('January – December ${now.year}'), findsOneWidget);
  });

  testWidgets('notification center shows unread items and opens tasks', (
    WidgetTester tester,
  ) async {
    final _InMemoryTaskStore store = _InMemoryTaskStore(_sampleTasks());

    await _pumpApp(tester, store);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Appointment missed'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);

    await tester.tap(find.text('Appointment missed'));
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsOneWidget);
    expect(find.text('Connect API'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notifications-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Clear notifications?'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('No notifications'), findsOneWidget);
  });

  testWidgets('individual notifications can be deleted', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final _InMemoryTaskStore store = _InMemoryTaskStore([
      ..._sampleTasks(),
      Task(
        id: 4,
        title: 'Second overdue task',
        description: 'Also missed its due time',
        isCompleted: false,
        createdAt: DateTime(2026, 1, 1, 0, 3),
        dueDate: now.subtract(const Duration(hours: 3)),
      ),
    ]);

    await _pumpApp(tester, store);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Appointment missed'), findsNWidgets(2));
    expect(find.byTooltip('Delete notification'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Delete notification').first);
    await tester.pumpAndSettle();

    expect(find.text('Appointment missed'), findsOneWidget);
    expect(await store.getNotifications(), hasLength(1));

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('Appointment missed'), findsOneWidget);
    expect(await store.getNotifications(), hasLength(1));
  });
}
