import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/statistics_service.dart';
import '../state/app_controller.dart';
import '../widgets/empty_task_view.dart';
import '../widgets/stat_card.dart';
import '../utils/theme_colors.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ThemeData theme = Theme.of(context);
        final TaskStatistics stats = controller.statistics;

        return Scaffold(
          appBar: AppBar(title: const Text('Statistics')),
          body: stats.total == 0
              ? const EmptyTaskView(
                  title: 'No insights yet',
                  message:
                      'Create and complete a few tasks to see your progress.',
                  icon: Icons.insights_outlined,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  children: [
                    Text(
                      'Your progress',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Insights calculated from your saved tasks.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Total',
                            value: stats.total,
                            icon: Icons.layers_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'Completed',
                            value: stats.completed,
                            icon: Icons.check_circle_outline_rounded,
                            color: successColor(theme.colorScheme),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Pending',
                            value: stats.pending,
                            icon: Icons.pending_outlined,
                            color: warningColor(theme.colorScheme),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'Overdue',
                            value: stats.overdue,
                            icon: Icons.error_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Card(
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
                                      value:
                                          stats.weeklyCompletionPercentage /
                                          100,
                                      strokeWidth: 9,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                    ),
                                  ),
                                  Text(
                                    '${stats.weeklyCompletionPercentage}%',
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
                                  Text(
                                    'Weekly completion',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stats.weeklyDueTasks == 0
                                        ? 'No tasks due this week yet. '
                                              'Showing overall completion.'
                                        : '${stats.weeklyCompletedDueTasks} of '
                                              '${stats.weeklyDueTasks} tasks due '
                                              'this week completed.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: stats.completionRate,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${stats.completed} of ${stats.total} tasks '
                                    'completed overall',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last 7 days',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tasks created and completed each day.',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
                            _ActivityChart(activities: stats.lastSevenDays),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _LegendDot(
                                  color: theme.colorScheme.primary,
                                  label: 'Created',
                                ),
                                const SizedBox(width: 18),
                                _LegendDot(
                                  color: successColor(theme.colorScheme),
                                  label: 'Completed',
                                ),
                              ],
                            ),
                          ],
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

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.activities});

  final List<DailyTaskActivity> activities;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    int maxValue = 1;
    for (final activity in activities) {
      if (activity.created > maxValue) maxValue = activity.created;
      if (activity.completed > maxValue) maxValue = activity.completed;
    }

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final activity in activities)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Bar(
                          value: activity.created,
                          maxValue: maxValue,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 3),
                        _Bar(
                          value: activity.completed,
                          maxValue: maxValue,
                          color: successColor(theme.colorScheme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('E').format(activity.date).substring(0, 1),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double height = value == 0 ? 3 : 18 + (value / maxValue) * 70;
    return Container(
      width: 7,
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
