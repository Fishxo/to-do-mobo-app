# Flutter from Scratch — A Simple Guide

A beginner-friendly explanation of what Flutter is, how a Flutter project is
structured, and how everything flows inside an app. Examples reference this
To-Do app.

---

## 1. What is Flutter?

Flutter is a **UI toolkit** made by Google for building apps.

You write **one codebase in Dart** and it runs on:

- Android phones
- iPhones
- Web browsers
- Windows / macOS / Linux desktops

### What is it used for?

| App type            | Examples                          |
|---------------------|-----------------------------------|
| Mobile apps         | To-Do apps, shops, banking apps   |
| Cross-platform apps | One code for Android + iOS         |
| Web apps            | Runs from the browser             |
| Desktop apps        | Windows / macOS / Linux programs  |

### What is Dart?

Dart is the **programming language** Flutter uses. Quick facts:

```dart
// Variable with a type
String title = 'Study Flutter';

// Variable with type inference (Dart figures it out)
int count = 5;          // whole numbers
bool isDone = false;    // true / false
var name = 'Ali';       // String, inferred

// Functions
int add(int a, int b) {
  return a + b;
}

// Short function
int add(int a, int b) => a + b;

// Classes hold data + behavior (see models/task.dart)
class Task {
  String title;
  bool isCompleted;
  Task(this.title, this.isCompleted);
}
```

---

## 2. The Big Idea: Everything is a Widget

> **"Flutter UI = Widgets inside widgets inside widgets."**

A widget is a small building block of the screen. You combine them like LEGO.

```
Scaffold                      (whole screen)
├── AppBar                    (top bar)
│   └── Text('My Tasks')      (title)
├── Body
│   ├── Text('2 tasks remaining')
│   └── ListView              (scrollable list)
│       ├── TaskItem          (one task row)
│       └── TaskItem
└── FloatingActionButton      (+ button)
```

Even tiny things are widgets: a button, a line of text, a padding, a color.

### Two kinds of widgets

| StatelessWidget      | StatefulWidget                    |
|----------------------|-----------------------------------|
| **Static** — never changes while on screen | **Dynamic** — changes over time |
| Example: `TaskItem`, `EmptyTaskView` | Example: `HomeScreen`, `AddTaskScreen` |
| No memory            | Has a `State` object with memory  |

**Rule of thumb:**
- Need to store data that can change (list of tasks, text field contents,
  selected filter)? → **StatefulWidget**
- Just displaying something fixed? → **StatelessWidget**

---

## 3. Project Structure (what each folder is for)

```
todoapp/
├── lib/                    ← YOUR CODE lives here (the app itself)
│   ├── main.dart           ← entry point (start of the app)
│   ├── models/             ← data shapes (Task)
│   ├── screens/            ← full pages (HomeScreen, AddTaskScreen)
│   ├── widgets/            ← small reusable pieces (TaskItem)
│   ├── services/           ← data/logic (TaskService) — where API goes later
│   └── theme/              ← colors & styling (AppTheme)
├── test/                   ← automated tests
├── android/                ← Android platform files (generated)
├── ios/                    ← iOS platform files (generated)
├── web/                    ← web platform files (generated)
├── pubspec.yaml            ← dependencies + project info (like a recipe list)
└── analysis_options.yaml   ← lint rules (code quality settings)
```

### Key folders in this app

| Folder     | Job                              | Analogy                 |
|------------|----------------------------------|-------------------------|
| `models/`  | Describes **what a Task is**     | The blueprint of a car  |
| `services/`| **Stores and changes** the data  | The engine              |
| `screens/` | Full **pages** the user visits   | Rooms in a house        |
| `widgets/` | Small **reusable UI parts**      | Furniture               |
| `theme/`   | Colors and styles                | Paint and decoration    |

### pubspec.yaml — the most important config file

```yaml
dependencies:          # packages your app needs to run
  flutter:
    sdk: flutter

dev_dependencies:      # packages only for testing/developing
  flutter_test:
    sdk: flutter
```

After adding a package → run `flutter pub get`.

---

