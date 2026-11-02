import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/task.dart';
import '../state/app_controller.dart';
import '../utils/formatting.dart';
import '../utils/theme_colors.dart';
import '../widgets/empty_task_view.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/task_item.dart';
import 'add_task_screen.dart';
import 'task_details_screen.dart';

/// Which subset of tasks is currently visible.
enum TaskFilter { all, today, upcoming, completed, overdue }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, this.onOpenSettings});

  final AppController controller;
  final VoidCallback? onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TaskFilter _filter = TaskFilter.all;

  AppController get _controller => widget.controller;

  List<Task> get _visibleTasks {
    final DateTime now = DateTime.now();
    final DateTime startOfTomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    final List<Task> filtered;
    switch (_filter) {
      case TaskFilter.all:
        filtered = _controller.tasks.toList();
      case TaskFilter.today:
        filtered = _controller.tasks
            .where(
              (task) => task.dueDate != null && isSameDay(task.dueDate!, now),
            )
            .toList();
      case TaskFilter.upcoming:
        filtered = _controller.tasks
            .where(
              (task) =>
                  !task.isCompleted &&
                  task.dueDate != null &&
                  task.dueDate!.isAfter(startOfTomorrow),
            )
            .toList();
      case TaskFilter.completed:
        filtered = _controller.tasks.where((task) => task.isCompleted).toList();
      case TaskFilter.overdue:
        filtered = _controller.tasks.where((task) => task.isOverdue).toList();
    }

    filtered.sort(
      (a, b) => _compareTasks(a, b, _controller.settings.sortOption),
    );
    return filtered;
  }

  int _compareTasks(Task a, Task b, TaskSortOption option) {
    switch (option) {
      case TaskSortOption.dueDate:
        final DateTime? aDue = a.dueDate;
        final DateTime? bDue = b.dueDate;
        if (aDue == null && bDue == null) {
          return b.createdAt.compareTo(a.createdAt);
        }
        if (aDue == null) return 1;
        if (bDue == null) return -1;
        final int byDue = aDue.compareTo(bDue);
        if (byDue != 0) return byDue;
        return b.priority.value.compareTo(a.priority.value);
      case TaskSortOption.priority:
        final int byPriority = b.priority.value.compareTo(a.priority.value);
        if (byPriority != 0) return byPriority;
        final DateTime? aDue = a.dueDate;
        final DateTime? bDue = b.dueDate;
        if (aDue == null && bDue == null) return 0;
        if (aDue == null) return 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      case TaskSortOption.createdDate:
        return b.createdAt.compareTo(a.createdAt);
    }
  }

  int _countFor(TaskFilter filter) {
    final DateTime now = DateTime.now();
    final DateTime startOfTomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    switch (filter) {
      case TaskFilter.all:
        return _controller.tasks.length;
      case TaskFilter.today:
        return _controller.tasks
            .where(
              (task) => task.dueDate != null && isSameDay(task.dueDate!, now),
            )
            .length;
      case TaskFilter.upcoming:
        return _controller.tasks
            .where(
              (task) =>
                  !task.isCompleted &&
                  task.dueDate != null &&
                  task.dueDate!.isAfter(startOfTomorrow),
            )
            .length;
      case TaskFilter.completed:
        return _controller.tasks.where((task) => task.isCompleted).length;
      case TaskFilter.overdue:
        return _controller.tasks.where((task) => task.isOverdue).length;
    }
  }

  String get _emptyTitle {
    switch (_filter) {
      case TaskFilter.all:
        return 'No tasks yet';
      case TaskFilter.today:
        return 'Nothing due today';
      case TaskFilter.upcoming:
        return 'No upcoming tasks';
      case TaskFilter.completed:
        return 'No completed tasks';
      case TaskFilter.overdue:
        return 'Nothing overdue';
    }
  }

  String get _emptyMessage {
    switch (_filter) {
      case TaskFilter.all:
        return 'Tap the + button to create your first task.';
      case TaskFilter.today:
        return 'Enjoy the clear day, or add something for today.';
      case TaskFilter.upcoming:
        return 'Tasks with future due dates will appear here.';
      case TaskFilter.completed:
        return 'Finished tasks will show up here.';
      case TaskFilter.overdue:
        return 'Great news — you are all caught up.';
    }
  }

  Future<void> _openAddTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTaskScreen(controller: _controller)),
    );
  }

  Future<void> _openTask(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TaskDetailsScreen(controller: _controller, taskId: task.id),
      ),
    );
  }

  Future<void> _editTask(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(task: task, controller: _controller),
      ),
    );
  }

  Future<void> _toggleTask(Task task) async {
    try {
      await _controller.toggleTask(task.id);
    } catch (_) {
      _showError('Could not update the task. Please try again.');
    }
  }

  Future<void> _confirmDelete(Task task) async {
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

    try {
      await _controller.deleteTask(task.id);
    } catch (_) {
      _showError('Could not delete the task. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showNotificationInfo() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final bool enabled = _controller.settings.notificationsEnabled;
        final bool permission = _controller.notificationPermissionGranted;
        final String message = !enabled
            ? 'Notifications are turned off. Enable them in Settings to get '
                  'reminders for your tasks.'
            : permission
            ? 'Notifications are enabled. Reminders will appear at the time '
                  'you choose for each task.'
            : 'Notifications are enabled, but permission has not been granted. '
                  'Open Settings and turn notifications off and on again to '
                  'request permission.';
        return AlertDialog(
          icon: const Icon(Icons.notifications_active_outlined),
          title: const Text('Reminders'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onOpenSettings?.call();
              },
              child: const Text('Open settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final List<Task> visibleTasks = _visibleTasks;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _controller.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  greetingFor(now),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'My Tasks',
                                  style: theme.textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatFullDate(now),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Reminders',
                            onPressed: _showNotificationInfo,
                            icon: const Icon(Icons.notifications_none_rounded),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: widget.onOpenSettings,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Total',
                              value: _controller.statistics.total,
                              icon: Icons.layers_outlined,
                              color: theme.colorScheme.primary,
                              onTap: () =>
                                  setState(() => _filter = TaskFilter.all),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Completed',
                              value: _controller.statistics.completed,
                              icon: Icons.check_circle_outline_rounded,
                              color: successColor(theme.colorScheme),
                              onTap: () => setState(
                                () => _filter = TaskFilter.completed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Pending',
                              value: _controller.statistics.pending,
                              icon: Icons.pending_outlined,
                              color: warningColor(theme.colorScheme),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Overdue',
                              value: _controller.statistics.overdue,
                              icon: Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              onTap: () =>
                                  setState(() => _filter = TaskFilter.overdue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final filter in TaskFilter.values)
                            ChoiceChip(
                              label: Text(
                                '${_filterLabel(filter)} '
                                '(${_countFor(filter)})',
                              ),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _filter == filter
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                              selected: _filter == filter,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SectionHeader(
                        title: 'Your tasks',
                        subtitle:
                            '${visibleTasks.length} '
                            '${visibleTasks.length == 1 ? 'task' : 'tasks'} in this view',
                        action: PopupMenuButton<TaskSortOption>(
                          tooltip: 'Sort tasks',
                          initialValue: _controller.settings.sortOption,
                          onSelected: _controller.setSortOption,
                          itemBuilder: (context) => [
                            for (final option in TaskSortOption.values)
                              PopupMenuItem(
                                value: option,
                                child: Text(option.label),
                              ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sort_rounded, size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  _controller.settings.sortOption.label,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (_controller.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_controller.errorMessage != null &&
                  _controller.tasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _TaskLoadError(
                    message: _controller.errorMessage!,
                    onRetry: _controller.refresh,
                  ),
                )
              else if (visibleTasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyTaskView(
                    title: _emptyTitle,
                    message: _emptyMessage,
                    icon: Icons.task_alt_rounded,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverList.builder(
                    itemCount: visibleTasks.length,
                    itemBuilder: (context, index) {
                      final Task task = visibleTasks[index];
                      return TaskItem(
                        task: task,
                        category: _controller.categoryById(task.categoryId),
                        onTap: () => _openTask(task),
                        onEdit: () => _editTask(task),
                        onToggle: () => _toggleTask(task),
                        onDelete: () => _confirmDelete(task),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Task'),
      ),
    );
  }

  String _filterLabel(TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return 'All';
      case TaskFilter.today:
        return 'Today';
      case TaskFilter.upcoming:
        return 'Upcoming';
      case TaskFilter.completed:
        return 'Completed';
      case TaskFilter.overdue:
        return 'Overdue';
    }
  }
}

class _TaskLoadError extends StatelessWidget {
  const _TaskLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
