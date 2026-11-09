import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/models/app_notification.dart';
import 'package:todoapp/models/task.dart';
import 'package:todoapp/services/database_service.dart';
import 'package:todoapp/services/notification_center_service.dart';

class _MemoryNotificationStore implements NotificationStore {
  final List<AppNotification> notifications = [];
  int _nextId = 1;

  @override
  Future<List<AppNotification>> getNotifications() async {
    final List<AppNotification> result = List<AppNotification>.from(
      notifications.where((item) => !item.isCleared),
    )..sort((a, b) => b.eventAt.compareTo(a.eventAt));
    return result;
  }

  @override
  Future<bool> insertNotificationIfAbsent(AppNotification notification) async {
    if (notifications.any((item) => item.dedupeKey == notification.dedupeKey)) {
      return false;
    }
    notifications.add(notification.copyWith(id: _nextId++));
    return true;
  }

  @override
  Future<void> markNotificationRead(int id) async {
    final int index = notifications.indexWhere((item) => item.id == id);
    if (index == -1) return;
    notifications[index] = notifications[index].copyWith(
      readAt: DateTime.now(),
    );
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final DateTime now = DateTime.now();
    for (int index = 0; index < notifications.length; index++) {
      notifications[index] = notifications[index].copyWith(readAt: now);
    }
  }

  @override
  Future<void> deleteNotification(int id) async {
    final int index = notifications.indexWhere((item) => item.id == id);
    if (index == -1 || notifications[index].isCleared) return;
    notifications[index] = notifications[index].copyWith(
      clearedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearNotifications() async {
    final DateTime now = DateTime.now();
    for (int index = 0; index < notifications.length; index++) {
      if (!notifications[index].isCleared) {
        notifications[index] = notifications[index].copyWith(clearedAt: now);
      }
    }
  }

  @override
  Future<void> clearNotificationsForTask(int taskId) async {
    final DateTime now = DateTime.now();
    for (int index = 0; index < notifications.length; index++) {
      final AppNotification notification = notifications[index];
      if (notification.taskId == taskId && !notification.isCleared) {
        notifications[index] = notification.copyWith(clearedAt: now);
      }
    }
  }
}

Task _task({
  required int id,
  required String title,
  bool isCompleted = false,
  DateTime? dueDate,
  DateTime? reminderAt,
}) {
  return Task(
    id: id,
    title: title,
    description: 'Description for $title',
    isCompleted: isCompleted,
    createdAt: DateTime(2024, 1, 1),
    dueDate: dueDate,
    reminderAt: reminderAt,
  );
}

void main() {
  test('notification model survives a SQLite map round trip', () {
    final AppNotification notification = AppNotification(
      id: 3,
      taskId: 7,
      type: AppNotificationType.overdue,
      title: 'Appointment missed',
      message: 'The task is still incomplete.',
      dedupeKey: 'overdue:7:2024-01-09T23:59:00.000Z',
      eventAt: DateTime.utc(2024, 1, 9, 23, 59),
      createdAt: DateTime.utc(2024, 1, 10, 8),
      readAt: DateTime.utc(2024, 1, 10, 9),
    );

    final AppNotification restored = AppNotification.fromMap(
      notification.toMap(),
    );

    expect(restored.id, 3);
    expect(restored.taskId, 7);
    expect(restored.type, AppNotificationType.overdue);
    expect(restored.title, notification.title);
    expect(restored.message, notification.message);
    expect(restored.dedupeKey, notification.dedupeKey);
    expect(restored.eventAt.toUtc(), notification.eventAt.toUtc());
    expect(restored.isRead, isTrue);
  });

  test(
    'sync saves reminders and missed appointments without duplicates',
    () async {
      final _MemoryNotificationStore store = _MemoryNotificationStore();
      final NotificationCenterService service = NotificationCenterService(
        store: store,
      );
      final DateTime now = DateTime(2024, 1, 10, 12);
      final List<Task> tasks = [
        _task(
          id: 1,
          title: 'Past appointment',
          dueDate: DateTime(2024, 1, 9, 23, 59),
          reminderAt: DateTime(2024, 1, 10, 10),
        ),
        _task(
          id: 2,
          title: 'Finished task',
          isCompleted: true,
          dueDate: DateTime(2024, 1, 9, 23, 59),
          reminderAt: DateTime(2024, 1, 10, 10),
        ),
        _task(
          id: 3,
          title: 'Future task',
          dueDate: DateTime(2024, 1, 11, 10),
          reminderAt: DateTime(2024, 1, 11, 9),
        ),
      ];

      expect(await service.sync(tasks: tasks, now: now), 2);
      expect(await service.sync(tasks: tasks, now: now), 0);
      expect(store.notifications, hasLength(2));

      final List<AppNotification> notifications = await service
          .getNotifications();
      expect(
        notifications.map((item) => item.type),
        containsAll([
          AppNotificationType.reminder,
          AppNotificationType.overdue,
        ]),
      );
      expect(notifications.every((item) => !item.isRead), isTrue);

      await service.markAsRead(notifications.first.id);
      final List<AppNotification> afterRead = await service.getNotifications();
      expect(afterRead.where((item) => !item.isRead), hasLength(1));

      await service.markAllAsRead();
      final List<AppNotification> afterAllRead = await service
          .getNotifications();
      expect(afterAllRead.every((item) => item.isRead), isTrue);

      await service.clearNotifications();
      expect(await service.getNotifications(), isEmpty);
      expect(await service.sync(tasks: tasks, now: now), 0);
      expect(await service.getNotifications(), isEmpty);
    },
  );

  test(
    'deleting one notification keeps the other and blocks re-sync',
    () async {
      final _MemoryNotificationStore store = _MemoryNotificationStore();
      final NotificationCenterService service = NotificationCenterService(
        store: store,
      );
      final DateTime now = DateTime(2024, 1, 10, 12);
      final List<Task> tasks = [
        _task(id: 1, title: 'Late task', dueDate: DateTime(2024, 1, 9, 23, 59)),
        _task(
          id: 2,
          title: 'Another late task',
          dueDate: DateTime(2024, 1, 10, 8),
        ),
      ];

      await service.sync(tasks: tasks, now: now);
      final List<AppNotification> notifications = await service
          .getNotifications();
      expect(notifications, hasLength(2));

      await service.deleteNotification(notifications.first.id);
      expect(await service.getNotifications(), hasLength(1));
      expect(await service.sync(tasks: tasks, now: now), 0);
      expect(await service.getNotifications(), hasLength(1));
    },
  );
}
