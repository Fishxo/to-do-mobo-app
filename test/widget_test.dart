import 'package:flutter_test/flutter_test.dart';

import 'package:todoapp/main.dart';

void main() {
  testWidgets('home screen shows sample tasks and counter',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Let the initial task load finish.
    await tester.pump();

    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('2 tasks remaining'), findsOneWidget);
    expect(find.text('Study Flutter'), findsOneWidget);
    expect(find.text('Build To-Do UI'), findsOneWidget);
  });

  testWidgets('filters switch the visible tasks',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Show only completed tasks.
    await tester.tap(find.text('Completed'));
    await tester.pump();

    expect(find.text('Study Flutter'), findsOneWidget);
    expect(find.text('Build To-Do UI'), findsNothing);

    // Show only active tasks.
    await tester.tap(find.text('Active'));
    await tester.pump();

    expect(find.text('Study Flutter'), findsNothing);
    expect(find.text('Build To-Do UI'), findsOneWidget);
  });

  testWidgets('add task screen validates an empty title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();

    // Try to save without typing a title.
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Title cannot be empty'), findsOneWidget);
  });
}
