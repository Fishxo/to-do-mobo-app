import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../state/app_controller.dart';
import '../utils/category_style.dart';
import '../widgets/category_editor_sheet.dart';
import '../widgets/empty_task_view.dart';
import '../widgets/task_item.dart';
import 'add_task_screen.dart';
import 'task_details_screen.dart';

class CategoryTasksScreen extends StatelessWidget {
  const CategoryTasksScreen({
    super.key,
    required this.controller,
    required this.categoryId,
  });

  final AppController controller;
  final int categoryId;

  Future<void> _deleteCategory(BuildContext context, Category category) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '"${category.name}" will be removed. Its tasks will become '
          'uncategorized and will not be deleted.',
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
    await controller.deleteCategory(category.id);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _openTask(BuildContext context, Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TaskDetailsScreen(controller: controller, taskId: task.id),
      ),
    );
  }

  Future<void> _editTask(BuildContext context, Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(task: task, controller: controller),
      ),
    );
  }

  Future<void> _confirmDeleteTask(BuildContext context, Task task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task.title}"? This cannot be undone.'),
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
    await controller.deleteTask(task.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final Category? category = controller.categoryById(categoryId);
        if (category == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Category')),
            body: const Center(child: Text('This category no longer exists.')),
          );
        }

        final ThemeData theme = Theme.of(context);
        final Color color = colorFromValue(category.colorValue);
        final List<Task> tasks = controller.tasksForCategory(categoryId);
        final int completed = tasks.where((task) => task.isCompleted).length;
        final double progress = tasks.isEmpty ? 0 : completed / tasks.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(category.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    CategoryEditorSheet.show(
                      context,
                      controller: controller,
                      category: category,
                    );
                  } else if (value == 'delete') {
                    _deleteCategory(context, category);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit category')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete category'),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          iconFromCodePoint(category.iconCodePoint),
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tasks.length} '
                              '${tasks.length == 1 ? 'task' : 'tasks'}',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              '$completed completed · '
                              '${tasks.length - completed} pending',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                color: color,
                                backgroundColor: color.withValues(alpha: 0.16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyTaskView(
                      title: 'No tasks in ${category.name}',
                      message:
                          'Tap the + button to add a task to this category.',
                      icon: iconFromCodePoint(category.iconCodePoint),
                    ),
                  )
                else
                  for (final Task task in tasks)
                    TaskItem(
                      task: task,
                      category: category,
                      onTap: () => _openTask(context, task),
                      onEdit: () => _editTask(context, task),
                      onToggle: () => controller.toggleTask(task.id),
                      onDelete: () => _confirmDeleteTask(context, task),
                    ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTaskScreen(
                  controller: controller,
                  initialCategoryId: categoryId,
                ),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Task'),
          ),
        );
      },
    );
  }
}
