import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task_priority.dart';

String greetingFor(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String formatFullDate(DateTime date) {
  return DateFormat('EEEE, MMMM d').format(date);
}

String formatShortDate(DateTime date) {
  return DateFormat('MMM d, yyyy').format(date);
}

String formatTime(DateTime date) {
  return DateFormat('h:mm a').format(date);
}

String formatDateTime(DateTime date) {
  return '${formatShortDate(date)} · ${formatTime(date)}';
}

String formatDueDate(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(date.year, date.month, date.day);
  final int difference = day.difference(today).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  if (difference == -1) return 'Yesterday';
  if (difference > 1 && difference < 7) {
    return DateFormat('EEEE').format(date);
  }
  return DateFormat('MMM d').format(date);
}

String formatReminder(DateTime date) {
  return formatDateTime(date);
}

Color priorityColor(TaskPriority priority, ColorScheme colors) {
  final bool dark = colors.brightness == Brightness.dark;
  switch (priority) {
    case TaskPriority.high:
      return dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);
    case TaskPriority.medium:
      return dark ? const Color(0xFFFACD66) : const Color(0xFFA16207);
    case TaskPriority.low:
      return dark ? const Color(0xFF69DBA7) : const Color(0xFF087F5B);
  }
}

IconData priorityIcon(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return Icons.keyboard_double_arrow_up_rounded;
    case TaskPriority.medium:
      return Icons.drag_handle_rounded;
    case TaskPriority.low:
      return Icons.keyboard_arrow_down_rounded;
  }
}
