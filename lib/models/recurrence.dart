enum RecurrencePattern {
  never,
  daily,
  weekly,
  monthly,
  yearly,
  custom;

  String get label => switch (this) {
    never => 'Never',
    daily => 'Daily',
    weekly => 'Weekly',
    monthly => 'Monthly',
    yearly => 'Yearly',
    custom => 'Custom',
  };

  String get value => name;

  static RecurrencePattern fromValue(Object? value) {
    if (value is RecurrencePattern) return value;
    return RecurrencePattern.values.firstWhere(
      (pattern) => pattern.value == value?.toString(),
      orElse: () => RecurrencePattern.never,
    );
  }
}

/// The unit used by a custom recurrence interval.
enum RecurrenceUnit {
  day,
  week,
  month,
  year;

  String get label => switch (this) {
    day => 'Days',
    week => 'Weeks',
    month => 'Months',
    year => 'Years',
  };

  String get singularLabel => switch (this) {
    day => 'day',
    week => 'week',
    month => 'month',
    year => 'year',
  };

  String get value => name;

  static RecurrenceUnit fromValue(Object? value) {
    if (value is RecurrenceUnit) return value;
    return RecurrenceUnit.values.firstWhere(
      (unit) => unit.value == value?.toString(),
      orElse: () => RecurrenceUnit.day,
    );
  }
}

/// Weekday values follow [DateTime.weekday]: Monday is 1 and Sunday is 7.
const List<int> recurrenceWeekdayValues = [1, 2, 3, 4, 5, 6, 7];

const List<String> recurrenceWeekdayShortLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String recurrenceWeekdayShortLabel(int weekday) {
  if (weekday < 1 || weekday > 7) return '';
  return recurrenceWeekdayShortLabels[weekday - 1];
}

String recurrenceWeekdayFullLabel(int weekday) {
  const List<String> labels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  if (weekday < 1 || weekday > 7) return '';
  return labels[weekday - 1];
}
