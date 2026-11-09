import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../models/task_priority.dart';
import '../state/app_controller.dart';
import '../utils/formatting.dart';

class OccurrenceEditorSheet extends StatefulWidget {
  const OccurrenceEditorSheet({
    super.key,
    required this.controller,
    required this.occurrence,
  });

  final AppController controller;
  final TaskOccurrence occurrence;

  @override
  State<OccurrenceEditorSheet> createState() => _OccurrenceEditorSheetState();
}

class _OccurrenceEditorSheetState extends State<OccurrenceEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime _date;
  DateTime? _endAt;
  DateTime? _reminderAt;
  late bool _isAllDay;
  late TaskPriority _priority;
  bool _saving = false;

  Task get _task => widget.occurrence.task;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _task.title);
    _description = TextEditingController(text: _task.description);
    _date = widget.occurrence.occurrenceAt;
    _isAllDay = _task.isAllDay;
    _endAt = widget.occurrence.endAt;
    _reminderAt = _task.reminderAt;
    _priority = _task.priority;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (_isAllDay) {
        _date = DateTime(picked.year, picked.month, picked.day);
      } else {
        _date = _combine(picked, TimeOfDay.fromDateTime(_date));
        if (_endAt != null) {
          _endAt = _combine(picked, TimeOfDay.fromDateTime(_endAt!));
        }
      }
    });
  }

  Future<void> _pickTime({required bool end}) async {
    final DateTime base = end ? (_endAt ?? _date.add(const Duration(hours: 1))) : _date;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    setState(() {
      final DateTime value = _combine(_date, time);
      if (end) {
        _endAt = value;
      } else {
        _date = value;
        if (_endAt != null && !_endAt!.isAfter(_date)) {
          _endAt = _date.add(const Duration(hours: 1));
        }
      }
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    if (!_isAllDay && _endAt != null && !_endAt!.isAfter(_date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.editOccurrenceAsTask(
        original: _task,
        occurrenceAt: widget.occurrence.occurrenceAt,
        title: _title.text,
        description: _description.text,
        dueDate: _date,
        endAt: _isAllDay ? null : _endAt,
        reminderAt: _reminderAt,
        isAllDay: _isAllDay,
        priority: _priority,
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Edit this occurrence', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Only this date is changed. The recurring series stays the same.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _isAllDay,
                    onChanged: (v) => setState(() {
                      _isAllDay = v;
                      if (v) _endAt = null;
                    }),
                    title: const Text('All Day'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(formatShortDate(_date)),
                    subtitle: const Text('Date'),
                    onTap: _pickDate,
                  ),
                  if (!_isAllDay) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(formatTime(_date)),
                      subtitle: const Text('Start time'),
                      onTap: () => _pickTime(end: false),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.schedule_send_rounded),
                      title: Text(_endAt == null ? 'Not set' : formatTime(_endAt!)),
                      subtitle: const Text('End time'),
                      onTap: () => _pickTime(end: true),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save this occurrence'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
