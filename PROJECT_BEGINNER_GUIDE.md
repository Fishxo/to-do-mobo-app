# My To-Do App: Beginner's Guide

This guide explains this project in simple terms. It is written for someone starting mobile application development with Flutter.

---

## 1. What this app does

This To-Do app lets the user:

- Add, edit, complete, and delete tasks
- Give tasks priorities, categories, due dates, and reminders
- Add subtasks to a main task
- Filter tasks by Today, Upcoming, Completed, or Overdue
- View tasks in a calendar
- Group tasks by category
- See task statistics
- Change light and dark theme settings
- Export or import data

The app stores its data locally using SQLite. SQLite is a small database stored on the phone.

---

## 2. The most important idea

A Flutter app is built from **widgets**.

A widget is a piece of the interface, such as:

- `Text` — displays text
- `Icon` — displays an icon
- `Button` — receives a user tap
- `Scaffold` — provides a basic screen layout
- `Column` — places widgets vertically
- `Row` — places widgets horizontally

```dart
Scaffold(
  appBar: AppBar(title: const Text('Home')), 
  body: const Text('Hello Flutter'),
)
```

Widgets are usually placed inside other widgets. This is why Flutter code looks like a widget tree.

---

## 3. Project folders

```text
lib/
├── main.dart          Starts the application
├── models/            Describes data types
├── screens/           Full pages and tabs
├── widgets/           Reusable interface pieces
├── state/             Shared application state
├── services/          Database and business operations
├── theme/             Light and dark colors
└── utils/             Small reusable helper functions
```

---

## 4. Start here: `main.dart`

Open `lib/main.dart` first.

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
```

`main()` is the first function that runs.

`runApp()` tells Flutter to build the app. Then `MyApp` creates:

- The light theme
- The dark theme
- The current theme mode
- The `AppController`
- The main page: `MainShell`

Inside `MyApp`, this part chooses the theme:

```dart
theme: AppTheme.light,
darkTheme: AppTheme.dark,
themeMode: _controller.settings.themeMode,
```

The settings screen changes the value of `themeMode`, and the app rebuilds automatically.

---

## 5. The main screen and bottom navigation

Open `lib/screens/main_shell.dart`.

`MainShell` controls four main pages:

1. Home
2. Calendar
3. Categories
4. Settings

It uses a `PageView` and a bottom `NavigationBar`.

```text
MainShell
├── HomeScreen
├── CalendarScreen
├── CategoriesScreen
└── SettingsScreen
```

The `PageController` decides which page is visible.

---

## 6. Models: what the data looks like

Models describe the shape of data used by the app.

The main model is in `lib/models/task.dart`.

A task contains information such as:

- `id`
- `title`
- `description`
- `isCompleted`
- `createdAt`
- `categoryId`
- `priority`
- `dueDate`
- `reminderAt`
- `subtasks`

Models are like data forms or blueprints.

Important conversion methods in `Task` include:

- `toMap()` — converts a task to SQLite format
- `fromMap()` — converts a SQLite row to a task
- `toJson()` — prepares task data for an API
- `fromJson()` — converts API JSON to a task

```dart
Task(
  id: 1,
  title: 'Study Flutter',
  description: 'Read widget basics',
  isCompleted: false,
  createdAt: DateTime.now(),
)
```

Other models include:

- `Category`
- `Subtask`
- `TaskPriority`
- `AppSettings`

---

## 7. Services: work with saved data

A service performs an operation. It normally contains no screen layout.

The most important service is:

```text
lib/services/task_service.dart
```

It provides operations such as:

- `getTasks()`
- `addTask()`
- `updateTask()`
- `deleteTask()`
- `toggleTask()`
- `addSubtask()`

The UI does not directly write SQLite. It asks a service to do the work.

```text
Screen -> AppController -> TaskService -> DatabaseService -> SQLite
```

That separation is useful because changing database code will not require changing every screen.

---

## 8. SQLite database

Open `lib/services/database_service.dart`.

SQLite is the database on the phone. It stores data in tables and rows, similar to simple spreadsheets.

This app has tables for information including:

- Tasks
- Categories
- Subtasks
- Settings

SQLite fields use names such as `is_completed` and `created_at`. Dart fields use names such as `isCompleted` and `createdAt`.

This conversion happens in files such as `lib/models/task.dart`:

```dart
Task.fromMap(...) // SQLite row -> Task
Task.toMap(...)   // Task -> SQLite row
```

SQLite data is permanent. Restarting the app does not normally delete it.

---

## 9. AppController: the shared control center

Open `lib/state/app_controller.dart`.

The app controller shares data with multiple screens. It extends `ChangeNotifier`, which can notify listeners when values change.

It keeps shared values such as:

- Tasks
- Categories
- Settings
- Loading state
- Error message

When it changes data, it reloads the lists and calls `notifyListeners()`.

```dart
await _taskService.updateTask(task);
await _reloadData();
```

`_reloadData()` loads new tasks and categories, then tells listening screens to rebuild.

This pattern means:

```text
User action
    -> AppController method
    -> Service saves or loads data
    -> AppController updates shared data
    -> Screen rebuilds
