import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

/// Wraps local notification setup, permissions and scheduling.
///
/// All methods are safe to call in tests or on platforms without the plugin:
/// failures are contained here instead of reaching the UI as crashes.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static final NotificationService instance = NotificationService();

  static const String _channelId = 'task_reminders';
  static const String _channelName = 'Task reminders';
  static const String _channelDescription =
      'Reminders for tasks with a selected time';

  /// Prefix used in the notification payload so a task id can be recognised
  /// even if another notification type is added later.
  static const String taskPayloadPrefix = 'task:';

  /// Shown when a task has no description instead of leaving the body empty.
  static const String emptyDescriptionFallback = 'Tap to view this task.';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  bool _permissionGranted = false;

  void Function(int taskId)? _onTaskSelected;
  int? _pendingTaskId;

  bool get isAvailable => _initialized;
  bool get permissionGranted => _permissionGranted;

  /// Builds the payload stored with a scheduled reminder.
  static String payloadForTask(int taskId) => '$taskPayloadPrefix$taskId';

  /// Reads a task id from a notification payload.
  ///
  /// Both `task:42` (current format) and `42` (older reminders that are
  /// already scheduled on a device) are accepted.
  static int? parseTaskIdFromPayload(String? payload) {
    if (payload == null) return null;

    final String value = payload.startsWith(taskPayloadPrefix)
        ? payload.substring(taskPayloadPrefix.length)
        : payload;
    final int? taskId = int.tryParse(value.trim());
    if (taskId == null || taskId <= 0) return null;
    return taskId;
  }

  /// The notification title is always the task title.
  static String notificationTitleFor(Task task) => task.title;

  /// The notification body is the task description, with a readable fallback
  /// when the task has no description.
  static String notificationBodyFor(Task task) {
    final String description = task.description.trim();
    return description.isEmpty ? emptyDescriptionFallback : description;
  }

  /// Registers the callback used to open a task when its reminder is tapped.
  ///
  /// If a notification was tapped before a handler was registered, the stored
  /// task id is delivered as soon as the handler is set.
  void setTaskSelectionHandler(void Function(int taskId)? handler) {
    _onTaskSelected = handler;
    final int? pendingTaskId = _pendingTaskId;
    if (pendingTaskId != null && handler != null) {
      _pendingTaskId = null;
      handler(pendingTaskId);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.notificationResponseType !=
        NotificationResponseType.selectedNotification) {
      return;
    }
    handleNotificationPayload(response.payload);
  }

  /// Processes a notification payload as if the user tapped the notification.
  ///
  /// The platform callback uses this method. It is public so the tap flow can
  /// also be exercised from tests without a real Android device.
  void handleNotificationPayload(String? payload) {
    final int? taskId = parseTaskIdFromPayload(payload);
    if (taskId == null) return;

    final void Function(int taskId)? handler = _onTaskSelected;
    if (handler == null) {
      _pendingTaskId = taskId;
    } else {
      handler(taskId);
    }
  }

  /// Returns the task id when the app was launched by tapping a reminder.
  ///
  /// This is the cold-start path: the app was terminated and the notification
  /// tap started the process.
  Future<int?> getLaunchTaskId() async {
    await initialize();
    if (!_initialized) return null;

    try {
      final NotificationAppLaunchDetails? details = await _plugin
          .getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return parseTaskIdFromPayload(details.notificationResponse?.payload);
    } catch (error) {
      debugPrint('Could not read notification launch details: $error');
      return null;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          );

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
      _initialized = true;
    } catch (error) {
      _initialized = false;
      debugPrint('Notifications unavailable: $error');
    }
  }

  /// Requests notification permission and, on Android 12+, exact alarm
  /// permission. Returns whether notifications may be shown.
  Future<bool> requestPermission() async {
    await initialize();
    if (!_initialized) return false;

    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final bool? granted = await android.requestNotificationsPermission();
        await android.requestExactAlarmsPermission();
        _permissionGranted = granted ?? false;
        return _permissionGranted;
      }

      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final bool? granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permissionGranted = granted ?? false;
        return _permissionGranted;
      }

      // macOS and desktop platforms do not have a mobile permission prompt.
      _permissionGranted = true;
      return true;
    } catch (error) {
      debugPrint('Could not request notification permission: $error');
      return false;
    }
  }

  /// Schedules a reminder for [task]. Returns false when the reminder is in
  /// the past or the platform refused to schedule it.
  Future<bool> scheduleTaskReminder(Task task) async {
    final DateTime? reminderAt = task.reminderAt;
    if (reminderAt == null || task.isCompleted) return false;
    if (!reminderAt.isAfter(DateTime.now())) return false;

    await initialize();
    if (!_initialized) return false;

    final String description = task.description.trim();
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        // Show the full description when the notification is expanded.
        styleInformation: description.isEmpty
            ? null
            : BigTextStyleInformation(
                description,
                contentTitle: notificationTitleFor(task),
              ),
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    final tz.TZDateTime scheduled = tz.TZDateTime.from(
      reminderAt.toUtc(),
      tz.UTC,
    );
    final String title = notificationTitleFor(task);
    final String body = notificationBodyFor(task);
    final String payload = payloadForTask(task.id);

    try {
      await _plugin.zonedSchedule(
        id: task.id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      return true;
    } catch (error) {
      // Some devices deny exact alarms. Fall back to an inexact reminder
      // instead of silently dropping it.
      try {
        await _plugin.zonedSchedule(
          id: task.id,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        return true;
      } catch (fallbackError) {
        debugPrint('Could not schedule reminder: $fallbackError');
        return false;
      }
    }
  }

  Future<void> cancelReminder(int taskId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: taskId);
    } catch (error) {
      debugPrint('Could not cancel reminder: $error');
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Could not cancel reminders: $error');
    }
  }
}
