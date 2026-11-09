import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/recurrence.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../models/task_priority.dart';
import '../services/category_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/notification_center_service.dart';
import '../services/notification_service.dart';
import '../services/recurrence_service.dart';
import '../services/settings_service.dart';
import '../services/statistics_service.dart';
import '../services/task_service.dart';
import '../utils/occurrence_utils.dart';
import '../widgets/recurring_completion_dialog.dart';

/// Central application state shared by every tab.
///
/// Screens listen to this controller instead of loading the database directly.
/// All reads and writes still go through the service layer.
class AppController extends ChangeNotifier {
  AppController({
    TaskService? taskService,
    CategoryService? categoryService,
    SettingsService? settingsService,
    NotificationService? notificationService,
    NotificationCenterService? notificationCenterService,
  }) {
    _taskService = taskService ?? TaskService.instance;
    _categoryService =
        categoryService ?? CategoryService(store: _taskService.store);
    _settingsService = settingsService ?? SettingsService.instance;
    _notificationService = notificationService ?? NotificationService.instance;
    final TaskStore store = _taskService.store;
    _notificationCenterService =
        notificationCenterService ??
        (store is NotificationStore
            ? NotificationCenterService(
                store: store as NotificationStore,
                notificationService: _notificationService,
              )
            : null);
    _exportService = ExportService(
      taskService: _taskService,
      categoryService: _categoryService,
    );
  }

  late final TaskService _taskService;
  late final CategoryService _categoryService;
  late final SettingsService _settingsService;
  late final NotificationService _notificationService;
  late final NotificationCenterService? _notificationCenterService;
  late final ExportService _exportService;

  List<Task> _tasks = const [];
  List<Category> _categories = const [];
  List<AppNotification> _notifications = const [];
  Map<String, TaskOccurrenceState> _occurrenceStates = const {};
  AppSettings _settings = const AppSettings();
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _notificationTimer;

  List<Task> get tasks => _tasks;
  List<Category> get categories => _categories;
  AppSettings get settings => _settings;
  Map<String, TaskOccurrenceState> get occurrenceStates => _occurrenceStates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get notificationsAvailable => _notificationService.isAvailable;
  bool get notificationPermissionGranted =>
      _notificationService.permissionGranted;
  NotificationService get notificationService => _notificationService;
  NotificationCenterService? get notificationCenter =>
      _notificationCenterService;
  List<AppNotification> get notifications => _notifications;
  int get unreadNotificationCount =>
      _notifications.where((notification) => !notification.isRead).length;

  TaskStatistics get statistics => StatisticsService().calculate(_tasks);