```

---

## 10. Home screen

Open `lib/screens/home_screen.dart`.

The home screen is responsible for:

- Showing dashboard counts
- Filtering tasks
- Sorting tasks
- Opening add/edit/task-detail screens
- Toggling and deleting tasks

The available filters are defined here:

```dart
enum TaskFilter {
  all,
  today,
  upcoming,
  completed,
  overdue,
}
```

The `_visibleTasks` getter selects the tasks that should currently be shown.

Example logic:

```dart
case TaskFilter.today:
  filtered = _controller.tasks
      .where((task) =>
          task.dueDate != null && isSameDay(task.dueDate!, now))
      .toList();
```

The `ChoiceChip` buttons change `_filter`, and `setState()` rebuilds the screen.

```dart
setState(() => _filter = TaskFilter.today);
```

---

## 11. How checkbox completion works

The task checkbox is inside `lib/widgets/task_item.dart`.

```text
Checkbox tapped
    -> TaskItem calls onToggle
    -> HomeScreen calls _toggleTask
    -> AppController.toggleTask
    -> TaskService.toggleTask
    -> DatabaseService updates SQLite
    -> AppController reloads data
    -> Screen rebuilds
```

This flow is important. It shows that the checkbox widget should only send an action. It should not directly connect to SQLite.

---

## 12. Stateful and stateless widgets

A `StatelessWidget` does not hold UI data that changes.

Examples:

- `TaskItem`
- `StatCard`
- `SectionHeader`

A `StatefulWidget` has a `State` object that can hold changing values and call `setState()`.

Examples:

- `HomeScreen`
- `AddTaskScreen`
- `CategoriesScreen`
- `MainShell`

When a value changes, call:

```dart
setState(() {
  // Update the variable here
});
```

`setState()` tells Flutter to run the widget's `build()` method again.

Important: changing a variable without `setState()` will often not update the screen.

---

## 13. Full pages and reusable widgets

`lib/screens/` contains full pages, including:

| File | Purpose |
|---|---|
| `home_screen.dart` | Home dashboard and task filtering |
| `calendar_screen.dart` | Tasks shown by calendar date |
| `categories_screen.dart` | Category list and progress |
| `category_tasks_screen.dart` | Tasks inside one category |
| `add_task_screen.dart` | Add or edit a task |
| `task_details_screen.dart` | One task and its subtasks |
| `settings_screen.dart` | Theme and app settings |
| `statistics_screen.dart` | Completion statistics |

`lib/widgets/` contains reusable pieces, including:

| File | Purpose |
|---|---|
| `task_item.dart` | One task card |
| `stat_card.dart` | Dashboard statistic card |
| `section_header.dart` | Section title and subtitle |
| `empty_task_view.dart` | Empty-list display |
| `category_editor_sheet.dart` | Category create/edit dialog |

If the same UI appears on several screens, it usually belongs in `lib/widgets/`.

---

## 14. Navigation

To move to another page, Flutter uses `Navigator`.

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TaskDetailsScreen(...),
  ),
);
```

This places a new page on top of the previous page.

To return:

```dart
Navigator.pop(context);
```

This app combines `Navigator` with the bottom-tab `MainShell`.

When a new task screen is finished, the controller reloads and the previous screen sees updated data.

---

## 15. Themes and colors

Open `lib/theme/app_theme.dart`.

The app defines:

- `AppTheme.light`
- `AppTheme.dark`

The themes use a `seedColor` and `ColorScheme`:

```dart
ColorScheme.fromSeed(
  seedColor: seedColor,
  brightness: brightness,
)
```

Inside widgets, use theme values instead of fixed colors:

```dart
final ThemeData theme = Theme.of(context);
final ColorScheme colors = theme.colorScheme;

Text(
  'Today',
  style: theme.textTheme.bodyMedium?.copyWith(
    color: colors.onSurface,
  ),
)
```

Useful theme colors:

| Name | Usually used for |
|---|---|
| `primary` | Main accent |
| `onPrimary` | Text on primary color |
| `surface` | Main page/card surface |
| `onSurface` | Normal text |
| `onSurfaceVariant` | Secondary text |
| `primaryContainer` | Selected background |
| `onPrimaryContainer` | Text on selected background |
| `error` | Overdue or dangerous state |
| `outlineVariant` | Borders and dividers |