## 4. App Flow — How the App Starts

```
You run `flutter run`
        │
        ▼
    main()                     ← lib/main.dart
        │
        ▼
   runApp(MyApp())             ← tells Flutter: "this is my app"
        │
        ▼
    MyApp.build()              ← returns MaterialApp (app shell: theme, routes)
        │
        ▼
   MaterialApp
   ├── theme: AppTheme.light / dark
   └── home: HomeScreen()      ← the first page shown
        │
        ▼
   HomeScreen.build()          ← builds the UI you see
        │
        ▼
   initState()                 ← runs ONCE when the screen is created
        │
        ▼
   _loadTasks()  ──►  TaskService.getTasks()  ──►  screen shows tasks
```

**In code (lib/main.dart):**

```dart
void main() {              // 1. App starts here
  runApp(const MyApp());   // 2. Launch the app
}

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {   // 3. Build the UI
    return MaterialApp(
      theme: AppTheme.light,
      home: const HomeScreen(),          // 4. First screen
    );
  }
}
```

---

## 5. Build Flow — How a Screen Becomes Pixels

Every widget has one job: a **`build()`** method that says *"here is what I look
like."*

```dart
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('My Tasks')),
    body: Text('$_remainingCount tasks remaining'),
  );
}
```

Flutter calls `build()`:

1. **Once** when the widget first appears
2. **Again every time `setState()` is called** (data changed)

```
setState(() { _filter = active; })
        │
        ▼
Flutter throws away the old UI
        │
        ▼
build() runs again with the new data
        │
        ▼
Screen updates  ✔
```

> ⚠️ If you change a variable **without** `setState()`, the screen will NOT
> update. This is the #1 beginner mistake.

---

## 6. StatefulWidget Lifecycle (life of a screen)

```
created  ──►  initState()  ──►  build()  ──►  user interacts
                  │                             │
                  │  (runs ONE time)            │ setState()
                  │  load data here             │
                  │                             ▼
                  │                        build() runs again
                  ▼                             │
              disposed()  ◄── screen closed ────┘
              (dispose() — clean up controllers)
```

In this app (`home_screen.dart`):

```dart
@override
void initState() {           // screen created → load tasks once
  super.initState();
  _loadTasks();
}

@override
Widget build(BuildContext context) {  // draw the screen
  ...
}
```

---

## 7. Action Flows — What Happens When the User Does Something

### A. Tap the checkbox (toggle complete)

```
User taps checkbox
      │
      ▼
Checkbox onChanged ──► onToggle() callback        (task_item.dart)
      │
      ▼
_toggleTask(task)                                  (home_screen.dart)
      │
      ▼
TaskService.toggleTask(task.id)                    (task_service.dart)
      │  flips isCompleted true ↔ false (in memory)
      ▼
_loadTasks() → setState() → build() runs
      │
      ▼
Title crosses out, counter changes  ✔
```

### B. Add a task

```
Tap FAB "+ Add Task"
      │
      ▼
Navigator.push(AddTaskScreen)     ← pushes a NEW page on the stack
      │
      ▼
User types title → taps Save
      │
      ▼
Form validates: title empty? → show "Title cannot be empty"  ✘
      │  (valid)
      ▼
TaskService.addTask(title, description)
      │
      ▼
Navigator.pop()                   ← closes the page, back to Home
      │
      ▼
HomeScreen reloads tasks → new task visible  ✔
```

### C. Edit a task

```
Tap on a task row
      │
      ▼
Navigator.push(AddTaskScreen(task: task))   ← same screen, but pre-filled
      │
      ▼
User changes title → Save
      │
      ▼
TaskService.updateTask(id, title, description)
      │
      ▼
Navigator.pop() → HomeScreen reloads → updated  ✔
```

### D. Delete a task

```
Tap the delete icon
      │
      ▼
showDialog()  ── "Are you sure?"      ← confirmation dialog
      │
      ├── Cancel  → Navigator.pop(false) → nothing happens
      │
      └── Delete  → Navigator.pop(true)
                        │
                        ▼
              TaskService.deleteTask(id)
                        │
                        ▼
              HomeScreen reloads → task gone  ✔
```

