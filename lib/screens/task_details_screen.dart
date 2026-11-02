import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../state/app_controller.dart';
import '../utils/category_style.dart';
import '../utils/formatting.dart';
import '../utils/theme_colors.dart';
import 'add_task_screen.dart';

class TaskDetailsScreen extends StatelessWidget {
  const TaskDetailsScreen({
    super.key,
    required this.controller,
    required this.taskId,
  });

  final AppController controller;
  final int taskId;

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text(
          'This task and all of its subtasks will be permanently deleted.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await controller.deleteTask(taskId);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _addSubtask(BuildContext context) async {
    final String? title = await showDialog<String>(
      context: context,
      builder: (_) => const _AddSubtaskDialog(),
    );

    if (title == null) return;
    await controller.addSubtask(taskId, title);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final Task? task = controller.taskById(taskId);
        if (task == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Task details')),
            body: const Center(child: Text('This task no longer exists.')),
          );
        }

        final ThemeData theme = Theme.of(context);
        final Category? category = controller.categoryById(task.categoryId);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Task details'),
            actions: [
              IconButton(
                tooltip: task.isCompleted ? 'Reopen task' : 'Mark complete',
                onPressed: () => controller.toggleTask(task.id),
                icon: Icon(
                  task.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddTaskScreen(task: task, controller: controller),
                      ),
                    );
                  } else if (value == 'delete') {
                    await _confirmDelete(context);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit task')),
                  PopupMenuItem(value: 'delete', child: Text('Delete task')),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      icon: priorityIcon(task.priority),
                      label: '${task.priority.label} priority',
                      color: priorityColor(task.priority, theme.colorScheme),
                    ),
                    _Pill(
                      icon: task.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.pending_outlined,
                      label: task.isCompleted ? 'Completed' : 'In progress',
                      color: task.isCompleted
                          ? successColor(theme.colorScheme)
                          : theme.colorScheme.primary,
                    ),
                    if (category != null)
                      _Pill(
                        icon: iconFromCodePoint(category.iconCodePoint),
                        label: category.name,
                        color: colorFromValue(category.colorValue),
                      ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            task.description,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Card(
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.event_outlined,
                        label: 'Due date',
                        value: task.dueDate == null
                            ? 'Not set'
                            : formatDateTime(task.dueDate!),
                        valueColor: task.isOverdue
                            ? theme.colorScheme.error
                            : null,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.notifications_none_rounded,
                        label: 'Reminder',
                        value: task.reminderAt == null
                            ? 'Not set'
                            : formatDateTime(task.reminderAt!),
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Created',
                        value: formatDateTime(task.createdAt),
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.update_rounded,
                        label: 'Updated',
                        value: formatDateTime(task.updatedAt),
                      ),
                      if (task.completedAt != null) ...[
                        const Divider(),
                        _InfoRow(
                          icon: Icons.task_alt_rounded,
                          label: 'Completed',
                          value: formatDateTime(task.completedAt!),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Subtasks', style: theme.textTheme.titleLarge),
                          if (task.subtasks.isNotEmpty)
                            Text(
                              '${task.completedSubtaskCount} of '
                              '${task.subtasks.length} completed',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _addSubtask(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (task.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: task.subtaskProgress,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        for (final Subtask subtask in task.subtasks)
                          ListTile(
                            leading: Checkbox(
                              value: subtask.isCompleted,
                              onChanged: (_) =>
                                  controller.toggleSubtask(subtask),
                            ),
                            title: Text(
                              subtask.title,
                              style: TextStyle(
                                decoration: subtask.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: subtask.isCompleted
                                    ? theme.colorScheme.onSurfaceVariant
                                    : null,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Delete subtask',
                              onPressed: () =>
                                  controller.deleteSubtask(subtask.id),
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No subtasks yet. Add small steps to make progress easier.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete task'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddSubtaskDialog extends StatefulWidget {
  const _AddSubtaskDialog();

  @override
  State<_AddSubtaskDialog> createState() => _AddSubtaskDialogState();
}

class _AddSubtaskDialogState extends State<_AddSubtaskDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Subtask cannot be empty');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add subtask'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'What is the next step?',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
