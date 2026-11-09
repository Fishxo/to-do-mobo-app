import 'package:intl/intl.dart';

import '../models/app_notification.dart';
import '../models/task.dart';
import '../models/task_occurrence.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'recurrence_service.dart';

/// Creates, persists and manages in-app notifications.
///
/// The platform notification service still shows the Android/iOS pop-ups.
/// This service stores a copy in SQLite so the Notification Center can show
/// the same history after the pop-up is gone or the app is restarted.
class NotificationCenterService {
  NotificationCenterService({
    required this.store,
    NotificationService? notificationService,
  }) : _notificationService =
           notificationService ?? NotificationService.instance;

  final NotificationStore store;
  final NotificationService _notificationService;

  NotificationService get platformNotifications => _notificationService;

  static String reminderDedupeKey(int taskId, DateTime eventAt) {
    return 'reminder:$taskId:${eventAt.toUtc().toIso8601String()}';
  }

  static String overdueDedupeKey(int taskId, DateTime eventAt) {
    return 'overdue:$taskId:${eventAt.toUtc().toIso8601String()}';
  }

  static String overdueTitleFor(Task task) => 'Appointment missed';

  static String overdueMessageFor(Task task) {
    final DateTime? dueDate = task.dueDate;
    if (dueDate == null) {
      return '"${task.title}" passed its scheduled time and is still '
          'incomplete.';
    }
    final String when = DateFormat('MMM d, yyyy · h:mm a')
        .format(dueDate.toLocal());
    return '"${task.title}" was due $when and is still incomplete.';
  }

  Future<List<AppNotification>> getNotifications() {
    return store.getNotifications();
  }

  /// Saves a notification for every reminder or due appointment that has
  /// already passed while its task is still incomplete.
  ///
  /// Duplicate records are prevented by the unique dedupe key in SQLite.
  Future<int> sync({
    required List<Task> tasks,
    DateTime? now,
    Map<String, TaskOccurrenceState> occurrenceStates = const {},
  }) async {
    final DateTime currentTime = (now ?? DateTime.now()).toLocal();
    final DateTime createdAt = DateTime.now();
    int inserted = 0;
    const RecurrenceService recurrence = RecurrenceService();

    for (final Task task in tasks) {
      if (task.isCompleted) continue;

      final DateTime? dueAt = task.dueDate?.toLocal();
      final Duration? reminderOffset = dueAt == null || task.reminderAt == null
          ? null
          : dueAt.difference(task.reminderAt!.toLocal());

      if (dueAt != null && task.isRecurring) {
        final List<DateTime> occurrences = recurrence.occurrences(
          task,
          from: DateTime(currentTime.year - 1),
          until: currentTime,
        );
        for (final DateTime occurrence in occurrences) {
          final TaskOccurrenceState? state =
              occurrenceStates[TaskOccurrenceState.keyFor(task.id, occurrence)];
          if (state?.isExcluded == true || state?.isCompleted == true) continue;
          if (reminderOffset != null) {
            final DateTime reminderAt = occurrence.subtract(reminderOffset);
            if (!reminderAt.isAfter(currentTime)) {
              final bool saved = await store.insertNotificationIfAbsent(
                AppNotification(
                  id: 0,
                  taskId: task.id,
                  type: AppNotificationType.reminder,
                  title: NotificationService.notificationTitleFor(task),
                  message: NotificationService.notificationBodyFor(task),
                  dedupeKey: reminderDedupeKey(task.id, reminderAt),
                  eventAt: reminderAt,
                  createdAt: createdAt,
                ),
              );
              if (saved) inserted++;
            }
          }
          final bool saved = await store.insertNotificationIfAbsent(
            AppNotification(
              id: 0,
              taskId: task.id,
              type: AppNotificationType.overdue,
              title: overdueTitleFor(task),
              message: overdueMessageFor(task),
              dedupeKey: overdueDedupeKey(task.id, occurrence),
              eventAt: occurrence,
              createdAt: createdAt,
            ),
          );
          if (saved) inserted++;
        }
        continue;
      }

      final DateTime? reminderAt = task.reminderAt?.toLocal();
      if (reminderAt != null && !reminderAt.isAfter(currentTime)) {
        final bool saved = await store.insertNotificationIfAbsent(
          AppNotification(
            id: 0,
            taskId: task.id,
            type: AppNotificationType.reminder,
            title: NotificationService.notificationTitleFor(task),
            message: NotificationService.notificationBodyFor(task),
            dedupeKey: reminderDedupeKey(task.id, reminderAt),
            eventAt: reminderAt,
            createdAt: createdAt,
          ),
        );
        if (saved) inserted++;
      }

      if (dueAt != null && !dueAt.isAfter(currentTime)) {
        final bool saved = await store.insertNotificationIfAbsent(
          AppNotification(
            id: 0,
            taskId: task.id,
            type: AppNotificationType.overdue,
            title: overdueTitleFor(task),
            message: overdueMessageFor(task),
            dedupeKey: overdueDedupeKey(task.id, dueAt),
            eventAt: dueAt,
            createdAt: createdAt,
          ),
        );
        if (saved) inserted++;
      }
    }

    return inserted;
  }

  Future<void> markAsRead(int id) {
    return store.markNotificationRead(id);
  }

  Future<void> markAllAsRead() {
    return store.markAllNotificationsRead();
  }

  Future<void> deleteNotification(int id) {
    return store.deleteNotification(id);
  }

  Future<void> clearNotifications() {
    return store.clearNotifications();
  }

  Future<void> clearNotificationsForTask(int taskId) {
    return store.clearNotificationsForTask(taskId);
  }
}
