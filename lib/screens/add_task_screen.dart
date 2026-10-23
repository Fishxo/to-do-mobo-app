import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/task_service.dart';

/// Screen used to both add a new task and edit an existing one.
/// Pass a [task] to edit it, leave it empty to create a new task.
class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key, this.task});

  final Task? task;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Validate the form before saving.
    if (!_formKey.currentState!.validate()) return;

    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();

    if (_isEditing) {
      await TaskService.instance.updateTask(
        widget.task!.id,
        title: title,
        description: description,
      );
    } else {
      await TaskService.instance.addTask(
        title: title,
        description: description,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'Add Task'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: !_isEditing,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'What do you need to do?',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional details',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save Changes' : 'Save'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