Do not hardcode a dark text color for every screen. `Theme.of(context)` automatically changes with the selected theme.

---

## 16. Adding or changing tasks

Open `lib/screens/add_task_screen.dart`.

The screen collects values and validates the form:

```dart
final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
```

For a required title:

```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return 'Title is required';
  }
  return null;
}
```

When saving:

```dart
if (!_formKey.currentState!.validate()) return;
```

Then the screen calls `AppController` methods rather than writing to SQLite directly.

---

## 17. Packages used by this project

The package list is in `pubspec.yaml`.

| Package | Purpose |
|---|---|
| `sqflite` | Local SQLite database |
| `intl` | Dates and number formatting |
| `shared_preferences` | Small stored settings |
| `flutter_local_notifications` | Local reminder notifications |
| `timezone` | Scheduled notification time zones |
| `table_calendar` | Calendar UI |
| `file_picker` | Choose backup/import files |
| `path_provider` | Find file storage locations |

The Flutter SDK does not automatically download a new package. After changing `pubspec.yaml`, run:

```bash
flutter pub get
```

---

## 18. How to read this project

Read the files in this order:

1. `pubspec.yaml`
2. `lib/main.dart`
3. `lib/screens/main_shell.dart`
4. `lib/models/task.dart`
5. `lib/models/subtask.dart`
6. `lib/services/task_service.dart`
7. `lib/services/database_service.dart`
8. `lib/state/app_controller.dart`
9. `lib/screens/home_screen.dart`
10. `lib/widgets/task_item.dart`
11. `lib/theme/app_theme.dart`
12. `lib/screens/add_task_screen.dart`
13. The remaining category, calendar, settings, and statistics files

Do not attempt to understand every line at once. Read one complete data flow first.

A useful first flow is adding a task:

```text
Add Task screen
    -> AppController.addTask()
    -> TaskService.addTask()
    -> SQLite insertTask()
    -> AppController reloads tasks
    -> Home screen rebuilds
```

---

## 19. Common beginner patterns

### Build the screen

```dart
@override
Widget build(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  return Scaffold(...);
}
```

### Change a list or screen state

```dart
setState(() {
  _selectedIndex = 1;
});
```

### Use the controller

```dart
final Task? task = widget.controller.taskById(taskId);
```

### Open another page

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const SettingsScreen()),
);
```

### Return from another page

```dart
Navigator.pop(context);
```

---

## 20. Common mistakes

### UI does not update

Usually the changed variable should be inside `setState()` or the `AppController` should call `notifyListeners()`.

### Database fields are not found

Check spelling and types. SQLite uses snake_case in many column names, while Dart uses camelCase.

### Wrong screen theme color

Use:

```dart
Theme.of(context).colorScheme
```

and

```dart
Theme.of(context).textTheme
```

### Package not found

Run:

```bash
flutter pub get
```

### Code analysis fails

Run:

```bash
flutter analyze
```

Fix one error at a time, beginning with the first error shown.

### App behavior is unclear

Add a temporary print:

```dart
debugPrint('The button was pressed');
```

Remove temporary prints before finishing your feature.

---

## 21. Useful commands

```bash
flutter run -d chrome
flutter run -d <android-device-id>
flutter pub get
flutter analyze
flutter test
flutter clean
flutter pub upgrade
```

Inside a running terminal app:

- Press `r` to hot reload Dart changes
- Press `R` to hot restart the app
- Press `q` to quit

---

## 22. Safe beginner exercises

### Exercise 1: Change the title

In `lib/screens/home_screen.dart`, locate the `My Tasks` text and change the wording. Use hot reload to see it.

### Exercise 2: Add a filter

Understand `_visibleTasks` and add a filter that shows tasks with no due date.

### Exercise 3: Change a theme color

Change the `seedColor` in `lib/theme/app_theme.dart`, then switch light and dark themes.

### Exercise 4: Add a dashboard card

Open `lib/widgets/stat_card.dart` and use it in the home or statistics screen.

### Exercise 5: Add a task field

A beginner-friendly bigger feature is to add an estimated duration field. The feature would require changes to:

1. `Task` model
2. SQLite table and database queries
3. `TaskService`
4. Add/edit task form
5. `TaskItem`
6. Tests

This sequence teaches how data moves through the full app.

---

## 23. Golden rules

- Start understanding the app through data flow, not every class at once.
- UI files display data; services save and change data.
- Put shared data in the controller when several screens need it.
- Use `setState()` for local screen changes.
- Use `Theme.of(context)` for theme-aware colors and text styles.
- Add one small feature at a time.
- Run `flutter analyze` after edits.
- Write tests for important behavior.
- Do not put SQL logic directly inside a button or page widget.

You already have a working app. Open one small file, change one small thing, run it, and learn from the result.
