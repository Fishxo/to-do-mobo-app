import 'package:flutter/material.dart';

/// Shown when the selected filter has no tasks.
class EmptyTaskView extends StatelessWidget {
  const EmptyTaskView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 72,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No tasks found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
