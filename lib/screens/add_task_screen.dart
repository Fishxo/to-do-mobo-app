import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../state/app_controller.dart';
import '../utils/category_style.dart';
import '../utils/formatting.dart';

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
  late final AppController _controller;
  final List<TextEditingController> _newSubtaskControllers = [];

  int? _categoryId;
  late TaskPriority _priority;
  DateTime? _dueDate;
  DateTime? _reminderAt;
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
    _reminderAt = widget.task?.reminderAt;
    _priority = widget.task?.priority ?? TaskPriority.medium;
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
    for (final controller in _newSubtaskControllers) {
      controller.dispose();
    }
    super.dispose();
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
      helpText: 'Select due date',
    );
    if (picked == null) return;
    setState(() {
      _dueDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dueDate?.hour ?? 23,
        _dueDate?.minute ?? 59,
      );
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

    FocusScope.of(context).unfocus();
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    final List<String> newSubtasks = _newSubtaskControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        final Task current =
            _controller.taskById(widget.task!.id) ?? widget.task!;
        await _controller.updateTask(
          current.copyWith(
            title: title,
            description: description,
            categoryId: _categoryId,
            priority: _priority,
            dueDate: _dueDate,
            reminderAt: _reminderAt,
          ),
        );
        for (final String subtask in newSubtasks) {
          await _controller.addSubtask(current.id, subtask);
        }
      } else {
        await _controller.addTask(
          title: title,
          description: description,
          categoryId: _categoryId,
          priority: _priority,
          dueDate: _dueDate,
          reminderAt: _reminderAt,
          subtaskTitles: newSubtasks,
        );
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
            const SizedBox(height: 14),
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
              ),
            ),
            const SizedBox(height: 24),
            Text('Priority', style: theme.textTheme.titleMedium),
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
            const SizedBox(height: 24),
            Text('Category', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _CategoryPicker(
              categories: _controller.categories,
              selectedId: _categoryId,
              onSelected: (id) {
                if (!_isSaving) setState(() => _categoryId = id);
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Due date'),
                    subtitle: Text(
                      _dueDate == null
                          ? 'No due date'
                          : formatDateTime(_dueDate!),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_dueDate != null)
                          IconButton(
                            tooltip: 'Clear due date',
                            onPressed: _isSaving
                                ? null
                                : () => setState(() => _dueDate = null),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: _isSaving ? null : _pickDueDate,
                  ),
                  const Divider(),
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
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text('Subtasks', style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : _addSubtaskField,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (currentTask != null && currentTask.subtasks.isNotEmpty) ...[
              const SizedBox(height: 4),
              Card(
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
            ],
            if (_newSubtaskControllers.isEmpty &&
                (currentTask == null || currentTask.subtasks.isEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Break the task into smaller steps if it helps.',
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
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Create Task'),
            ),
          ],
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
