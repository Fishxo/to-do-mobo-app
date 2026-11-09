import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../models/task_priority.dart';
import '../services/report_service.dart';
import '../state/app_controller.dart';
import '../utils/formatting.dart';
import '../utils/theme_colors.dart';
import '../widgets/section_header.dart';
import 'task_details_screen.dart';

/// Reports & Insights: weekly, monthly and yearly summaries of saved tasks.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const ReportService _reports = ReportService();

  ReportPeriod _period = ReportPeriod.weekly;
  late final Map<ReportPeriod, DateTime> _anchors = {
    for (final ReportPeriod period in ReportPeriod.values)
      period: DateTime.now(),
  };

  AppController get _controller => widget.controller;

  TaskReport _reportFor(ReportPeriod period) {
    return _reports.calculate(
      tasks: _controller.tasks,
      period: period,
      anchor: _anchors[period] ?? DateTime.now(),
      startOfWeek: _controller.settings.startOfWeek,
      occurrenceStates: _controller.occurrenceStates,
    );
  }

  void _selectPeriod(ReportPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
  }

  void _movePeriod(int delta) {
    final DateTime anchor = _anchors[_period] ?? DateTime.now();
    setState(() {
      switch (_period) {
        case ReportPeriod.weekly:
          _anchors[_period] = anchor.add(Duration(days: 7 * delta));
          break;
        case ReportPeriod.monthly:
          _anchors[_period] = DateTime(anchor.year, anchor.month + delta, 1);
          break;
        case ReportPeriod.yearly:
          _anchors[_period] = DateTime(anchor.year + delta, 1, 1);
          break;
      }
    });
  }

  void _goToCurrent() {
    setState(() => _anchors[_period] = DateTime.now());
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

  Future<void> _toggleTask(Task task) async {
    try {
      await _controller.toggleTask(task.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not update the task.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final TaskReport report = _reportFor(_period);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reports & Insights'),
            actions: [
              IconButton(
                key: const Key('reports-current'),
                tooltip: 'Go to current period',
                onPressed: _goToCurrent,
                icon: const Icon(Icons.today_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                _PeriodSelector(selected: _period, onSelected: _selectPeriod),
                const SizedBox(height: 14),
                _PeriodNavigator(
                  report: report,
                  onPrevious: () => _movePeriod(-1),
                  onNext: report.isCurrent ? null : () => _movePeriod(1),
                ),
                const SizedBox(height: 18),
                _CompletionCard(report: report),
                const SizedBox(height: 14),
                _BreakdownCard(report: report),
                const SizedBox(height: 14),
                _ActivityCard(report: report),
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Tasks in this period',
                  subtitle: report.total == 0
                      ? 'No tasks to show for ${_period.label.toLowerCase()} report'
                      : '${report.total} '
                            '${report.total == 1 ? 'task' : 'tasks'} · '
                            'Due here, or created when no date is set',
                ),
                const SizedBox(height: 12),
                if (report.entries.isEmpty)
                  const Card(child: _ReportEmptyState())
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (
                          int index = 0;
                          index < report.entries.length;
                          index++
                        ) ...[
                          _ReportTaskTile(
                            entry: report.entries[index],
                            onOpen: _openTask,
                            onToggle: _toggleTask,
                          ),
                          if (index < report.entries.length - 1)
                            const Divider(indent: 16, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ReportPeriod>(
      segments: [
        for (final ReportPeriod period in ReportPeriod.values)
          ButtonSegment<ReportPeriod>(
            value: period,
            label: Text(period.label),
            icon: Icon(_iconFor(period), size: 18),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (Set<ReportPeriod> selection) {
        if (selection.isNotEmpty) onSelected(selection.first);
      },
      showSelectedIcon: false,
    );
  }

  IconData _iconFor(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.weekly:
        return Icons.view_week_outlined;
      case ReportPeriod.monthly:
        return Icons.calendar_view_month_outlined;
      case ReportPeriod.yearly:
        return Icons.calendar_today_outlined;
    }
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.report,
    required this.onPrevious,
    required this.onNext,
  });

  final TaskReport report;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  String get _title {
    final DateTime start = report.range.start;
    final DateTime lastDay = DateTime(
      report.range.end.year,
      report.range.end.month,
      report.range.end.day - 1,
    );

    switch (report.period) {
      case ReportPeriod.weekly:
        if (start.month == lastDay.month) {
          return '${DateFormat('MMM d').format(start)} – '
              '${DateFormat('d, yyyy').format(lastDay)}';
        }
        if (start.year == lastDay.year) {
          return '${DateFormat('MMM d').format(start)} – '
              '${DateFormat('MMM d, yyyy').format(lastDay)}';
        }
        return '${DateFormat('MMM d, yyyy').format(start)} – '
            '${DateFormat('MMM d, yyyy').format(lastDay)}';
      case ReportPeriod.monthly:
        return DateFormat('MMMM yyyy').format(start);
      case ReportPeriod.yearly:
        return DateFormat('yyyy').format(start);
    }
  }

  String get _subtitle {
    switch (report.period) {
      case ReportPeriod.weekly:
        return DateFormat('EEEE').format(report.range.start);
      case ReportPeriod.monthly:
        return 'Monthly report';
      case ReportPeriod.yearly:
        return 'January – December ${report.range.start.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            IconButton(
              key: const Key('reports-previous'),
              tooltip: 'Previous period',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (report.isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Current',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              key: const Key('reports-next'),
              tooltip: 'Next period',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.report});

  final TaskReport report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: CircularProgressIndicator(
                      value: report.completionRate,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    '${report.completionPercentage}%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Completion', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    report.total == 0
                        ? 'No tasks in this period yet.'
                        : '${report.completed} of ${report.total} tasks '
                              'completed.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: report.completionRate,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.completionPercentage >= 75
                        ? 'Great progress this period.'
                        : report.completionPercentage >= 40
                        ? 'You are making steady progress.'
                        : 'There is room to catch up on pending tasks.',
                    style: theme.textTheme.bodySmall,
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

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.report});

  final TaskReport report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<_StatusSlice> slices = [
      _StatusSlice(
        label: 'Completed',
        count: report.completed,
        color: successColor(colors),
      ),
      _StatusSlice(
        label: 'Pending',
        count: report.pending,
        color: warningColor(colors),
      ),
      _StatusSlice(
        label: 'Overdue',
        count: report.overdue,
        color: colors.error,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task breakdown', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              'How tasks in this period are distributed.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: report.total == 0
                    ? Container(color: colors.surfaceContainerHighest)
                    : Row(
                        children: [
                          for (final _StatusSlice slice in slices)
                            if (slice.count > 0)
                              Expanded(
                                flex: slice.count,
                                child: Container(color: slice.color),
                              ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            for (final _StatusSlice slice in slices)
              _BreakdownRow(slice: slice, total: report.total),
            const SizedBox(height: 4),
            const Divider(),
            const SizedBox(height: 12),
            Text('Priority mix', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final TaskPriority priority in TaskPriority.values)
                  _PriorityCountChip(
                    priority: priority,
                    count: report.byPriority[priority] ?? 0,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSlice {
  const _StatusSlice({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.slice, required this.total});

  final _StatusSlice slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int percentage = total == 0
        ? 0
        : ((slice.count / total) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(slice.label, style: theme.textTheme.bodyMedium)),
          Text(
            '${slice.count}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '$percentage%',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityCountChip extends StatelessWidget {
  const _PriorityCountChip({required this.priority, required this.count});

  final TaskPriority priority;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = priorityColor(priority, theme.colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: count == 0 ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(priorityIcon(priority), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '${priority.label} $count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.report});

  final TaskReport report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              _descriptionFor(report.period),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            _ActivityChart(points: report.activity),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(
                  color: colors.primary,
                  label: 'Created ${report.createdActivity}',
                ),
                const SizedBox(width: 18),
                _LegendDot(
                  color: successColor(colors),
                  label: 'Completed ${report.completedActivity}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _descriptionFor(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.weekly:
        return 'Tasks created and completed each day.';
      case ReportPeriod.monthly:
        return 'Tasks created and completed each week.';
      case ReportPeriod.yearly:
        return 'Tasks created and completed each month.';
    }
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.points});

  final List<ReportActivityPoint> points;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    int maxValue = 1;
    for (final ReportActivityPoint point in points) {
      if (point.created > maxValue) maxValue = point.created;
      if (point.completed > maxValue) maxValue = point.completed;
    }

    final double barWidth = points.length > 9
        ? 4
        : points.length > 6
        ? 5
        : 7;

    return SizedBox(
      height: 164,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final ReportActivityPoint point in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Tooltip(
                  message:
                      '${point.label}: ${point.created} created, '
                      '${point.completed} completed',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 122,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _ActivityBar(
                              value: point.created,
                              maxValue: maxValue,
                              width: barWidth,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 2),
                            _ActivityBar(
                              value: point.completed,
                              maxValue: maxValue,
                              width: barWidth,
                              color: successColor(colors),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        point.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityBar extends StatelessWidget {
  const _ActivityBar({
    required this.value,
    required this.maxValue,
    required this.width,
    required this.color,
  });

  final int value;
  final int maxValue;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double height = value == 0 ? 3 : 10 + (value / maxValue) * 108;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: value == 0 ? color.withValues(alpha: 0.18) : color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ReportTaskTile extends StatelessWidget {
  const _ReportTaskTile({
    required this.entry,
    required this.onOpen,
    required this.onToggle,
  });

  final ReportTaskEntry entry;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Task task = entry.task;
    final Color statusColor = _statusColor(entry.status, colors);
    final bool isDue = task.dueDate != null;
    final String dateLabel =
        '${isDue ? 'Due' : 'Created'} '
        '${formatShortDate(entry.date)} · ${formatTime(entry.date)}';

    return InkWell(
      onTap: () => onOpen(task),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: (_) => onToggle(task),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: task.isCompleted
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isDue
                              ? Icons.event_outlined
                              : Icons.add_circle_outline_rounded,
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _StatusChip(
                          label: entry.status.label,
                          color: statusColor,
                        ),
                        _StatusChip(
                          label: '${task.priority.label} priority',
                          color: priorityColor(task.priority, colors),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ReportTaskStatus status, ColorScheme colors) {
    switch (status) {
      case ReportTaskStatus.completed:
        return successColor(colors);
      case ReportTaskStatus.pending:
        return warningColor(colors);
      case ReportTaskStatus.overdue:
        return colors.error;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ReportEmptyState extends StatelessWidget {
  const _ReportEmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_outlined,
              size: 30,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No tasks in this period',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Try another period or add a task with a date in this range.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
