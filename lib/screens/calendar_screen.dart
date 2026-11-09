import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../state/app_controller.dart';
import '../utils/formatting.dart';
import '../utils/category_style.dart';
import '../utils/theme_colors.dart';
import '../widgets/empty_task_view.dart';
import 'add_task_screen.dart';
import 'occurrence_editor_sheet.dart';
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
    return _addDays(date, -(_dateOnly(date).weekday - DateTime.monday));
  }

  DateTime _clampedDate(int year, int month, int day) {
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDay));
  }

  List<TaskOccurrence> _occurrencesForDay(DateTime day) {
    final DateTime dayStart = _dateOnly(day);
    final DateTime dayEnd = _addDays(dayStart, 1)
        .subtract(const Duration(microseconds: 1));
    final List<TaskOccurrence> items = [];
    for (final Task task in _controller.tasks) {
      items.addAll(
        _controller.occurrencesForTask(task, from: dayStart, until: dayEnd),
      );
    }
    items.sort((a, b) {
      final int byTime = a.occurrenceAt.compareTo(b.occurrenceAt);
      if (byTime != 0) return byTime;
      return b.task.priority.value.compareTo(a.task.priority.value);
    });
    return items;
  }

  List<Task> _tasksForDay(DateTime day) {
    return _occurrencesForDay(day)
        .map((item) => item.task.copyWith(
              dueDate: item.occurrenceAt,
              isCompleted: item.isCompleted,
              completedAt: item.isCompleted ? DateTime.now() : null,
            ))
        .toList(growable: false);
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
    await _openAddTaskAt(
      DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 9),
    );
  }

  Future<void> _openAddTaskAt(DateTime dueDate) async {
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

  Future<void> _editSeries(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(task: task, controller: _controller),
      ),
    );
  }

  Future<void> _toggleOccurrence(TaskOccurrence occurrence) async {
    try {
      if (occurrence.isRecurring) {
        await _controller.setOccurrenceCompleted(
          occurrence.task.id,
          occurrence.occurrenceAt,
          !occurrence.isCompleted,
        );
      } else {
        await _controller.toggleTask(occurrence.task.id);
      }
    } catch (_) {
      _showError('Could not update the task. Please try again.');
    }
  }

  Future<void> _editOccurrence(TaskOccurrence occurrence) async {
    if (!occurrence.isRecurring) {
      await _editSeries(occurrence.task);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => OccurrenceEditorSheet(
        controller: _controller,
        occurrence: occurrence,
      ),
    );
  }

  Future<void> _confirmDeleteOccurrence(TaskOccurrence occurrence) async {
    if (!occurrence.isRecurring) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete task?'),
          content: Text('Delete "${occurrence.task.title}"? This cannot be undone.'),
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
        await _controller.deleteTask(occurrence.task.id);
      } catch (_) {
        _showError('Could not delete the task. Please try again.');
      }
      return;
    }

    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_busy_rounded),
              title: const Text('Delete this occurrence'),
              subtitle: const Text('Only this date is removed from the series.'),
              onTap: () => Navigator.pop(sheetContext, 'occurrence'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(sheetContext).colorScheme.error),
              title: Text(
                'Delete entire series',
                style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
              ),
              subtitle: const Text('All repeats and saved occurrence status are removed.'),
              onTap: () => Navigator.pop(sheetContext, 'series'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'occurrence') {
        await _controller.deleteOccurrence(
          occurrence.task.id,
          occurrence.occurrenceAt,
        );
      } else {
        await _controller.deleteTask(occurrence.task.id);
      }
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
    return _WeekTimeline(
      days: List<DateTime>.generate(
        7,
        (index) => _addDays(_startOfWeek(_focusedDay), index),
      ),
      selectedDay: _selectedDay,
      tasksForDay: _tasksForDay,
      categoryFor: _controller.categoryById,
      onSelectDay: (day) {
        setState(() {
          _selectedDay = day;
          _focusedDay = day;
        });
      },
      onOpenTask: _openTask,
      onCreateTask: _openAddTaskAt,
      onWeekChanged: (delta) => _move(delta),
    );
  }

  Widget _buildDayView(ThemeData theme) {
    final List<TaskOccurrence> items = _occurrencesForDay(_selectedDay);

    if (items.isEmpty) {
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
                '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        for (final TaskOccurrence occurrence in items)
          _OccurrenceCard(
            occurrence: occurrence,
            category: _controller.categoryById(occurrence.task.categoryId),
            onTap: () => _openTask(occurrence.task),
            onEdit: () => _editOccurrence(occurrence),
            onToggle: () => _toggleOccurrence(occurrence),
            onDelete: () => _confirmDeleteOccurrence(occurrence),
          ),
      ],
    );
  }
}

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.days,
    required this.selectedDay,
    required this.tasksForDay,
    required this.categoryFor,
    required this.onSelectDay,
    required this.onOpenTask,
    required this.onCreateTask,
    required this.onWeekChanged,
  });

  static const double _hourHeight = 68;
  static const double _timeGutterWidth = 58;
  final List<DateTime> days;
  final DateTime selectedDay;
  final List<Task> Function(DateTime day) tasksForDay;
  final Category? Function(int? id) categoryFor;
  final ValueChanged<DateTime> onSelectDay;
  final Future<void> Function(Task task) onOpenTask;
  final Future<void> Function(DateTime date) onCreateTask;
  final ValueChanged<int> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final DateTime now = DateTime.now();
    final double minDayWidth = 48;
    final double timelineWidth = _timeGutterWidth + (minDayWidth * 7);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double dayWidth = constraints.maxWidth >= timelineWidth
            ? (constraints.maxWidth - _timeGutterWidth) / 7
            : minDayWidth;
        final double gridWidth = _timeGutterWidth + (dayWidth * 7);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -280) onWeekChanged(1);
            if (details.primaryVelocity! > 280) onWeekChanged(-1);
          },
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(
                    bottom: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: gridWidth,
                    height: 76,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: _timeGutterWidth),
                        for (int index = 0; index < days.length; index++)
                          _WeekDayHeader(
                            day: days[index],
                            width: dayWidth,
                            isToday: isSameDay(days[index], now),
                            isSelected: isSameDay(days[index], selectedDay),
                            onTap: () => onSelectDay(days[index]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: gridWidth,
                      height: _hourHeight * 24,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: _timeGutterWidth,
                            child: _TimeGutter(
                              hourHeight: _hourHeight,
                              colors: colors,
                            ),
                          ),
                          for (
                            int dayIndex = 0;
                            dayIndex < days.length;
                            dayIndex++
                          )
                            Positioned(
                              left: _timeGutterWidth + dayIndex * dayWidth,
                              top: 0,
                              width: dayWidth,
                              height: _hourHeight * 24,
                              child: _DayTimelineColumn(
                                day: days[dayIndex],
                                dayWidth: dayWidth,
                                hourHeight: _hourHeight,
                                isSelected: isSameDay(
                                  days[dayIndex],
                                  selectedDay,
                                ),
                                isToday: isSameDay(days[dayIndex], now),
                                tasks: tasksForDay(days[dayIndex]),
                                categoryFor: categoryFor,
                                onOpenTask: onOpenTask,
                                onCreateTask: onCreateTask,
                                now: now,
                              ),
                            ),
                          if (days.any((day) => isSameDay(day, now)))
                            Positioned(
                              left:
                                  _timeGutterWidth +
                                  days.indexWhere(
                                        (day) => isSameDay(day, now),
                                      ) *
                                      dayWidth,
                              top: ((now.hour + now.minute / 60) * _hourHeight),
                              width: dayWidth,
                              height: 1,
                              child: Container(
                                color: colors.error,
                                height: 1.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekDayHeader extends StatelessWidget {
  const _WeekDayHeader({
    required this.day,
    required this.width,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });
  final DateTime day;
  final double width;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      width: width,
      child: InkWell(
        key: Key('calendar-week-day-${day.year}-${day.month}-${day.day}'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE').format(day).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primaryContainer
                    : isToday
                    ? colors.surfaceContainerHighest
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? colors.primary
                      : isToday
                      ? colors.primary
                      : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeGutter extends StatelessWidget {
  const _TimeGutter({required this.hourHeight, required this.colors});
  final double hourHeight;
  final ColorScheme colors;

  String _hourLabel(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    return '${hour > 12 ? hour - 12 : hour} ${hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int hour = 0; hour < 24; hour++)
          Positioned(
            left: 0,
            right: 0,
            top: hour * hourHeight,
            height: hourHeight,
            child: Transform.translate(
              offset: const Offset(0, -7),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _hourLabel(hour),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant, fontSize: 10),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayTimelineColumn extends StatelessWidget {
  const _DayTimelineColumn({
    required this.day,
    required this.dayWidth,
    required this.hourHeight,
    required this.isSelected,
    required this.isToday,
    required this.tasks,
    required this.categoryFor,
    required this.onOpenTask,
    required this.onCreateTask,
    required this.now,
  });
  final DateTime day;
  final double dayWidth;
  final double hourHeight;
  final bool isSelected;
  final bool isToday;
  final List<Task> tasks;
  final Category? Function(int? id) categoryFor;
  final Future<void> Function(Task task) onOpenTask;
  final Future<void> Function(DateTime date) onCreateTask;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? colors.primary.withValues(alpha: 0.025) : null,
        border: Border(
          right: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Stack(
        children: [
          for (int hour = 0; hour < 24; hour++)
            Positioned(
              left: 0,
              right: 0,
              top: hour * hourHeight,
              height: hourHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () =>
                    onCreateTask(DateTime(day.year, day.month, day.day, hour)),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          for (final task in tasks)
            if (task.dueDate != null)
              _TaskCalendarBlock(
                task: task,
                category: categoryFor(task.categoryId),
                hourHeight: hourHeight,
                onTap: () => onOpenTask(task),
              ),
        ],
      ),
    );
  }
}

class _TaskCalendarBlock extends StatelessWidget {
  const _TaskCalendarBlock({
    required this.task,
    required this.category,
    required this.hourHeight,
    required this.onTap,
  });
  final Task task;
  final Category? category;
  final double hourHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseColor = category == null
        ? Theme.of(context).colorScheme.primary
        : colorFromValue(category!.colorValue);
    final start = task.dueDate!;
    final top = (start.hour + start.minute / 60) * hourHeight + 3;
    final height = (hourHeight - 6).clamp(30.0, hourHeight - 6);
    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: Material(
        color: baseColor.withValues(alpha: task.isCompleted ? 0.38 : 0.82),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  task.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.occurrence,
    required this.category,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final TaskOccurrence occurrence;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Task task = occurrence.task;
    final Color statusColor = occurrence.isCompleted
        ? successColor(colors)
        : occurrence.isOverdue
        ? colors.error
        : colors.primary;
    final String status = occurrence.isCompleted
        ? 'Completed'
        : occurrence.isOverdue
        ? 'Overdue'
        : 'Pending';
    final String time = task.isAllDay
        ? 'All day'
        : occurrence.endAt == null
        ? formatTime(occurrence.occurrenceAt)
        : '${formatTime(occurrence.occurrenceAt)} – ${formatTime(occurrence.endAt!)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: statusColor),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Checkbox(
                  key: Key(
                    'occurrence-check-${task.id}-${occurrence.occurrenceAt.toUtc().toIso8601String()}',
                  ),
                  value: occurrence.isCompleted,
                  onChanged: (_) => onToggle(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: occurrence.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: occurrence.isCompleted
                              ? colors.onSurfaceVariant
                              : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MiniChip(
                            icon: Icons.schedule_rounded,
                            label: time,
                            color: colors.onSurfaceVariant,
                          ),
                          _MiniChip(
                            icon: occurrence.isCompleted
                                ? Icons.check_circle_rounded
                                : occurrence.isOverdue
                                ? Icons.error_outline_rounded
                                : Icons.radio_button_unchecked_rounded,
                            label: status,
                            color: statusColor,
                            emphasized: true,
                          ),
                          if (task.isRecurring)
                            _MiniChip(
                              icon: Icons.repeat_rounded,
                              label: 'Recurring',
                              color: colors.secondary,
                            ),
                          if (category != null)
                            _MiniChip(
                              icon: iconFromCodePoint(category!.iconCodePoint),
                              label: category!.name,
                              color: colorFromValue(category!.colorValue),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Occurrence actions',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(task.isRecurring ? 'Edit this occurrence' : 'Edit task'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(task.isRecurring ? 'Delete occurrence' : 'Delete task'),
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasized ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
