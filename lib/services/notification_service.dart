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

  // Android never allows raising importance on an existing channel. v4 forces
  // devices that may have cached an earlier low-importance v3 channel onto a
  // fresh HIGH channel. Startup then cancels and rebuilds pending reminders.
  static const String androidChannelId = 'task_reminders_v4_heads_up';
  static const String _channelId = androidChannelId;
  static const List<String> _legacyChannelIds = <String>[
    'task_reminders',
    'task_reminders_v2_high',
    'task_reminders_v3_heads_up',
  ];
  static const String _channelName = 'Task reminders';
  static const String _channelDescription =
      'Reminders for tasks with a selected time';

  /// Canonical Android channel configuration used for both channel creation
  /// and all scheduled reminder/due notifications.
  static const AndroidNotificationChannel androidReminderChannel =
      AndroidNotificationChannel(
        androidChannelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
        audioAttributesUsage: AudioAttributesUsage.notification,
      );

  /// Prefix used in the notification payload so a task id can be recognised
  /// even if another notification type is added later.
  static const String taskPayloadPrefix = 'task:';

  /// Shown when a task has no description instead of leaving the body empty.
  static const String emptyDescriptionFallback = 'Tap to view this task.';

  /// Due alerts use a different platform notification id from reminders so
  /// both can coexist for the same task without overwriting each other.
  static const int dueAlertIdOffset = 500000;

  static int dueAlertIdForTask(int taskId) => dueAlertIdOffset + taskId;

  static String dueAlertTitleFor(Task task) => 'Task due: ${task.title}';

  /// Converts an intended local DateTime into the absolute instant accepted
  /// by zonedSchedule. UTC is used as the TZDateTime location intentionally:
  /// the instant is preserved, and Android renders/delivers it in device time.
  static tz.TZDateTime scheduledDateFor(DateTime scheduledAt) {
    return tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC);
  }

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
      await _configureAndroidChannel();
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
            // Check first so Android 13+ is prompted only when needed, then query
            // again: a null/failed request result must never be treated as granted.
            final bool enabledBeforeRequest =
                await android.areNotificationsEnabled() ?? false;
            if (!enabledBeforeRequest) {
              await android.requestNotificationsPermission();
            }
            _permissionGranted =
                await android.areNotificationsEnabled() ?? false;
        await android.requestExactAlarmsPermission();
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

  /// Opens Android's notification settings for this app. Android owns the
  /// final pop-up and launcher-badge preferences, so they cannot be enabled
  /// or overridden by notification payload flags.
  Future<bool> openAndroidNotificationSettings() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.openAppNotificationSettings() ?? false;
    } catch (error) {
      debugPrint('Could not open Android notification settings: $error');
      return false;
    }
  }

  Future<void> _configureAndroidChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    for (final String legacyId in _legacyChannelIds) {
      try {
        // Remove legacy channels so stale importance/sound settings do not
        // interfere on devices that still have them cached.
        await android.deleteNotificationChannel(channelId: legacyId);
      } catch (error) {
        debugPrint('Could not delete legacy notification channel $legacyId: $error');
      }
    }

    try {
      await android.createNotificationChannel(androidReminderChannel);
      final List<AndroidNotificationChannel>? channels = await android
          .getNotificationChannels();
      AndroidNotificationChannel? configured;
      if (channels != null) {
        for (final AndroidNotificationChannel channel in channels) {
          if (channel.id == _channelId) {
            configured = channel;
            break;
          }
        }
      }
      if (configured != null &&
          (configured.importance.value < Importance.high.value ||
              !configured.playSound ||
            !configured.enableVibration ||
            !configured.showBadge)) {
        debugPrint(
          'Reminder channel $_channelId is restricted by Android settings '
          '(importance=${configured.importance}, sound=${configured.playSound}, '
          'vibration=${configured.enableVibration}, badge=${configured.showBadge}). '
          'Enable pop-up, sound, vibration, and app-icon badges for this '
          'channel in system settings.',
        );
      }
    } catch (error) {
      // Do not silently schedule to an unknown/default channel. Initialization
      // will fail and can be retried on the next app launch.
      debugPrint('Could not create or inspect notification channel: $error');
      rethrow;
    }
  }

  /// Schedules a reminder for [task]. Returns false when the reminder is in
  /// the past or the platform refused to schedule it.
  Future<bool> scheduleTaskReminder(Task task) async {
    final DateTime? reminderAt = task.reminderAt;
    if (reminderAt == null) return false;

    return scheduleTaskReminderAt(task, reminderAt);
  }

  /// Schedules a reminder at an explicit time, which is used for recurring
  /// occurrences. [notificationId] must be unique per occurrence so later
  /// occurrences do not replace earlier ones.
  Future<bool> scheduleTaskReminderAt(
    Task task,
    DateTime scheduledAt, [
    int? notificationId,
  ]) async {
    if (task.isCompleted) return false;

    return _scheduleTaskNotification(
      task,
      notificationId: notificationId ?? task.id,
      scheduledAt: scheduledAt,
      title: notificationTitleFor(task),
    );
  }

  /// Schedules an alert for when a task's due time arrives. This lets the
  /// platform warn the user about an appointment even if the app is closed.
  Future<bool> scheduleTaskDueAlert(Task task) async {
    final DateTime? dueDate = task.dueDate;
    if (dueDate == null) return false;

    return scheduleTaskDueAlertAt(task, dueDate);
  }

  /// Schedules a due alert for one recurring occurrence at [scheduledAt].
  Future<bool> scheduleTaskDueAlertAt(
    Task task,
    DateTime scheduledAt, [
    int? notificationId,
  ]) async {
    if (task.isCompleted) return false;

    return _scheduleTaskNotification(
      task,
      notificationId: notificationId ?? dueAlertIdForTask(task.id),
      scheduledAt: scheduledAt,
      title: dueAlertTitleFor(task),
    );
  }

  Future<bool> _scheduleTaskNotification(
    Task task, {
    required int notificationId,
    required DateTime scheduledAt,
    required String title,
  }) async {
    if (!scheduledAt.isAfter(DateTime.now())) return false;

    await initialize();
    if (!_initialized) return false;

    final String description = task.description.trim();
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        onlyAlertOnce: true,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        when: scheduledAt.millisecondsSinceEpoch,
        usesChronometer: false,
        ticker: title,
        channelShowBadge: true,
        // Ask supported launchers (including Samsung One UI) to display a
        // numeric count; Android may still honor the user's badge preference.
        number: 1,
        autoCancel: true,
        // Show the full description when the notification is expanded.
        styleInformation: description.isEmpty
            ? null
            : BigTextStyleInformation(description, contentTitle: title),
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    final tz.TZDateTime scheduled = scheduledDateFor(scheduledAt);
    final String body = notificationBodyFor(task);
    final String payload = payloadForTask(task.id);

    try {
      await _plugin.zonedSchedule(
        id: notificationId,
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
          id: notificationId,
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

  Future<void> cancelTaskDueAlert(int taskId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: dueAlertIdForTask(taskId));
    } catch (error) {
      debugPrint('Could not cancel due alert: $error');
    }
  }

  /// Cancels the base and recurring-occurrence notifications scheduled for a
  /// task. [maxOccurrences] should cover the window used when scheduling.
  Future<void> cancelTaskNotifications(
    int taskId, {
    int maxOccurrences = 64,
  }) async {
    if (!_initialized) return;
    for (int index = 0; index < maxOccurrences; index++) {
      final int reminderId = taskId + (index * 1000000);
      final int dueId = dueAlertIdForTask(taskId) + index;
      try {
        await _plugin.cancel(id: reminderId);
      } catch (_) {}
      try {
        await _plugin.cancel(id: dueId);
      } catch (_) {}
      if (index == 0) {
        try {
          await _plugin.cancel(id: taskId);
        } catch (_) {}
        try {
          await _plugin.cancel(id: dueAlertIdForTask(taskId));
        } catch (_) {}
      }
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
