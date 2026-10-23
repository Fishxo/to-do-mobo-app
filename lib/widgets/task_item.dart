import 'package:flutter/material.dart';

import '../models/task.dart';

/// A single row in the task list: checkbox, title, description and delete.
class TaskItem extends StatelessWidget {
  const TaskItem({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Completed tasks look faded and their title is crossed out.
    final Color textColor = task.isCompleted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    final TextDecoration decoration =
        task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (_) => onToggle(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor,
                        decoration: decoration,
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: task.isCompleted
                              ? theme.colorScheme.outline
                              : theme.colorScheme.onSurfaceVariant,
                          decoration: decoration,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete task',
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
