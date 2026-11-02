import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../utils/category_style.dart';
import '../utils/formatting.dart';
import '../utils/theme_colors.dart';

/// A polished task card used on the home, calendar and category screens.
class TaskItem extends StatelessWidget {
  const TaskItem({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.onEdit,
    this.category,
  });

  final Task task;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color accent = priorityColor(task.priority, colors);
    final bool completed = task.isCompleted;

    final Color titleColor = completed
        ? colors.onSurfaceVariant
        : colors.onSurface;
    final TextDecoration decoration = completed
        ? TextDecoration.lineThrough
        : TextDecoration.none;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Checkbox(
                  value: completed,
                  onChanged: (_) => onToggle(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: titleColor,
                          decoration: decoration,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: decoration,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _PriorityBadge(task: task, color: accent),
                          if (category != null)
                            _CategoryLabel(category: category!),
                          if (task.dueDate != null)
                            _MetaLabel(
                              icon: Icons.event_outlined,
                              text: formatDueDate(task.dueDate!),
                              color: task.isOverdue
                                  ? colors.error
                                  : colors.onSurfaceVariant,
                              bold: task.isOverdue,
                            ),
                          if (task.reminderAt != null)
                            _MetaLabel(
                              icon: Icons.notifications_none_rounded,
                              text: formatTime(task.reminderAt!),
                              color: colors.onSurfaceVariant,
                            ),
                          if (task.subtasks.isNotEmpty)
                            _MetaLabel(
                              icon: Icons.checklist_rounded,
                              text:
                                  '${task.completedSubtaskCount}/${task.subtasks.length}',
                              color: colors.onSurfaceVariant,
                            ),
                        ],
                      ),
                      if (task.subtasks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: task.subtaskProgress,
                            minHeight: 4,
                            backgroundColor: colors.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: PopupMenuButton<String>(
                  tooltip: 'Task actions',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit?.call();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit task'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete task'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.task, required this.color});

  final Task task;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool completed = task.isCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: completed ? 0.06 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            priorityIcon(task.priority),
            size: 13,
            color: completed ? color.withValues(alpha: 0.5) : color,
          ),
          const SizedBox(width: 3),
          Text(
            task.priority.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: completed ? color.withValues(alpha: 0.5) : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color color = themeAccentColor(
      colorFromValue(category.colorValue),
      colors,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconFromCodePoint(category.iconCodePoint),
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
