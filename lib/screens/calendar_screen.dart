import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../state/app_controller.dart';
import '../utils/formatting.dart';
import '../widgets/empty_task_view.dart';
import '../widgets/task_item.dart';
import 'add_task_screen.dart';
import 'task_details_screen.dart';

enum CalendarView { year, month, week, day }

extension on CalendarView {
  String get label {
    switch (this) {
      case CalendarView.year:
        return 'Year';
      case CalendarView.month:
        return 'Month';
      case CalendarView.week:
        return 'Week';
      case CalendarView.day:
        return 'Day';
    }
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const List<String> _miniWeekdayLabels = [
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
  ];
  static const List<String> _weekdayLabels = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  CalendarView _view = CalendarView.month;
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

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _addDays(DateTime date, int days) {
    return DateTime(date.year, date.month, date.day + days);
  }

  DateTime _startOfWeek(DateTime date) {
    return _addDays(date, -(_dateOnly(date).weekday % 7));
  }

  DateTime _clampedDate(int year, int month, int day) {
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDay));
  }

  int _compareTasks(Task a, Task b) {
    final int byTime = a.dueDate!.compareTo(b.dueDate!);
    if (byTime != 0) return byTime;
    return b.priority.value.compareTo(a.priority.value);
  }

  List<Task> _tasksForDay(DateTime day) {
    final List<Task> tasks = _controller.tasks
        .where((task) => task.dueDate != null && isSameDay(task.dueDate!, day))
        .toList();
    tasks.sort(_compareTasks);
    return tasks;
  }

  String get _periodLabel {
    switch (_view) {
      case CalendarView.year:
        return '${_focusedDay.year}';
      case CalendarView.month:
        return DateFormat('MMMM yyyy').format(_focusedDay);
      case CalendarView.week:
        final DateTime start = _startOfWeek(_focusedDay);
        final DateTime end = _addDays(start, 6);
        if (start.year == end.year) {
          if (start.month == end.month) {
            return '${DateFormat('MMM d').format(start)} – '
                '${DateFormat('d, yyyy').format(end)}';
          }
          return '${DateFormat('MMM d').format(start)} – '
              '${DateFormat('MMM d, yyyy').format(end)}';
        }
        return '${DateFormat('MMM d, yyyy').format(start)} – '
            '${DateFormat('MMM d, yyyy').format(end)}';
      case CalendarView.day:
        return DateFormat('EEE, MMM d, yyyy').format(_selectedDay);
    }
  }

  void _changeView(CalendarView view) {
    if (view == _view) return;
    setState(() {
      _view = view;
      if (view == CalendarView.year) {
        _focusedDay = DateTime(_selectedDay.year, _selectedDay.month, 1);
      }
    });
  }

  void _move(int delta) {
    setState(() {
      switch (_view) {
        case CalendarView.year:
          final DateTime target = DateTime(
            _focusedDay.year + delta,
            _focusedDay.month,
            1,
          );
          _focusedDay = target;
          _selectedDay = _clampedDate(
            target.year,
            target.month,
            _selectedDay.day,
          );
          break;
        case CalendarView.month:
          final DateTime target = DateTime(
            _focusedDay.year,
            _focusedDay.month + delta,
            1,
          );
          _focusedDay = target;
          _selectedDay = _clampedDate(
            target.year,
            target.month,
            _selectedDay.day,
          );
          break;
        case CalendarView.week:
          _focusedDay = _addDays(_focusedDay, 7 * delta);
          _selectedDay = _addDays(_selectedDay, 7 * delta);
          break;
        case CalendarView.day:
          _focusedDay = _addDays(_focusedDay, delta);
          _selectedDay = _focusedDay;
          break;
      }
    });
  }

  void _goToToday() {
    final DateTime now = DateTime.now();
    setState(() {
      _focusedDay = DateTime(now.year, now.month, now.day);
      _selectedDay = _focusedDay;
    });
  }

  void _openMonth(DateTime month) {
    setState(() {
      _focusedDay = DateTime(month.year, month.month, 1);
      final bool sameMonth =
          _selectedDay.year == month.year && _selectedDay.month == month.month;
      _selectedDay = DateTime(
        month.year,
        month.month,
        sameMonth ? _selectedDay.day : 1,
      );
      _view = CalendarView.month;
    });
  }

  void _openDay(DateTime day) {
    setState(() {
      _focusedDay = _dateOnly(day);
      _selectedDay = _focusedDay;
      _view = CalendarView.day;
    });
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Calendar'),
            actions: [
              TextButton.icon(
                key: const Key('calendar-today'),
                onPressed: _goToToday,
                icon: const Icon(Icons.today_rounded, size: 18),
                label: const Text('Today'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      key: const Key('calendar-previous'),
                      tooltip: 'Previous',
                      onPressed: () => _move(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        _periodLabel,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const Key('calendar-next'),
                      tooltip: 'Next',
                      onPressed: () => _move(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: CalendarView.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final CalendarView view = CalendarView.values[index];
                    final bool selected = _view == view;
                    return ChoiceChip(
                      key: Key('calendar-view-${view.name}'),
                      label: Text(view.label),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                      onSelected: (_) => _changeView(view),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildView(theme)),
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

  Widget _buildView(ThemeData theme) {
    switch (_view) {
      case CalendarView.year:
        return _buildYearView(theme);
      case CalendarView.month:
        return _buildMonthView(theme);
      case CalendarView.week:
        return _buildWeekView(theme);
      case CalendarView.day:
        return _buildDayView(theme);
    }
  }

  Widget _buildYearView(ThemeData theme) {
    final int year = _focusedDay.year;
    final DateTime now = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 700
            ? 4
            : constraints.maxWidth >= 520
            ? 3
            : 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final DateTime month = DateTime(year, index + 1, 1);
              return _YearMonthCard(
                month: month,
                today: now,
                selectedDay: _selectedDay,
                weekdayLabels: _miniWeekdayLabels,
                tasksForDay: _tasksForDay,
                onTap: () => _openMonth(month),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMonthView(ThemeData theme) {
    final DateTime focusedMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      1,
    );
    final int startOffset = focusedMonth.weekday % 7;
    final DateTime firstCell = _addDays(focusedMonth, -startOffset);
    final DateTime now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            children: [
              Row(
                children: [
                  for (final String label in _weekdayLabels)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 42,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final DateTime day = _addDays(firstCell, index);
                  return _MonthDayCell(
                    day: day,
                    isCurrentMonth: day.month == focusedMonth.month,
                    isToday: isSameDay(day, now),
                    isSelected: isSameDay(day, _selectedDay),
                    tasks: _tasksForDay(day),
                    onTap: () => _openDay(day),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekView(ThemeData theme) {
    final DateTime start = _startOfWeek(_focusedDay);
    final DateTime now = DateTime.now();
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (index) => _addDays(start, index),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      children: [
        for (final DateTime day in days)
          _WeekDaySection(
            day: day,
            tasks: _tasksForDay(day),
            isToday: isSameDay(day, now),
            isSelected: isSameDay(day, _selectedDay),
            categoryFor: _controller.categoryById,
            onOpenDay: () => _openDay(day),
            onOpenTask: _openTask,
            onEditTask: _editTask,
            onToggleTask: _toggleTask,
            onDeleteTask: _confirmDelete,
          ),
      ],
    );
  }

  Widget _buildDayView(ThemeData theme) {
    final List<Task> tasks = _tasksForDay(_selectedDay);

    if (tasks.isEmpty) {
      return EmptyTaskView(
        title: 'No tasks this day',
        message: 'Tap Add to schedule something for this date.',
        icon: Icons.event_available_outlined,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatFullDate(_selectedDay),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        for (final Task task in tasks)
          _TimedTaskItem(
            task: task,
            category: _controller.categoryById(task.categoryId),
            onTap: () => _openTask(task),
            onEdit: () => _editTask(task),
            onToggle: () => _toggleTask(task),
            onDelete: () => _confirmDelete(task),
          ),
      ],
    );
  }
}

class _YearMonthCard extends StatelessWidget {
  const _YearMonthCard({
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.weekdayLabels,
    required this.tasksForDay,
    required this.onTap,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selectedDay;
  final List<String> weekdayLabels;
  final List<Task> Function(DateTime day) tasksForDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final DateTime first = DateTime(month.year, month.month, 1);
    final int startOffset = first.weekday % 7;
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final bool isSelectedMonth =
        selectedDay.year == month.year && selectedDay.month == month.month;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMMM').format(month),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isSelectedMonth
                            ? colors.primary
                            : colors.onSurface,
                      ),
                    ),
                  ),
                  if (isSelectedMonth)
                    Icon(Icons.circle, size: 6, color: colors.primary),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final String label in weekdayLabels)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Column(
                  children: [
                    for (int row = 0; row < 6; row++)
                      Expanded(
                        child: Row(
                          children: [
                            for (int column = 0; column < 7; column++)
                              Expanded(
                                child: _buildMiniDay(
                                  context,
                                  row * 7 + column,
                                  startOffset,
                                  daysInMonth,
                                ),
                              ),
                          ],
                        ),
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

  Widget _buildMiniDay(
    BuildContext context,
    int index,
    int startOffset,
    int daysInMonth,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int dayNumber = index - startOffset + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox.shrink();
    }

    final DateTime day = DateTime(month.year, month.month, dayNumber);
    final bool isToday = isSameDay(day, today);
    final bool hasTasks = tasksForDay(day).isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: isToday
          ? BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: 9.5,
              height: 1,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? colors.primary : colors.onSurface,
            ),
          ),
          if (hasTasks) ...[
            const SizedBox(height: 1),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.tasks,
    required this.onTap,
  });

  final DateTime day;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final List<Task> tasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final Color numberColor;
    if (isSelected) {
      numberColor = colors.onPrimary;
    } else if (isToday) {
      numberColor = colors.primary;
    } else if (!isCurrentMonth) {
      numberColor = colors.onSurfaceVariant.withValues(alpha: 0.45);
    } else {
      numberColor = colors.onSurface;
    }

    final Color background = isSelected
        ? colors.primary
        : isToday
        ? colors.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return InkWell(
      key: Key('calendar-day-${day.year}-${day.month}-${day.day}'),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                height: 1,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: numberColor,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final Task task in tasks.take(3))
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.onPrimary
                            : priorityColor(
                                task.priority,
                                colors,
                              ).withValues(alpha: isCurrentMonth ? 1 : 0.45),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (tasks.length > 3)
                    Text(
                      '+',
                      style: TextStyle(
                        fontSize: 8,
                        height: 1,
                        color: isSelected
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDaySection extends StatelessWidget {
  const _WeekDaySection({
    required this.day,
    required this.tasks,
    required this.isToday,
    required this.isSelected,
    required this.categoryFor,
    required this.onOpenDay,
    required this.onOpenTask,
    required this.onEditTask,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  final DateTime day;
  final List<Task> tasks;
  final bool isToday;
  final bool isSelected;
  final Category? Function(int? id) categoryFor;
  final VoidCallback onOpenDay;
  final Future<void> Function(Task task) onOpenTask;
  final Future<void> Function(Task task) onEditTask;
  final Future<void> Function(Task task) onToggleTask;
  final Future<void> Function(Task task) onDeleteTask;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: Key('calendar-week-day-${day.year}-${day.month}-${day.day}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onOpenDay,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isToday
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(day).toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: isToday
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isToday ? colors.onPrimary : colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isToday ? 'Today' : DateFormat('EEEE').format(day),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isSelected ? colors.primary : colors.onSurface,
                        ),
                      ),
                      Text(
                        DateFormat('MMMM d, yyyy').format(day),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 58, bottom: 8),
            child: Text('No tasks scheduled', style: theme.textTheme.bodySmall),
          )
        else
          for (final Task task in tasks)
            _TimedTaskItem(
              task: task,
              category: categoryFor(task.categoryId),
              onTap: () => onOpenTask(task),
              onEdit: () => onEditTask(task),
              onToggle: () => onToggleTask(task),
              onDelete: () => onDeleteTask(task),
            ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _TimedTaskItem extends StatelessWidget {
  const _TimedTaskItem({
    required this.task,
    required this.category,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final Task task;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              task.dueDate == null ? '' : formatTime(task.dueDate!),
              style: theme.textTheme.labelSmall,
            ),
          ),
        ),
        Expanded(
          child: TaskItem(
            task: task,
            category: category,
            onTap: onTap,
            onEdit: onEdit,
            onToggle: onToggle,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}