### E. Change the filter (All / Active / Completed)

```
Tap "Active"
      │
      ▼
setState(() => _filter = TaskFilter.active)   ← only UI state, no service call
      │
      ▼
build() runs → _visibleTasks getter returns only active tasks
      │
      ▼
List shows only active tasks  ✔
```

---

## 8. Navigation Flow (moving between screens)

Flutter uses a simple **stack** (like a pile of cards):

```
        ┌─────────────────┐
   top  │  AddTaskScreen   │  ◄── pushed last (currently visible)
        ├─────────────────┤
        │   HomeScreen     │
 bottom └─────────────────┘
```

Two commands only:

```dart
// GO to a new screen (push it on the stack)
Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTaskScreen()));

// COME BACK (remove the top screen)
Navigator.pop(context);
```

Flow in this app:

```
HomeScreen ──push──► AddTaskScreen ──pop──► HomeScreen
   (add)                                     (reload list)

HomeScreen ──push──► AddTaskScreen(task) ──pop──► HomeScreen
   (edit)                                         (reload list)
```

No routing package needed — `Navigator` is built in.

---

## 9. Where Does Data Live? (and why the service folder exists)

```
┌───────────────────────────────────────────────────┐
│  UI (screens/ + widgets/)                         │
│  - only DISPLAYS data                             │
│  - never stores or changes tasks by itself        │
└──────────────────────┬────────────────────────────┘
                       │ calls methods
                       ▼
┌───────────────────────────────────────────────────┐
│  Service (services/task_service.dart)             │
│  - getTasks()  addTask()  updateTask()            │
│  - deleteTask()  toggleTask()                     │
│  - TODAY: stores tasks in memory (a List)         │
│  - LATER: same method names, but uses HTTP calls  │
└──────────────────────┬────────────────────────────┘
                       │  (future)
                       ▼
              REST API → Node.js → PostgreSQL
```

**Why this matters:** when the backend arrives, you only edit
`task_service.dart` (swap list operations for `http` requests). All screens and
widgets stay exactly the same.

`Task` also has `toJson()` / `fromJson()` already, so converting to/from API
JSON is ready.

---

## 10. Quick Cheat Sheet

| I want to...                        | I use...                                  |
|-------------------------------------|-------------------------------------------|
| Start the app                       | `main()` + `runApp()` in `main.dart`       |
| Show a page                         | `Scaffold` + `AppBar` + `body`             |
| Show a list                         | `ListView.builder`                        |
| Get user input                      | `TextFormField` + `TextEditingController`  |
| Validate a form                     | `Form` + `GlobalKey<FormState>` + `validator` |
| Update the screen                   | `setState(() { ... })`                     |
| Go to another screen                | `Navigator.push(...)`                     |
| Return to previous screen           | `Navigator.pop(context)`                  |
| Ask "are you sure?"                 | `showDialog(...)`                         |
| Run code once at screen creation    | `initState()`                             |
| Clean up when screen closes         | `dispose()`                               |
| Add a package                       | `pubspec.yaml` + `flutter pub get`         |
| Check for errors                    | `flutter analyze`                         |
| Run the app                         | `flutter run`                             |
| Hot reload (see changes instantly)  | press `r` in the terminal                 |

---

## 11. Suggested Learning Path

1. ✅ Read this file and open each file in `lib/` while reading Section 3.
2. Change a color in `theme/app_theme.dart` → hot reload (`r`).
3. Change the sample tasks in `services/task_service.dart` → hot restart (`R`).
4. Add a `priority` field to `models/task.dart` and show it in `widgets/task_item.dart`.
5. Add a "Clear completed" button to the home screen.
6. Only then: learn `http` package + build the REST API backend.

**Golden rules for beginners:**

- One widget = one job, keep files small.
- UI displays, `task_service.dart` decides — never mix them.
- Data changed? → `setState()`.
- New page? → `Navigator.push`. Done with page? → `Navigator.pop`.
- Run `flutter analyze` before you think something is broken.
