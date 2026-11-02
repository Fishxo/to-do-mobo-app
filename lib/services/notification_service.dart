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

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  bool _permissionGranted = false;

  bool get isAvailable => _initialized;
  bool get permissionGranted => _permissionGranted;

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

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    final tz.TZDateTime scheduled = tz.TZDateTime.from(
      reminderAt.toUtc(),
      tz.UTC,
    );

    try {
      await _plugin.zonedSchedule(
        id: task.id,
        title: 'Task reminder',
        body: task.title,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: task.id.toString(),
      );
      return true;
    } catch (error) {
      // Some devices deny exact alarms. Fall back to an inexact reminder
      // instead of silently dropping it.
      try {
        await _plugin.zonedSchedule(
          id: task.id,
          title: 'Task reminder',
          body: task.title,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: task.id.toString(),
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
