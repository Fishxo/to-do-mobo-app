import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/models/task.dart';
import 'package:todoapp/services/report_service.dart';

Task _task({
  required int id,
  required String title,
  required DateTime createdAt,
  bool isCompleted = false,
  DateTime? dueDate,
  DateTime? completedAt,
}) {
  return Task(
    id: id,
    title: title,
    description: '',
    isCompleted: isCompleted,
    createdAt: createdAt,
    dueDate: dueDate,
    completedAt: completedAt,
  );
}

void main() {
  const ReportService service = ReportService();

  test('weekly, monthly and yearly ranges follow the calendar', () {
    final DateTime anchor = DateTime(2024, 1, 10);

    final ReportRange weekly = service.rangeFor(ReportPeriod.weekly, anchor);
    expect(weekly.start, DateTime(2024, 1, 8));
    expect(weekly.end, DateTime(2024, 1, 15));

    final ReportRange sundayWeek = service.rangeFor(
      ReportPeriod.weekly,
      anchor,
      startOfWeek: DateTime.sunday,
    );
    expect(sundayWeek.start, DateTime(2024, 1, 7));
    expect(sundayWeek.end, DateTime(2024, 1, 14));

    final ReportRange monthly = service.rangeFor(ReportPeriod.monthly, anchor);
    expect(monthly.start, DateTime(2024, 1, 1));
    expect(monthly.end, DateTime(2024, 2, 1));

    final ReportRange yearly = service.rangeFor(ReportPeriod.yearly, anchor);
    expect(yearly.start, DateTime(2024, 1, 1));
    expect(yearly.end, DateTime(2025, 1, 1));
  });

  test('reports count statuses, completion and activity', () {
    final DateTime anchor = DateTime(2024, 1, 10);
    final List<Task> tasks = [
      _task(
        id: 1,
        title: 'Completed in week',
        createdAt: DateTime(2024, 1, 1),
        dueDate: DateTime(2024, 1, 9),
        isCompleted: true,
        completedAt: DateTime(2024, 1, 10),
      ),
      _task(
        id: 2,
        title: 'Overdue in week',
        createdAt: DateTime(2024, 1, 9),
        dueDate: DateTime(2024, 1, 10),
      ),
      _task(id: 3, title: 'No due date', createdAt: DateTime(2024, 1, 12)),
      _task(
        id: 4,
        title: 'Outside week',
        createdAt: DateTime(2024, 1, 1),
        dueDate: DateTime(2024, 2, 2),
      ),
    ];

    final TaskReport report = service.calculate(
      tasks: tasks,
      period: ReportPeriod.weekly,
      anchor: anchor,
    );

    expect(report.total, 3);
    expect(report.completed, 1);
    expect(report.pending, 1);
    expect(report.overdue, 1);
    expect(report.completionPercentage, 33);
    expect(report.byPriority.isEmpty, isFalse);
    expect(report.activity, hasLength(7));
    expect(report.createdActivity, 2);
    expect(report.completedActivity, 1);
    expect(report.entries.first.date, DateTime(2024, 1, 12));
  });

  test('activity buckets adapt to the report period', () {
    final List<Task> tasks = [
      _task(
        id: 1,
        title: 'Created in January',
        createdAt: DateTime(2024, 1, 15),
      ),
    ];

    final TaskReport monthly = service.calculate(
      tasks: tasks,
      period: ReportPeriod.monthly,
      anchor: DateTime(2024, 1, 10),
    );
    expect(monthly.activity, hasLength(5));
    expect(monthly.activity.first.label, '1-7');
    expect(monthly.activity.last.label, '29-31');

    final TaskReport yearly = service.calculate(
      tasks: tasks,
      period: ReportPeriod.yearly,
      anchor: DateTime(2024, 1, 10),
    );
    expect(yearly.activity, hasLength(12));
    expect(yearly.activity[0].label, 'Jan');
    expect(yearly.activity[11].label, 'Dec');
  });

  test('current period detection uses the selected calendar range', () {
    final DateTime now = DateTime(2024, 1, 10, 12);
    expect(
      service.isCurrentPeriod(
        ReportPeriod.weekly,
        DateTime(2024, 1, 8),
        now: now,
      ),
      isTrue,
    );
    expect(
      service.isCurrentPeriod(
        ReportPeriod.weekly,
        DateTime(2024, 1, 1),
        now: now,
      ),
      isFalse,
    );
    expect(
      service.isCurrentPeriod(
        ReportPeriod.yearly,
        DateTime(2024, 6, 1),
        now: now,
      ),
      isTrue,
    );
  });
}
