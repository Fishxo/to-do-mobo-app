import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../models/task.dart';
import '../state/app_controller.dart';
import '../utils/formatting.dart';
import '../widgets/empty_task_view.dart';
import '../widgets/task_item.dart';
import 'add_task_screen.dart';
import 'task_details_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  AppController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
  }

  List<Task> _tasksForDay(DateTime day) {
    return _controller.tasks
        .where((task) => task.dueDate != null && isSameDay(task.dueDate!, day))
        .toList(growable: false);
  }

  StartingDayOfWeek get _startingDay {
    final int index = (_controller.settings.startOfWeek - 1).clamp(0, 6);
    return StartingDayOfWeek.values[index];
  }

  Future<void> _openAddTask() async {
    final DateTime dueDate = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      9,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddTaskScreen(controller: _controller, initialDueDate: dueDate),
      ),
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final List<Task> selectedTasks = _tasksForDay(_selectedDay);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Calendar'),
            actions: [
              IconButton(
                tooltip: 'Go to today',
                onPressed: () {
                  final DateTime now = DateTime.now();
                  setState(() {
                    _focusedDay = DateTime(now.year, now.month, now.day);
                    _selectedDay = _focusedDay;
                  });
                },
                icon: const Icon(Icons.today_rounded),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: TableCalendar<Task>(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2035, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                      },
                      startingDayOfWeek: _startingDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, _selectedDay),
                      eventLoader: _tasksForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle:
                            theme.textTheme.titleMedium ??
                            const TextStyle(fontSize: 16),
                        leftChevronIcon: const Icon(Icons.chevron_left_rounded),
                        rightChevronIcon: const Icon(
                          Icons.chevron_right_rounded,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: theme.textTheme.labelSmall!,
                        weekendStyle: theme.textTheme.labelSmall!,
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        cellMargin: const EdgeInsets.all(4),
                        todayDecoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.18,
                          ),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        markerDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 3,
                        markerSize: 5,
                        markerMargin: const EdgeInsets.symmetric(
                          horizontal: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSameDay(_selectedDay, DateTime.now())
                                ? 'Today'
                                : formatFullDate(_selectedDay),
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '${selectedTasks.length} '
                            '${selectedTasks.length == 1 ? 'task' : 'tasks'} scheduled',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _openAddTask,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: selectedTasks.isEmpty
                    ? EmptyTaskView(
                        title: 'No tasks this day',
                        message: 'Tap Add to schedule something for this date.',
                        icon: Icons.event_available_outlined,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: selectedTasks.length,
                        itemBuilder: (context, index) {
                          final Task task = selectedTasks[index];
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
          floatingActionButton: FloatingActionButton(
            onPressed: _openAddTask,
            tooltip: 'Add task for this day',
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
    );
  }
}