  Category? categoryById(int? id) {
    if (id == null) return null;
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Task? taskById(int id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  List<Task> tasksForCategory(int categoryId) {
    return _tasks
        .where((task) => task.categoryId == categoryId)
        .toList(growable: false);
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      _settings = await _settingsService.load();
      await _categoryService.ensureDefaultCategories();
      await _reloadData();

      if (_settings.notificationsEnabled) {
        await _notificationService.initialize();
        await _notificationService.requestPermission();
        await _rescheduleReminders();
      }
      _startNotificationTimer();
    } catch (error) {
      _errorMessage = 'Could not load your data. Please try again.';
      debugPrint('Initialization failed: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      await _reloadData();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Could not refresh your data. Please try again.';
      debugPrint('Refresh failed: $error');
    }
    notifyListeners();
  }

  Future<void> _reloadData() async {
    _categories = await _categoryService.getCategories();
    _tasks = await _taskService.getTasks();
    final List<TaskOccurrenceState> states = await _taskService
        .getOccurrenceStates();
    _occurrenceStates = {
      for (final TaskOccurrenceState state in states) state.key: state,
    };
    await _syncNotifications();
    await _loadNotifications();
    notifyListeners();
  }

  Future<void> _syncNotifications() async {
    final NotificationCenterService? service = _notificationCenterService;
    if (service == null) return;

    try {
      await service.sync(tasks: _tasks, occurrenceStates: _occurrenceStates);
    } catch (error) {
      debugPrint('Could not sync notifications: $error');
    }
  }

  Future<void> _loadNotifications() async {
    final NotificationCenterService? service = _notificationCenterService;
    if (service == null) {
      _notifications = const [];
      return;
    }

    try {
      _notifications = await service.getNotifications();
    } catch (error) {
      debugPrint('Could not load notifications: $error');
    }
  }

  void _startNotificationTimer() {
    if (_notificationCenterService == null) return;
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshNotifications(),
    );
  }

  Future<void> _refreshNotifications() async {
    final NotificationCenterService? service = _notificationCenterService;
    if (service == null) return;

    try {
      final int inserted = await service.sync(
        tasks: _tasks,
        occurrenceStates: _occurrenceStates,
      );
      final List<AppNotification> latest = await service.getNotifications();
      final bool changed =
          inserted > 0 || !_notificationsMatch(_notifications, latest);
      _notifications = latest;
      if (changed) notifyListeners();
    } catch (error) {
      debugPrint('Could not refresh notifications: $error');
    }
  }

  bool _notificationsMatch(List<AppNotification> a, List<AppNotification> b) {
    if (a.length != b.length) return false;
    for (int index = 0; index < a.length; index++) {
      if (a[index].id != b[index].id || a[index].readAt != b[index].readAt) {
        return false;
      }
    }
    return true;
  }

  Future<void> markNotificationRead(int id) async {
    final NotificationCenterService? service = _notificationCenterService;
    if (service == null) return;
    await service.markAsRead(id);
    await _loadNotifications();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    final NotificationCenterService? service = _notificationCenterService;
    if (service == null) return;
    await service.markAllAsRead();
    await _loadNotifications();
    notifyListeners();
  }

  Future<void> deleteNotification(int id) async {
    final NotificationCenterService? service = _notificationCenterService;
    if (service == null) return;
    await service.deleteNotification(id);
    _notifications = _notifications
        .where((notification) => notification.id != id)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> clearNotifications() async {
    final NotificationCenterService? service = _notificationCenterService;
    if (service == null) return;
    await service.clearNotifications();
    _notifications = const [];
    notifyListeners();
  }

  Future<bool> ensureNotificationPermission() async {
    if (!_notificationService.isAvailable) {
      await _notificationService.initialize();
    }
    if (_notificationService.permissionGranted) return true;
    return _notificationService.requestPermission();
  }

  Future<Task> addTask({
    required String title,
    String? description,
    int? categoryId,
    TaskPriority? priority,
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
    final Task task = await _taskService.addTask(
      title: title,
      description: description,
      categoryId: categoryId,
      priority: priority ?? _settings.defaultPriority,
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
      subtaskTitles: subtaskTitles,
    );

    await _reloadData();
    await _refreshScheduledNotifications();
    return task;
  }

  Future<void> updateTask(Task task) async {
    await _taskService.updateTask(task);
    await _notificationCenterService?.clearNotificationsForTask(task.id);
    await _notificationService.cancelTaskNotifications(task.id);
    await _reloadData();
    await _refreshScheduledNotifications();
  }

  Future<void> toggleTask(int id) async {
    await _taskService.toggleTask(id);
    await _reloadData();
    await _refreshScheduledNotifications();
  }

  Future<void> deleteTask(int id) async {
    await _taskService.deleteTask(id);
    await _notificationCenterService?.clearNotificationsForTask(id);
    await _notificationService.cancelTaskNotifications(id);
    await _reloadData();
    await _refreshScheduledNotifications();
  }

  Future<void> setOccurrenceCompleted(
    int taskId,
    DateTime occurrenceAt,
    bool isCompleted,
  ) async {
    await _taskService.setOccurrenceCompleted(taskId, occurrenceAt, isCompleted);
    await _reloadData();
    await _refreshScheduledNotifications();
  }

  Future<void> applyTaskCompletion({
    required int taskId,
    required bool isCompleted,
    DateTime? occurrenceAt,
    RecurrenceCompletionScope? scope,
  }) async {
    final Task? task = taskById(taskId);
    if (task == null) return;
    if (!task.isRecurring || occurrenceAt == null || scope == null) {
      final Task updated = task.copyWith(
        isCompleted: isCompleted,
        completedAt: isCompleted ? DateTime.now() : null,
        seriesCompleted: false,
        seriesCompletedFrom: null,
      );
      await updateTask(updated);
      return;
    }

    switch (scope) {
      case RecurrenceCompletionScope.thisEvent:
        await setOccurrenceCompleted(taskId, occurrenceAt, isCompleted);
        break;
      case RecurrenceCompletionScope.thisAndFuture:
        await setOccurrenceSeriesCompletedFrom(taskId, occurrenceAt, isCompleted);
        break;
      case RecurrenceCompletionScope.allEvents:
        await setSeriesCompleted(taskId, isCompleted);
        break;
    }
  }

  Future<void> deleteOccurrence(int taskId, DateTime occurrenceAt) async {
    await _taskService.setOccurrenceExcluded(taskId, occurrenceAt);
    await _reloadData();
    await _refreshScheduledNotifications();
  }

  Future<void> setOccurrenceSeriesCompletedFrom(
    int taskId,
    DateTime occurrenceAt,
    bool isCompleted,
  ) async {
    await _taskService.setOccurrenceSeriesCompletedFrom(
      taskId,
      occurrenceAt,
      isCompleted,
    );
    await _reloadData();
    await _refreshScheduledNotifications();
  }

  Future<void> setSeriesCompleted(int taskId, bool isCompleted) async {
    await _taskService.setSeriesCompleted(taskId, isCompleted);
    await _notificationCenterService?.clearNotificationsForTask(taskId);
    await _notificationService.cancelTaskNotifications(taskId);
    await _reloadData();
    await _refreshScheduledNotifications();
  }

  /// Creates a detached, non-recurring task from one occurrence and excludes
  /// that occurrence from the original series so the series settings stay intact.
  Future<void> editOccurrenceAsTask({
    required Task original,
    required DateTime occurrenceAt,
    required String title,
    required String description,
    DateTime? dueDate,
    DateTime? endAt,
    DateTime? reminderAt,
    required bool isAllDay,
    int? categoryId,
    TaskPriority? priority,
  }) async {
    await addTask(
      title: title,
      description: description,
      categoryId: categoryId ?? original.categoryId,
      priority: priority ?? original.priority,
      dueDate: dueDate,
      endAt: endAt,
      reminderAt: reminderAt,
      isAllDay: isAllDay,
      recurrence: RecurrencePattern.never,
    );
    await _taskService.setOccurrenceExcluded(original.id, occurrenceAt);
    await _reloadData();
    await _refreshScheduledNotifications();
  }

  TaskOccurrenceState? occurrenceStateFor(int taskId, DateTime occurrenceAt) {
    return _occurrenceStates[TaskOccurrenceState.keyFor(taskId, occurrenceAt)];
  }

  bool isOccurrenceCompleted(int taskId, DateTime occurrenceAt) {
    final Task? task = taskById(taskId);
    if (task == null) return false;
    return OccurrenceUtils.isCompletedFor(task, occurrenceAt, _occurrenceStates);
  }

  List<TaskOccurrence> occurrencesForTask(
    Task task, {
    required DateTime from,
    required DateTime until,
  }) {
    if (!task.isRecurring) {
      if (task.dueDate == null) return const [];
      final DateTime due = task.dueDate!.toLocal();
      if (due.isBefore(from) || due.isAfter(until)) return const [];
      return [
        TaskOccurrence(task: task, occurrenceAt: due, isCompleted: task.isCompleted),
      ];
    }
    const RecurrenceService recurrence = RecurrenceService();
    final List<DateTime> dates = recurrence.occurrences(
      task,
      from: from,
      until: until,
    );
    final List<TaskOccurrence> result = <TaskOccurrence>[];
    for (final DateTime date in dates) {
      final DateTime at = date.toLocal();
      final TaskOccurrenceState? state = occurrenceStateFor(task.id, at);
      if (state?.isExcluded == true) continue;
      result.add(
        TaskOccurrence(
          task: task,
          occurrenceAt: at,
          isCompleted: state?.isCompleted ?? false,
        ),
      );
    }
    return result;
  }

  Future<void> addSubtask(int taskId, String title) async {
    await _taskService.addSubtask(taskId: taskId, title: title);
    await _reloadData();
  }

  Future<void> toggleSubtask(Subtask subtask) async {
    await _taskService.toggleSubtask(subtask);
    await _reloadData();
  }

  Future<void> deleteSubtask(int subtaskId) async {
    await _taskService.deleteSubtask(subtaskId);
    await _reloadData();
  }

  Future<Category> addCategory({
    required String name,
    required int colorValue,
    required int iconCodePoint,
  }) async {
    final Category category = await _categoryService.addCategory(
      name: name,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
    );
    await _reloadData();
    return category;
  }

  Future<void> updateCategory({
    required Category category,
    required String name,
    required int colorValue,
    required int iconCodePoint,
  }) async {
    await _categoryService.updateCategory(
      category: category,
      name: name,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
    );
    await _reloadData();
  }

  Future<void> deleteCategory(int id) async {
    await _categoryService.deleteCategory(id);
    await _reloadData();
  }

  Future<void> clearCompletedTasks() async {
    await _taskService.clearCompletedTasks();
    await _reloadData();
    await _refreshScheduledNotifications();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _settingsService.save(_settings);
    notifyListeners();
  }

  /// Returns `false` when permission was denied, so the UI can explain it.
  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      final bool granted = await ensureNotificationPermission();
      if (!granted) return false;
      _settings = _settings.copyWith(notificationsEnabled: true);
      await _settingsService.save(_settings);
      await _rescheduleReminders();
    } else {
      _settings = _settings.copyWith(notificationsEnabled: false);
      await _settingsService.save(_settings);
      await _notificationService.cancelAll();
    }
    notifyListeners();
    return true;
  }

  Future<void> setDefaultPriority(TaskPriority priority) async {
    _settings = _settings.copyWith(defaultPriority: priority);
    await _settingsService.save(_settings);
    notifyListeners();
  }

  Future<void> setStartOfWeek(int startOfWeek) async {
    _settings = _settings.copyWith(startOfWeek: startOfWeek);
    await _settingsService.save(_settings);
    notifyListeners();
  }

  Future<void> setSortOption(TaskSortOption option) async {
    _settings = _settings.copyWith(sortOption: option);
    await _settingsService.save(_settings);
    notifyListeners();
  }

  Future<void> _scheduleTaskNotifications(Task task) async {
    if (task.isCompleted || task.dueDate == null) return;

    final DateTime now = DateTime.now();
    final List<DateTime> occurrences = task.recurrence == RecurrencePattern.never
        ? <DateTime>[task.dueDate!.toLocal()]
        : OccurrenceUtils.expandTask(
            task,
            from: now,
            until: now.add(const Duration(days: 365)),
            states: _occurrenceStates,
          ).where((o) => !o.isCompleted).map((o) => o.occurrenceAt).toList();

    final Duration? reminderOffset = task.reminderAt == null
        ? null
        : task.dueDate!.difference(task.reminderAt!).abs();

    for (int index = 0; index < occurrences.length && index < 64; index++) {
      final DateTime occurrence = occurrences[index];
      if (reminderOffset != null) {
        await _notificationService.scheduleTaskReminderAt(
          task,
          occurrence.subtract(reminderOffset),
          task.id + (index * 1000000),
        );
      }
      await _notificationService.scheduleTaskDueAlertAt(
        task,
        occurrence,
        NotificationService.dueAlertIdForTask(task.id) + index,
      );
    }
  }

  Future<void> _refreshScheduledNotifications() async {
    if (_settings.notificationsEnabled) {
      await _rescheduleReminders();
    } else {
      await _notificationService.cancelAll();
    }
  }

  Future<void> _rescheduleReminders() async {
    await _notificationService.cancelAll();
    for (final Task task in _tasks) {
      if (!task.isCompleted) {
        await _scheduleTaskNotifications(task);
      }
    }
  }

  Future<String?> exportTasks() {
    return _exportService.exportToFile();
  }

  Future<ImportResult?> importTasks() async {
    final ImportResult? result = await _exportService.importFromFile();
    if (result != null) {
      await _reloadData();
      if (_settings.notificationsEnabled) {
        await _rescheduleReminders();
      }
    }
    return result;
  }

  Future<ImportResult> importTasksFromJson(String json) async {
    final ImportResult result = await _exportService.importJson(json);
    await _reloadData();
    await _refreshScheduledNotifications();
    return result;
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }
}
