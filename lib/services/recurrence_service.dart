import '../models/recurrence.dart';
import '../models/task.dart';

/// Calculates the future occurrences of a recurring task.
///
/// A task with [RecurrencePattern.never] has no computed occurrences; callers
/// use its single due date instead. Recurring occurrences are based on the
/// task's due date (or its reminder time when there is no due date), so the
/// wall-clock time the user picked is preserved for every occurrence.
class RecurrenceService {
  const RecurrenceService();

  /// Hard stop so a very large [until] range cannot create an endless list.
  static const int defaultMaxOccurrences = 512;

  /// Returns the occurrences that fall inside `[from, until]`.
  ///
  /// Both bounds are inclusive. Occurrences keep the time zone of the task's
  /// due date. Custom weekdays, interval units, end dates and occurrence
  /// limits are all honoured.
  List<DateTime> occurrences(
    Task task, {
    required DateTime from,
    required DateTime until,
    int maxOccurrences = defaultMaxOccurrences,
  }) {
    if (task.recurrence == RecurrencePattern.never || maxOccurrences <= 0) {
      return <DateTime>[];
    }

    final DateTime? anchorSource = task.dueDate ?? task.reminderAt;
    if (anchorSource == null) return <DateTime>[];

    final DateTime anchor = anchorSource;
    final DateTime start = from;
    final DateTime end = until;
    if (end.isBefore(start)) return <DateTime>[];

    final Set<int> weekdays = task.recurrenceWeekdays
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toSet();
    final int interval = task.recurrenceInterval < 1
        ? 1
        : task.recurrenceInterval;
    final int? occurrenceLimit = task.recurrenceCount;

    final List<DateTime> result = <DateTime>[];
    DateTime? current = anchor;
    int emitted = 0;
    int steps = 0;

    while (current != null &&
        !current.isAfter(end) &&
        result.length < maxOccurrences &&
        steps < 100000) {
      if (_isAfterEndDate(current, task.recurrenceEndDate)) break;
      if (occurrenceLimit != null &&
          occurrenceLimit > 0 &&
          emitted >= occurrenceLimit) {
        break;
      }

      if (_isAllowed(current, task.recurrence, weekdays)) {
        if (!current.isBefore(start)) result.add(current);
        emitted++;
      } else if (occurrenceLimit != null &&
          occurrenceLimit > 0 &&
          emitted >= occurrenceLimit) {
        break;
      }

      current = _next(current, task, anchor, weekdays, interval);
      steps++;
    }

    return result;
  }

  bool _isAllowed(
    DateTime value,
    RecurrencePattern pattern,
    Set<int> weekdays,
  ) {
    if (pattern != RecurrencePattern.custom || weekdays.isEmpty) return true;
    return weekdays.contains(value.weekday);
  }

  DateTime? _next(
    DateTime current,
    Task task,
    DateTime anchor,
    Set<int> weekdays,
    int interval,
  ) {
    switch (task.recurrence) {
      case RecurrencePattern.never:
        return null;
      case RecurrencePattern.daily:
        return _addDays(current, interval);
      case RecurrencePattern.weekly:
        return _addDays(current, interval * 7);
      case RecurrencePattern.monthly:
        return _addMonths(current, interval, anchor.day);
      case RecurrencePattern.yearly:
        return _addYears(current, interval, anchor.day);
      case RecurrencePattern.custom:
        if (weekdays.isEmpty) {
          return _addUnit(current, task.recurrenceUnit, interval, anchor);
        }
        if (task.recurrenceUnit == RecurrenceUnit.week) {
          return _nextCustomWeek(current, interval, weekdays);
        }
        return _nextCustomFiltered(
          current,
          task.recurrenceUnit,
          interval,
          weekdays,
          anchor,
        );
    }
  }

  DateTime _nextCustomWeek(
    DateTime current,
    int interval,
    Set<int> weekdays,
  ) {
    final List<int> sorted = weekdays.toList()..sort();
    final DateTime weekStart = _startOfWeek(current);

    for (final int weekday in sorted) {
      if (weekday <= current.weekday) continue;
      final DateTime candidate = _addDays(weekStart, weekday - 1);
      return _withTime(candidate, current);
    }

    final DateTime nextWeek = _addDays(weekStart, interval * 7);
    return _withTime(_addDays(nextWeek, sorted.first - 1), current);
  }

  DateTime _nextCustomFiltered(
    DateTime current,
    RecurrenceUnit unit,
    int interval,
    Set<int> weekdays,
    DateTime anchor,
  ) {
    DateTime candidate = _addUnit(current, unit, interval, anchor);
    int guard = 0;
    while (!weekdays.contains(candidate.weekday) && guard < 1000) {
      candidate = _addUnit(candidate, unit, interval, anchor);
      guard++;
    }
    return candidate;
  }

  DateTime _addUnit(
    DateTime value,
    RecurrenceUnit unit,
    int interval,
    DateTime anchor,
  ) {
    switch (unit) {
      case RecurrenceUnit.day:
        return _addDays(value, interval);
      case RecurrenceUnit.week:
        return _addDays(value, interval * 7);
      case RecurrenceUnit.month:
        return _addMonths(value, interval, anchor.day);
      case RecurrenceUnit.year:
        return _addYears(value, interval, anchor.day);
    }
  }

  DateTime _addDays(DateTime value, int days) {
    return _build(
      value,
      value.year,
      value.month,
      value.day + days,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  DateTime _addMonths(DateTime value, int months, int preferredDay) {
    final int targetMonth = value.month + months;
    final int year = value.year + (targetMonth - 1) ~/ 12;
    final int month = (targetMonth - 1) % 12 + 1;
    final int day = _clampDay(year, month, preferredDay);
    return _build(
      value,
      year,
      month,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  DateTime _addYears(DateTime value, int years, int preferredDay) {
    final int year = value.year + years;
    final int day = _clampDay(year, value.month, preferredDay);
    return _build(
      value,
      year,
      value.month,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  DateTime _startOfWeek(DateTime value) {
    final DateTime day = _dateOnly(value);
    return _addDays(day, -(day.weekday - DateTime.monday));
  }

  DateTime _dateOnly(DateTime value) {
    return _build(value, value.year, value.month, value.day, 0, 0, 0, 0, 0);
  }

  DateTime _withTime(DateTime day, DateTime timeSource) {
    return _build(
      timeSource,
      day.year,
      day.month,
      day.day,
      timeSource.hour,
      timeSource.minute,
      timeSource.second,
      timeSource.millisecond,
      timeSource.microsecond,
    );
  }

  bool _isAfterEndDate(DateTime value, DateTime? endDate) {
    if (endDate == null) return false;
    final DateTime valueDay = _dateOnly(value);
    final DateTime endDay = _build(
      value,
      endDate.year,
      endDate.month,
      endDate.day,
      0,
      0,
      0,
      0,
      0,
    );
    return valueDay.isAfter(endDay);
  }

  DateTime _build(
    DateTime reference,
    int year,
    int month,
    int day,
    int hour,
    int minute,
    int second,
    int millisecond,
    int microsecond,
  ) {
    if (reference.isUtc) {
      return DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
        millisecond,
        microsecond,
      );
    }
    return DateTime(
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
  }

  int _clampDay(int year, int month, int day) {
    final int lastDay = DateTime.utc(year, month + 1, 0).day;
    return day > lastDay ? lastDay : day;
  }
}
