import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../services/category_service.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/statistics_service.dart';
import '../services/task_service.dart';

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
  }) {
    _taskService = taskService ?? TaskService.instance;
    _categoryService =
        categoryService ?? CategoryService(store: _taskService.store);
    _settingsService = settingsService ?? SettingsService.instance;
    _notificationService = notificationService ?? NotificationService.instance;
    _exportService = ExportService(
      taskService: _taskService,
      categoryService: _categoryService,
    );
  }

  late final TaskService _taskService;
  late final CategoryService _categoryService;
  late final SettingsService _settingsService;
  late final NotificationService _notificationService;
  late final ExportService _exportService;

  List<Task> _tasks = const [];
  List<Category> _categories = const [];
  AppSettings _settings = const AppSettings();
  bool _isLoading = true;
  String? _errorMessage;

  List<Task> get tasks => _tasks;
  List<Category> get categories => _categories;
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get notificationsAvailable => _notificationService.isAvailable;
  bool get notificationPermissionGranted =>
      _notificationService.permissionGranted;

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
    DateTime? reminderAt,
    List<String> subtaskTitles = const [],
  }) async {
    final Task task = await _taskService.addTask(
      title: title,
      description: description,
      categoryId: categoryId,
      priority: priority ?? _settings.defaultPriority,
      dueDate: dueDate,
      reminderAt: reminderAt,
      subtaskTitles: subtaskTitles,
    );

    if (_settings.notificationsEnabled) {
      await _notificationService.scheduleTaskReminder(task);
    }
    await _reloadData();
    return task;
  }

  Future<void> updateTask(Task task) async {
    await _taskService.updateTask(task);

    if (!_settings.notificationsEnabled || task.isCompleted) {
      await _notificationService.cancelReminder(task.id);
    } else {
      await _notificationService.cancelReminder(task.id);
      await _notificationService.scheduleTaskReminder(task);
    }
    await _reloadData();
  }

  Future<void> toggleTask(int id) async {
    final Task updated = await _taskService.toggleTask(id);
    if (updated.isCompleted) {
      await _notificationService.cancelReminder(updated.id);
    } else if (_settings.notificationsEnabled) {
      await _notificationService.scheduleTaskReminder(updated);
    }
    await _reloadData();
  }

  Future<void> deleteTask(int id) async {
    await _notificationService.cancelReminder(id);
    await _taskService.deleteTask(id);
    await _reloadData();
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

  Future<void> _rescheduleReminders() async {
    await _notificationService.cancelAll();
    for (final Task task in _tasks) {
      if (!task.isCompleted && task.reminderAt != null) {
        await _notificationService.scheduleTaskReminder(task);
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
    return result;
  }
}
