import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/task_priority.dart';
import '../state/app_controller.dart';
import '../utils/app_info.dart';
import '../services/export_service.dart';
import 'statistics_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBusy = false;

  AppController get _controller => widget.controller;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _isBusy = true);
    final bool success = await _controller.setNotificationsEnabled(enabled);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (enabled && !success) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.notifications_off_outlined),
          title: const Text('Permission needed'),
          content: const Text(
            'Notification permission was denied, so reminders cannot be '
            'delivered. You can enable notifications for this app in your '
            'device settings, then try again.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openNotificationDisplaySettings() async {
    final bool opened = await _controller.notificationService
        .openAndroidNotificationSettings();
    if (!mounted || opened) return;
    _showMessage(
      'Open your device Settings → Apps → Todo App → Notifications. Enable '
      'Task reminders, Show as pop-up, and App icon badges.',
    );
  }

  Future<void> _exportTasks() async {
    setState(() => _isBusy = true);
    try {
      final String? path = await _controller.exportTasks();
      if (!mounted) return;
      if (path == null) {
        _showMessage('Export cancelled.');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.file_download_done_rounded),
          title: const Text('Backup created'),
          content: SelectableText(
            'Your tasks and categories were exported to:\n\n$path',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (_) {
      _showMessage('Could not export your tasks. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importTasks() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import tasks?'),
        content: const Text(
          'Tasks from the backup will be added to your current list. Existing '
          'tasks are not replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      final ImportResult? result = await _controller.importTasks();
      if (!mounted) return;
      if (result == null) {
        _showMessage('Import cancelled.');
        return;
      }
      _showMessage(
        'Imported ${result.tasks} '
        '${result.tasks == 1 ? 'task' : 'tasks'}'
        '${result.categories > 0 ? ' and ${result.categories} categories' : ''}.',
      );
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not import the backup. Please check the file.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _clearCompleted() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear completed tasks?'),
        content: const Text(
          'All completed tasks and their subtasks will be permanently deleted. '
          'This cannot be undone.',
        ),
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
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _controller.clearCompletedTasks();
      _showMessage('Completed tasks cleared.');
    } catch (_) {
      _showMessage('Could not clear completed tasks.');
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  String _weekdayLabel(int day) {
    switch (day) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final ThemeData theme = Theme.of(context);
        final bool notificationsEnabled =
            _controller.settings.notificationsEnabled;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                children: [
                  _SectionLabel(label: 'Appearance'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Text('Theme', style: theme.textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                  icon: Icon(
                                    Icons.light_mode_outlined,
                                    size: 16,
                                  ),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                  icon: Icon(
                                    Icons.dark_mode_outlined,
                                    size: 16,
                                  ),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('System'),
                                  icon: Icon(
                                    Icons.brightness_auto_outlined,
                                    size: 16,
                                  ),
                                ),
                              ],
                              selected: {_controller.settings.themeMode},
                              showSelectedIcon: false,
                              onSelectionChanged: (selection) =>
                                  _controller.setThemeMode(selection.first),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _SectionLabel(label: 'Notifications'),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.notifications_active_outlined,
                          ),
                          title: const Text('Reminders'),
                          subtitle: Text(
                            notificationsEnabled
                                ? 'Task reminders are enabled'
                                : 'Task reminders are turned off',
                          ),
                          value: notificationsEnabled,
                          onChanged: _isBusy
                              ? null
                              : (value) => _toggleNotifications(value),
                        ),
                        const Divider(),
                        ListTile(
                          key: const Key('notification-display-settings'),
                          leading: const Icon(Icons.tune_rounded),
                          title: const Text('Pop-up and app icon badges'),
                          subtitle: const Text(
                            'Configure these in your device notification settings',
                          ),
                          trailing: const Icon(Icons.open_in_new_rounded),
                          onTap: _openNotificationDisplaySettings,
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.info_outline_rounded),
                          title: const Text('How reminders work'),
                          subtitle: const Text(
                            'Reminders are scheduled locally on this device. '
                            'They do not need an internet connection.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SectionLabel(label: 'Task preferences'),
                  Card(
                    child: Column(
                      children: [
                        _DropdownTile<TaskPriority>(
                          icon: Icons.flag_outlined,
                          title: 'Default priority',
                          value: _controller.settings.defaultPriority,
                          items: TaskPriority.values
                              .map(
                                (priority) => DropdownMenuItem(
                                  value: priority,
                                  child: Text(priority.label),
                                ),
                              )
                              .toList(),
                          onChanged: _controller.setDefaultPriority,
                        ),
                        const Divider(),
                        _DropdownTile<int>(
                          icon: Icons.calendar_view_week_outlined,
                          title: 'Start of week',
                          value: _controller.settings.startOfWeek,
                          items:
                              [
                                    DateTime.monday,
                                    DateTime.saturday,
                                    DateTime.sunday,
                                  ]
                                  .map(
                                    (day) => DropdownMenuItem(
                                      value: day,
                                      child: Text(_weekdayLabel(day)),
                                    ),
                                  )
                                  .toList(),
                          onChanged: _controller.setStartOfWeek,
                        ),
                        const Divider(),
                        _DropdownTile<TaskSortOption>(
                          icon: Icons.sort_rounded,
                          title: 'Default sorting',
                          value: _controller.settings.sortOption,
                          items: TaskSortOption.values
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option,
                                  child: Text(option.label),
                                ),
                              )
                              .toList(),
                          onChanged: _controller.setSortOption,
                        ),
                      ],
                    ),
                  ),
                  _SectionLabel(label: 'Insights'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.insights_outlined),
                      title: const Text('Task statistics'),
                      subtitle: const Text(
                        'Completion history and progress overview',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StatisticsScreen(controller: _controller),
                        ),
                      ),
                    ),
                  ),
                  _SectionLabel(label: 'Data management'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.file_upload_outlined),
                          title: const Text('Export tasks'),
                          subtitle: const Text(
                            'Save tasks and categories as a JSON backup',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _isBusy ? null : _exportTasks,
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.file_download_outlined),
                          title: const Text('Import tasks'),
                          subtitle: const Text(
                            'Add tasks from a JSON backup file',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _isBusy ? null : _importTasks,
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(
                            Icons.delete_sweep_outlined,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            'Clear completed tasks',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          subtitle: const Text(
                            'Permanently remove finished tasks',
                          ),
                          onTap: _isBusy ? null : _clearCompleted,
                        ),
                      ],
                    ),
                  ),
                  _SectionLabel(label: 'About'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.task_alt_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: const Text(AppInfo.name),
                          subtitle: Text(
                            'Version ${AppInfo.version} · '
                            '${_themeLabel(_controller.settings.themeMode)} theme',
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Text(
                            AppInfo.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isBusy)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(letterSpacing: 1.1),
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: items,
        underline: const SizedBox.shrink(),
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }
}
