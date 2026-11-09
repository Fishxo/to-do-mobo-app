import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/recurrence.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../state/app_controller.dart';
import '../utils/category_style.dart';
import '../utils/formatting.dart';
import '../widgets/recurring_completion_dialog.dart';

/// Screen used to both add a new task and edit an existing one.
/// Pass a [task] to edit it, leave it empty to create a new task.
class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({
    super.key,
    this.task,
    this.controller,
    this.initialDueDate,
    this.initialCategoryId,
  });

  final Task? task;
  final AppController? controller;
  final DateTime? initialDueDate;
  final int? initialCategoryId;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _recurrenceIntervalController;
  late final TextEditingController _recurrenceCountController;
  late final AppController _controller;
  final List<TextEditingController> _newSubtaskControllers = [];

  int? _categoryId;
  late TaskPriority _priority;
  DateTime? _dueDate;
  DateTime? _endAt;
  DateTime? _reminderAt;
  bool _isCompleted = false;
  bool _isAllDay = false;
  RecurrencePattern _recurrence = RecurrencePattern.never;
  int _recurrenceInterval = 1;
  RecurrenceUnit _recurrenceUnit = RecurrenceUnit.week;
  Set<int> _recurrenceWeekdays = <int>{};
  _RepeatEndType _repeatEndType = _RepeatEndType.never;
  DateTime? _repeatEndDate;
  bool _isSaving = false;
  String? _errorMessage;
  bool _hasLoadedDefaults = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AppController();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _categoryId = widget.task?.categoryId ?? widget.initialCategoryId;
    _dueDate = widget.task?.dueDate ?? widget.initialDueDate;
    _endAt = widget.task?.endAt;
    _reminderAt = widget.task?.reminderAt;
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _isAllDay = widget.task?.isAllDay ?? false;
    _recurrence = widget.task?.recurrence ?? RecurrencePattern.never;
    _recurrenceInterval = widget.task?.recurrenceInterval ?? 1;
    _recurrenceUnit = widget.task?.recurrenceUnit ?? RecurrenceUnit.week;
    _recurrenceWeekdays =
        (widget.task?.recurrenceWeekdays ?? const <int>[]).toSet();
    _repeatEndDate = widget.task?.recurrenceEndDate;
    if (widget.task?.recurrenceCount != null) {
      _repeatEndType = _RepeatEndType.afterCount;
    } else if (_repeatEndDate != null) {
      _repeatEndType = _RepeatEndType.onDate;
    }
    _recurrenceIntervalController = TextEditingController(
      text: '$_recurrenceInterval',
    );
    _recurrenceCountController = TextEditingController(
      text: '${widget.task?.recurrenceCount ?? 10}',
    );

    if (!_isAllDay && _dueDate != null && _endAt == null) {
      _endAt = _dueDate!.add(const Duration(hours: 1));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedDefaults) return;
    _hasLoadedDefaults = true;
    if (!_isEditing) {
      _priority = _controller.settings.defaultPriority;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _recurrenceIntervalController.dispose();
    _recurrenceCountController.dispose();
    for (final controller in _newSubtaskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  DateTime _defaultEndAfter(DateTime start) {
    return start.add(const Duration(hours: 1));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDueDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _dueDate ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'Select date',
    );
    if (picked == null || !mounted) return;

    if (_isAllDay) {
      setState(() {
        _dueDate = _dateOnly(picked);
        _endAt = null;
      });
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? picked),
      helpText: 'Start time',
    );
    if (time == null || !mounted) return;

    setState(() {
      final DateTime start = _combineDateAndTime(picked, time);
      _dueDate = start;
      final DateTime? existingEnd = _endAt;
      if (existingEnd == null ||
          !_sameDay(existingEnd, start) ||
          !existingEnd.isAfter(start)) {
        _endAt = _defaultEndAfter(start);
      }
    });
  }

  Future<void> _pickStartTime() async {
    final DateTime day = _dueDate ?? DateTime.now();
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? day),
      helpText: 'Start time',
    );
    if (time == null || !mounted) return;

    setState(() {
      final DateTime start = _combineDateAndTime(day, time);
      _dueDate = start;
      DateTime end = _endAt ?? _defaultEndAfter(start);
      end = _combineDateAndTime(
        _sameDay(end, start) ? start : _dateOnly(start),
        TimeOfDay.fromDateTime(end),
      );
      if (!end.isAfter(start)) end = _defaultEndAfter(start);
      _endAt = end;
    });
  }

  Future<void> _pickEndTime() async {
    final DateTime day = _dueDate ?? DateTime.now();
    final DateTime initial = _endAt ?? _defaultEndAfter(day);
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'End time',
    );
    if (time == null || !mounted) return;

    setState(() => _endAt = _combineDateAndTime(day, time));
  }

  Future<void> _pickRepeatEndDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _repeatEndDate ?? _dueDate ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Repeat end date',
    );
    if (picked == null || !mounted) return;
    setState(() => _repeatEndDate = _dateOnly(picked));
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _setAllDay(bool value) {
    setState(() {
      _isAllDay = value;
      if (value) {
        if (_dueDate != null) _dueDate = _dateOnly(_dueDate!);
        _endAt = null;
      } else if (_dueDate != null) {
        _endAt = _endAt != null && _endAt!.isAfter(_dueDate!)
            ? _endAt
            : _defaultEndAfter(_dueDate!);
      }
    });
  }

  void _setRecurrence(RecurrencePattern? pattern) {
    if (pattern == null) return;
    setState(() {
      _recurrence = pattern;
      if (pattern == RecurrencePattern.custom &&
          _recurrenceWeekdays.isEmpty) {
        final DateTime anchor = _dueDate ?? DateTime.now();
        _recurrenceWeekdays = <int>{anchor.weekday};
      }
    });
  }

  Future<void> _pickReminder() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _reminderAt ?? now.add(const Duration(hours: 1));

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'Reminder date',
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Reminder time',
    );
    if (time == null || !mounted) return;

    final DateTime reminder = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!reminder.isAfter(DateTime.now())) {
      _showMessage('Please choose a reminder time in the future.');
      return;
    }

    setState(() => _reminderAt = reminder);

    if (!_controller.settings.notificationsEnabled) {
      _showMessage(
        'Reminder saved, but notifications are turned off in Settings.',
      );
      return;
    }

    final bool granted = await _controller.ensureNotificationPermission();
    if (!granted && mounted) {
      _showMessage(
        'Notification permission was denied. Enable it in Settings to receive '
        'this reminder.',
      );
    }
  }

  void _addSubtaskField() {
    setState(() {
      _newSubtaskControllers.add(TextEditingController());
    });
  }

  void _removeSubtaskField(int index) {
    setState(() {
      _newSubtaskControllers.removeAt(index).dispose();
    });
  }

  Future<void> _toggleExistingSubtask(Subtask subtask) async {
    try {
      await _controller.toggleSubtask(subtask);
      if (mounted) setState(() {});
    } catch (_) {
      _showMessage('Could not update the subtask.');
    }
  }

  Future<void> _deleteExistingSubtask(Subtask subtask) async {
    try {
      await _controller.deleteSubtask(subtask.id);
      if (mounted) setState(() {});
    } catch (_) {
      _showMessage('Could not delete the subtask.');
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_reminderAt != null && !_reminderAt!.isAfter(DateTime.now())) {
      setState(() {
        _errorMessage = 'The reminder time must be in the future.';
      });
      return;
    }

    if (!_isAllDay &&
        _dueDate != null &&
        _endAt != null &&
        !_endAt!.isAfter(_dueDate!)) {
      setState(() {
        _errorMessage = 'The end time must be after the start time.';
      });
      return;
    }

    if (_recurrence != RecurrencePattern.never && _dueDate == null) {
      setState(() {
        _errorMessage = 'Choose a date before setting a repeat.';
      });
      return;
    }

    final int repeatInterval =
        int.tryParse(_recurrenceIntervalController.text.trim()) ?? 0;
    final int? repeatCount = int.tryParse(
      _recurrenceCountController.text.trim(),
    );

    if (_recurrence == RecurrencePattern.custom) {
      if (repeatInterval < 1) {
        setState(() {
          _errorMessage = 'The repeat interval must be at least 1.';
        });
        return;
      }
      if (_repeatEndType == _RepeatEndType.onDate && _repeatEndDate == null) {
        setState(() {
          _errorMessage = 'Choose an end date for the repeat.';
        });
        return;
      }
      if (_repeatEndType == _RepeatEndType.afterCount &&
          (repeatCount == null || repeatCount < 1)) {
        setState(() {
          _errorMessage = 'The number of repetitions must be at least 1.';
        });
        return;
      }
      if (_repeatEndDate != null &&
          _dueDate != null &&
          _repeatEndDate!.isBefore(_dateOnly(_dueDate!))) {
        setState(() {
          _errorMessage = 'The repeat end date cannot be before the start.';
        });
        return;
      }
    }

    FocusScope.of(context).unfocus();
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    final List<String> newSubtasks = _newSubtaskControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final DateTime? endAt = !_isAllDay && _dueDate != null ? _endAt : null;
    final bool isCustom = _recurrence == RecurrencePattern.custom;
    final List<int> weekdays = isCustom
        ? (_recurrenceWeekdays.toList()..sort())
        : const <int>[];
    final DateTime? repeatEndDate =
        isCustom && _repeatEndType == _RepeatEndType.onDate
        ? _repeatEndDate
        : null;
    final int? repeatLimit = isCustom && _repeatEndType == _RepeatEndType.afterCount
        ? repeatCount
        : null;
    final int interval = isCustom ? repeatInterval : 1;
    final RecurrenceUnit unit = isCustom
        ? _recurrenceUnit
        : RecurrenceUnit.day;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        final Task current =
            _controller.taskById(widget.task!.id) ?? widget.task!;
        final bool completionChanged = current.isCompleted != _isCompleted;
        await _controller.updateTask(
          current.copyWith(
            title: title,
            description: description,
            categoryId: _categoryId,
            priority: _priority,
            dueDate: _dueDate,
            endAt: endAt,
            reminderAt: _reminderAt,
            isAllDay: _isAllDay,
            recurrence: _recurrence,
            recurrenceInterval: interval,
            recurrenceUnit: unit,
            recurrenceWeekdays: weekdays,
            recurrenceEndDate: repeatEndDate,
            recurrenceCount: repeatLimit,
          ),
        );
        for (final String subtask in newSubtasks) {
          await _controller.addSubtask(current.id, subtask);
        }
        if (completionChanged) {
          if (current.isRecurring && _dueDate != null) {
            if (!mounted) return;
            final RecurrenceCompletionScope? scope =
                await showRecurringCompletionDialog(
              context,
              completing: _isCompleted,
              occurrenceAt: _dueDate!,
            );
            if (!mounted) return;
            if (scope == null) {
              if (!mounted) return;
              setState(() {
                _isSaving = false;
                _errorMessage =
                    'Changes were saved, but completion status was not applied.';
              });
              return;
            }
            await _controller.applyTaskCompletion(
              taskId: current.id,
              isCompleted: _isCompleted,
              occurrenceAt: _dueDate!,
              scope: scope,
            );
          } else {
            await _controller.applyTaskCompletion(
              taskId: current.id,
              isCompleted: _isCompleted,
            );
          }
        }
      } else {
        final Task created = await _controller.addTask(
          title: title,
          description: description,
          categoryId: _categoryId,
          priority: _priority,
          dueDate: _dueDate,
          endAt: endAt,
          reminderAt: _reminderAt,
          isAllDay: _isAllDay,
          recurrence: _recurrence,
          recurrenceInterval: interval,
          recurrenceUnit: unit,
          recurrenceWeekdays: weekdays,
          recurrenceEndDate: repeatEndDate,
          recurrenceCount: repeatLimit,
          subtaskTitles: newSubtasks,
        );
        if (_isCompleted) {
          await _controller.applyTaskCompletion(
            taskId: created.id,
            isCompleted: true,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Could not save the task. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Task? currentTask = _isEditing
        ? _controller.taskById(widget.task!.id)
        : null;
    final String? errorMessage = _errorMessage;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'New Task'),
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double horizontal = constraints.maxWidth > 720 ? 28 : 16;
                    return ListView(
                      padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 20),
                      children: [
                        _FormSection(
                          icon: Icons.edit_note_rounded,
                          title: 'Event details',
                          subtitle: 'Give your event a clear name and context.',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _titleController,
                                autofocus: !_isEditing,
                                enabled: !_isSaving,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Task title',
                                  hintText: 'What do you need to do?',
                                  prefixIcon: Icon(Icons.check_circle_outline_rounded),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Title cannot be empty';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _descriptionController,
                                minLines: 3,
                                maxLines: 6,
                                enabled: !_isSaving,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'Add more details (optional)',
                                  alignLabelWithHint: true,
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(bottom: 42),
                                    child: Icon(Icons.notes_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FormSection(
                          icon: Icons.tune_rounded,
                          title: 'Planning',
                          subtitle: 'Priority and category help keep your calendar organized.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Priority', style: theme.textTheme.labelLarge),
                              const SizedBox(height: 10),
                              SegmentedButton<TaskPriority>(
                                segments: TaskPriority.values
                                    .map(
                                      (priority) => ButtonSegment<TaskPriority>(
                                        value: priority,
                                        label: Text(priority.label),
                                        icon: Icon(priorityIcon(priority), size: 16),
                                      ),
                                    )
                                    .toList(),
                                selected: {_priority},
                                showSelectedIcon: false,
                                onSelectionChanged: _isSaving
                                    ? null
                                    : (selection) {
                                        setState(() => _priority = selection.first);
                                      },
                              ),
                              const SizedBox(height: 18),
                              Text('Category', style: theme.textTheme.labelLarge),
                              const SizedBox(height: 10),
                              _CategoryPicker(
                                categories: _controller.categories,
                                selectedId: _categoryId,
                                onSelected: (id) {
                                  if (!_isSaving) setState(() => _categoryId = id);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FormSection(
                          icon: Icons.calendar_month_rounded,
                          title: 'Schedule',
                          subtitle: _isAllDay
                              ? 'All-day events keep the date without start and end times.'
                              : 'Set the date and time window for this event.',
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            color: colors.surfaceContainerLowest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
                            ),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  key: const Key('task-all-day'),
                                  value: _isAllDay,
                                  onChanged: _isSaving ? null : _setAllDay,
                                  secondary: Icon(
                                    Icons.wb_sunny_outlined,
                                    color: _isAllDay ? colors.primary : null,
                                  ),
                                  title: const Text('All Day'),
                                  subtitle: Text(
                                    _isAllDay
                                        ? 'The event lasts the whole day'
                                        : 'Set a start and end time',
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  key: const Key('task-date'),
                                  leading: const Icon(Icons.event_outlined),
                                  title: const Text('Date'),
                                  subtitle: Text(
                                    _dueDate == null
                                        ? 'No date'
                                        : formatShortDate(_dueDate!),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_dueDate != null)
                                        IconButton(
                                          tooltip: 'Clear date',
                                          onPressed: _isSaving
                                              ? null
                                              : () => setState(() {
                                                    _dueDate = null;
                                                    _endAt = null;
                                                  }),
                                          icon: const Icon(Icons.close_rounded, size: 18),
                                        ),
                                      const Icon(Icons.chevron_right_rounded),
                                    ],
                                  ),
                                  onTap: _isSaving ? null : _pickDueDate,
                                ),
                                if (!_isAllDay) ...[
                                  const Divider(height: 1),
                                  ListTile(
                                    key: const Key('task-start-time'),
                                    leading: const Icon(Icons.schedule_rounded),
                                    title: const Text('Start time'),
                                    subtitle: Text(
                                      _dueDate == null
                                          ? 'Choose a date first'
                                          : formatTime(_dueDate!),
                                    ),
                                    trailing: const Icon(Icons.chevron_right_rounded),
                                    onTap: _isSaving ? null : _pickStartTime,
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    key: const Key('task-end-time'),
                                    leading: const Icon(Icons.schedule_send_rounded),
                                    title: const Text('End time'),
                                    subtitle: Text(
                                      _endAt == null ? 'Not set' : formatTime(_endAt!),
                                    ),
                                    trailing: const Icon(Icons.chevron_right_rounded),
                                    onTap: _isSaving ? null : _pickEndTime,
                                  ),
                                ],
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.notifications_none_rounded),
                                  title: const Text('Reminder'),
                                  subtitle: Text(
                                    _reminderAt == null
                                        ? 'No reminder'
                                        : formatReminder(_reminderAt!),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_reminderAt != null)
                                        IconButton(
                                          tooltip: 'Clear reminder',
                                          onPressed: _isSaving
                                              ? null
                                              : () => setState(() => _reminderAt = null),
                                          icon: const Icon(Icons.close_rounded, size: 18),
                                        ),
                                      const Icon(Icons.chevron_right_rounded),
                                    ],
                                  ),
                                  onTap: _isSaving ? null : _pickReminder,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FormSection(
                          icon: Icons.flag_rounded,
                          title: 'Status',
                          subtitle: 'Set the event status. Saving a recurring completed event will ask how widely to apply it.',
                          child: SwitchListTile(
                            key: const Key('task-completed'),
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(
                              _isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: _isCompleted ? colors.primary : colors.onSurfaceVariant,
                            ),
                            title: Text(_isCompleted ? 'Completed' : 'Active'),
                            subtitle: Text(
                              _isCompleted
                                  ? 'This event is marked complete.'
                                  : 'This event is still active.',
                            ),
                            value: _isCompleted,
                            onChanged: _isSaving ? null : (v) => setState(() => _isCompleted = v),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FormSection(
                          icon: Icons.repeat_rounded,
                          title: 'Repeat',
                          subtitle: _recurrence == RecurrencePattern.never
                              ? 'Create a one-time event, or choose a repeat pattern.'
                              : _recurrence == RecurrencePattern.custom
                              ? 'Custom rules apply to future occurrences in this series.'
                              : 'This event repeats on a ${_recurrence.label.toLowerCase()} schedule.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<RecurrencePattern>(
                                key: const Key('task-repeat-field'),
                                initialValue: _recurrence,
                                decoration: const InputDecoration(
                                  labelText: 'Repeat',
                                  prefixIcon: Icon(Icons.repeat_rounded),
                                ),
                                items: [
                                  for (final RecurrencePattern pattern
                                      in RecurrencePattern.values)
                                    DropdownMenuItem<RecurrencePattern>(
                                      value: pattern,
                                      child: Text(pattern.label),
                                    ),
                                ],
                                onChanged: _isSaving ? null : _setRecurrence,
                              ),
                              if (_recurrence == RecurrencePattern.custom) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: colors.secondaryContainer.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colors.outlineVariant.withValues(alpha: 0.55),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.auto_awesome_rounded,
                                              size: 18, color: colors.secondary),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Custom repeat settings',
                                            style: theme.textTheme.titleSmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              key: const Key('task-repeat-interval'),
                                              controller: _recurrenceIntervalController,
                                              enabled: !_isSaving,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Every',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: DropdownButtonFormField<RecurrenceUnit>(
                                              key: const Key('task-repeat-unit'),
                                              initialValue: _recurrenceUnit,
                                              decoration: const InputDecoration(
                                                labelText: 'Unit',
                                              ),
                                              items: [
                                                for (final RecurrenceUnit unit
                                                    in RecurrenceUnit.values)
                                                  DropdownMenuItem<RecurrenceUnit>(
                                                    value: unit,
                                                    child: Text(unit.label),
                                                  ),
                                              ],
                                              onChanged: _isSaving
                                                  ? null
                                                  : (unit) {
                                                      if (unit == null) return;
                                                      setState(() => _recurrenceUnit = unit);
                                                    },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Text('Repeat on', style: theme.textTheme.labelLarge),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final int weekday in recurrenceWeekdayValues)
                                            FilterChip(
                                              key: Key('task-repeat-weekday-$weekday'),
                                              label: Text(recurrenceWeekdayShortLabel(weekday)),
                                              selected: _recurrenceWeekdays.contains(weekday),
                                              onSelected: _isSaving
                                                  ? null
                                                  : (selected) {
                                                      setState(() {
                                                        if (selected) {
                                                          _recurrenceWeekdays.add(weekday);
                                                        } else {
                                                          _recurrenceWeekdays.remove(weekday);
                                                        }
                                                      });
                                                    },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      DropdownButtonFormField<_RepeatEndType>(
                                        key: const Key('task-repeat-end-type'),
                                        initialValue: _repeatEndType,
                                        decoration: const InputDecoration(
                                          labelText: 'Ends',
                                          prefixIcon: Icon(Icons.event_repeat_rounded),
                                        ),
                                        items: const [
                                          DropdownMenuItem<_RepeatEndType>(
                                            value: _RepeatEndType.never,
                                            child: Text('Never'),
                                          ),
                                          DropdownMenuItem<_RepeatEndType>(
                                            value: _RepeatEndType.onDate,
                                            child: Text('On date'),
                                          ),
                                          DropdownMenuItem<_RepeatEndType>(
                                            value: _RepeatEndType.afterCount,
                                            child: Text('After occurrences'),
                                          ),
                                        ],
                                        onChanged: _isSaving
                                            ? null
                                            : (value) {
                                                if (value == null) return;
                                                setState(() => _repeatEndType = value);
                                              },
                                      ),
                                      if (_repeatEndType == _RepeatEndType.onDate) ...[
                                        const SizedBox(height: 8),
                                        ListTile(
                                          key: const Key('task-repeat-end-date'),
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.event_outlined),
                                          title: const Text('End date'),
                                          subtitle: Text(
                                            _repeatEndDate == null
                                                ? 'Not set'
                                                : formatShortDate(_repeatEndDate!),
                                          ),
                                          trailing: const Icon(Icons.chevron_right_rounded),
                                          onTap: _isSaving ? null : _pickRepeatEndDate,
                                        ),
                                      ],
                                      if (_repeatEndType == _RepeatEndType.afterCount) ...[
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          key: const Key('task-repeat-count'),
                                          controller: _recurrenceCountController,
                                          enabled: !_isSaving,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Number of occurrences',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FormSection(
                          icon: Icons.checklist_rounded,
                          title: 'Subtasks',
                          subtitle: 'Break the event into smaller steps.',
                          trailing: TextButton.icon(
                            onPressed: _isSaving ? null : _addSubtaskField,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add'),
                          ),
                          child: Column(
                            children: [
                              if (currentTask != null && currentTask.subtasks.isNotEmpty)
                                Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 0,
                                  color: colors.surfaceContainerLowest,
                                  child: Column(
                                    children: [
                                      for (final subtask in currentTask.subtasks)
                                        _ExistingSubtaskRow(
                                          subtask: subtask,
                                          enabled: !_isSaving,
                                          onToggle: () => _toggleExistingSubtask(subtask),
                                          onDelete: () => _deleteExistingSubtask(subtask),
                                        ),
                                    ],
                                  ),
                                ),
                              if (_newSubtaskControllers.isEmpty &&
                                  (currentTask == null || currentTask.subtasks.isEmpty))
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No subtasks yet. Add one if it helps you prepare.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              for (int index = 0; index < _newSubtaskControllers.length; index++)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _newSubtaskControllers[index],
                                          enabled: !_isSaving,
                                          textCapitalization: TextCapitalization.sentences,
                                          decoration: InputDecoration(
                                            hintText: 'Subtask ${index + 1}',
                                            prefixIcon: const Icon(
                                              Icons.subdirectory_arrow_right_rounded,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove subtask',
                                        onPressed: _isSaving
                                            ? null
                                            : () => _removeSubtaskField(index),
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    errorMessage,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: Key(_isEditing ? 'task-save' : 'task-create'),
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_isEditing ? 'Save Changes' : 'Create Task'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Text(
        'No categories yet. Create one from the Categories tab.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('None'),
          selected: selectedId == null,
          showCheckmark: false,
          onSelected: (_) => onSelected(null),
        ),
        for (final category in categories)
          ChoiceChip(
            avatar: Icon(
              iconFromCodePoint(category.iconCodePoint),
              size: 16,
              color: colorFromValue(category.colorValue),
            ),
            label: Text(category.name),
            selected: selectedId == category.id,
            showCheckmark: false,
            onSelected: (_) => onSelected(category.id),
          ),
      ],
    );
  }
}

class _ExistingSubtaskRow extends StatelessWidget {
  const _ExistingSubtaskRow({
    required this.subtask,
    required this.enabled,
    required this.onToggle,
    required this.onDelete,
  });

  final Subtask subtask;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Checkbox(
        value: subtask.isCompleted,
        onChanged: enabled ? (_) => onToggle() : null,
      ),
      title: Text(
        subtask.title,
        style: TextStyle(
          decoration: subtask.isCompleted
              ? TextDecoration.lineThrough
              : TextDecoration.none,
        ),
      ),
      trailing: IconButton(
        tooltip: 'Delete subtask',
        onPressed: enabled ? onDelete : null,
        icon: const Icon(Icons.delete_outline, size: 20),
      ),
    );
  }
}

enum _RepeatEndType { never, onDate, afterCount }

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colors.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
