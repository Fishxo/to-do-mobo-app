import 'package:flutter/material.dart';

enum RecurrenceCompletionScope { thisEvent, thisAndFuture, allEvents }

Future<RecurrenceCompletionScope?> showRecurringCompletionDialog(
  BuildContext context, {
  required bool completing,
  required DateTime occurrenceAt,
}) {
  return showDialog<RecurrenceCompletionScope>(
    context: context,
    builder: (context) => _RecurringCompletionDialog(
      completing: completing,
      occurrenceAt: occurrenceAt,
    ),
  );
}

class _RecurringCompletionDialog extends StatefulWidget {
  const _RecurringCompletionDialog({
    required this.completing,
    required this.occurrenceAt,
  });

  final bool completing;
  final DateTime occurrenceAt;

  @override
  State<_RecurringCompletionDialog> createState() =>
      _RecurringCompletionDialogState();
}

class _RecurringCompletionDialogState
    extends State<_RecurringCompletionDialog> {
  RecurrenceCompletionScope _selected = RecurrenceCompletionScope.thisEvent;

  String get _title => widget.completing
      ? 'Mark occurrence as completed?'
      : 'Reopen occurrence?';

  String get _subtitle => widget.completing
      ? 'Choose how this completion should apply to the recurring series.'
      : 'Choose how reopening should apply to the recurring series.';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (widget.completing ? colors.primary : colors.secondary)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              widget.completing
                  ? Icons.check_circle_outline_rounded
                  : Icons.refresh_rounded,
              color: widget.completing ? colors.primary : colors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(_subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _ScopeOption(
              selected: _selected == RecurrenceCompletionScope.thisEvent,
              icon: Icons.event_available_rounded,
              title: 'This event',
              description:
                  'Apply only to the selected occurrence. Other repeats stay unchanged.',
              onTap: () => setState(
                () => _selected = RecurrenceCompletionScope.thisEvent,
              ),
            ),
            const SizedBox(height: 10),
            _ScopeOption(
              selected: _selected == RecurrenceCompletionScope.thisAndFuture,
              icon: Icons.fast_forward_rounded,
              title: 'This and future events',
              description:
                  'Apply to this occurrence and every later occurrence in the series.',
              onTap: () => setState(
                () => _selected = RecurrenceCompletionScope.thisAndFuture,
              ),
            ),
            const SizedBox(height: 10),
            _ScopeOption(
              selected: _selected == RecurrenceCompletionScope.allEvents,
              icon: Icons.all_inclusive_rounded,
              title: 'All events',
              description:
                  'Apply to every occurrence in the series, past and future.',
              onTap: () => setState(
                () => _selected = RecurrenceCompletionScope.allEvents,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('recurring-completion-confirm'),
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color border = selected
        ? colors.primary
        : colors.outlineVariant.withValues(alpha: 0.65);
    final Color background = selected
        ? colors.primaryContainer.withValues(alpha: 0.38)
        : colors.surfaceContainerLowest;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary.withValues(alpha: 0.14)
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
