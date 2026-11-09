import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../state/app_controller.dart';
import '../utils/formatting.dart';
import '../widgets/empty_task_view.dart';
import 'task_details_screen.dart';

/// Persistent in-app notification list.
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _openNotification(
    BuildContext context,
    AppNotification notification,
  ) async {
    if (!notification.isRead) {
      await controller.markNotificationRead(notification.id);
    }
    if (!context.mounted) return;

    final int? taskId = notification.taskId;
    if (taskId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('The related task no longer exists.')),
        );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TaskDetailsScreen(controller: controller, taskId: taskId),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text(
          'This removes every saved notification from the notification center.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.clearNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final List<AppNotification> notifications = controller.notifications;
        final int unreadCount = controller.unreadNotificationCount;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (unreadCount > 0)
                IconButton(
                  key: const Key('notifications-mark-all-read'),
                  tooltip: 'Mark all as read',
                  onPressed: controller.markAllNotificationsRead,
                  icon: const Icon(Icons.done_all_rounded),
                ),
              if (notifications.isNotEmpty)
                IconButton(
                  key: const Key('notifications-clear'),
                  tooltip: 'Clear notifications',
                  onPressed: () => _confirmClear(context),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: notifications.isEmpty
              ? const EmptyTaskView(
                  title: 'No notifications',
                  message: 'Task reminders and missed appointments will appear here.',
                  icon: Icons.notifications_none_rounded,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final AppNotification notification = notifications[index];
                    return _NotificationTile(
                      notification: notification,
                      onTap: () => _openNotification(context, notification),
                      onMarkRead: () =>
                          controller.markNotificationRead(notification.id),
                      onDelete: () =>
                          controller.deleteNotification(notification.id),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool unread = !notification.isRead;
    final bool isOverdue = notification.type == AppNotificationType.overdue;
    final Color accent = isOverdue ? colors.error : colors.primary;

    return Card(
      key: Key('notification-${notification.id}'),
      color: unread
          ? Color.alphaBlend(
              accent.withValues(alpha: 0.07),
              colors.surfaceContainerLowest,
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isOverdue
                      ? Icons.event_busy_outlined
                      : Icons.notifications_active_outlined,
                  size: 21,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formatDateTime(notification.eventAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: unread ? 'Unread' : 'Read',
                          color: unread ? accent : colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unread)
                    IconButton(
                      key: Key('notification-mark-read-${notification.id}'),
                      tooltip: 'Mark as read',
                      visualDensity: VisualDensity.compact,
                      onPressed: onMarkRead,
                      icon: const Icon(Icons.done_rounded, size: 20),
                    ),
                  IconButton(
                    key: Key('notification-delete-${notification.id}'),
                    tooltip: 'Delete notification',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
