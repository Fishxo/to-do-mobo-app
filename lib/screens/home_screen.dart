import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/empty_task_view.dart';
import '../widgets/task_item.dart';
import 'add_task_screen.dart';

/// Which subset of tasks is currently visible.
enum TaskFilter { all, active, completed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.taskService});

  final TaskService? taskService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TaskService _taskService;

  List<Task> _tasks = const [];
  TaskFilter _filter = TaskFilter.all;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _taskService = widget.taskService ?? TaskService.instance;
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final List<Task> tasks = await _taskService.getTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load your tasks. Please try again.';
      });
    }
  }

  Future<void> _retryLoad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _loadTasks();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  int get _remainingCount => _tasks.where((task) => !task.isCompleted).length;

  List<Task> get _visibleTasks {
    switch (_filter) {
      case TaskFilter.all:
        return _tasks;
      case TaskFilter.active:
        return _tasks.where((task) => !task.isCompleted).toList();
      case TaskFilter.completed:
        return _tasks.where((task) => task.isCompleted).toList();
    }
  }

  String get _emptyTitle {
    switch (_filter) {
      case TaskFilter.all:
        return 'No tasks yet';
      case TaskFilter.active:
        return 'No active tasks';
      case TaskFilter.completed:
        return 'No completed tasks';
    }
  }

  String get _emptyMessage {
    switch (_filter) {
      case TaskFilter.all:
        return 'Tap "Add Task" to create your first task.';
      case TaskFilter.active:
        return 'Everything is done. Add a new task or enjoy the break.';
      case TaskFilter.completed:
        return 'Completed tasks will appear here.';
    }
  }

  Future<void> _openAddTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(taskService: _taskService),
      ),
    );
    if (!mounted) return;
    await _loadTasks();
  }

  Future<void> _openEditTask(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(task: task, taskService: _taskService),
      ),
    );
    if (!mounted) return;
    await _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    try {
      await _taskService.toggleTask(task.id);
      await _loadTasks();
    } catch (_) {
      _showError('Could not update the task. Please try again.');
    }
  }

  Future<void> _confirmDelete(Task task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('Are you sure you want to delete this task?'),
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
      await _taskService.deleteTask(task.id);
      await _loadTasks();
    } catch (_) {
      _showError('Could not delete the task. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Task> visibleTasks = _visibleTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$_remainingCount tasks remaining',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _FilterChip(
                    label: 'All',
                    selected: _filter == TaskFilter.all,
                    onSelected: () => setState(() => _filter = TaskFilter.all),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterChip(
                    label: 'Active',
                    selected: _filter == TaskFilter.active,
                    onSelected: () =>
                        setState(() => _filter = TaskFilter.active),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterChip(
                    label: 'Completed',
                    selected: _filter == TaskFilter.completed,
                    onSelected: () =>
                        setState(() => _filter = TaskFilter.completed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Task list
          Expanded(child: _buildTaskList(visibleTasks)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTask,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildTaskList(List<Task> visibleTasks) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final String? errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _TaskLoadError(message: errorMessage, onRetry: _retryLoad);
    }

    if (visibleTasks.isEmpty) {
      return EmptyTaskView(title: _emptyTitle, message: _emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: visibleTasks.length,
      itemBuilder: (context, index) {
        final Task task = visibleTasks[index];
        return TaskItem(
          task: task,
          onTap: () => _openEditTask(task),
          onToggle: () => _toggleTask(task),
          onDelete: () => _confirmDelete(task),
        );
      },
    );
  }
}

/// Shown when SQLite could not be read, with a button to try again.
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

/// Small reusable filter button used above the task list.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Align(alignment: Alignment.center, child: Text(label)),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}
