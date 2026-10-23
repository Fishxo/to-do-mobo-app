import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/empty_task_view.dart';
import '../widgets/task_item.dart';
import 'add_task_screen.dart';

/// Which subset of tasks is currently visible.
enum TaskFilter { all, active, completed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TaskService _taskService = TaskService.instance;

  List<Task> _tasks = const [];
  TaskFilter _filter = TaskFilter.all;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final List<Task> tasks = await _taskService.getTasks();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
    });
  }

  int get _remainingCount =>
      _tasks.where((task) => !task.isCompleted).length;

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

  Future<void> _openAddTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    );
    // Refresh the list in case a task was added.
    await _loadTasks();
  }

  Future<void> _openEditTask(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTaskScreen(task: task)),
    );
    // Refresh the list in case the task was edited.
    await _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    await _taskService.toggleTask(task.id);
    await _loadTasks();
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
    await _taskService.deleteTask(task.id);
    await _loadTasks();
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
                    onSelected: () =>
                        setState(() => _filter = TaskFilter.all),
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
          Expanded(
            child: visibleTasks.isEmpty
                ? const EmptyTaskView()
                : ListView.builder(
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
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTask,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
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
      label: Align(
        alignment: Alignment.center,
        child: Text(label),
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}
