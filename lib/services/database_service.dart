import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/subtask.dart';
import '../models/task.dart';

/// The storage contract used by the task and category services.
///
/// Today [DatabaseService] (SQLite) implements it. Later, an API data source
/// can implement the same contract for synchronization without changing the UI.
abstract class TaskStore {
  Future<List<Task>> getTasks();

  Future<Task?> getTaskById(int id);

  Future<Task> insertTask(Task task);

  Future<void> updateTask(Task task);

  Future<void> deleteTask(int id);

  Future<List<Category>> getCategories();

  Future<Category> insertCategory(Category category);

  Future<void> updateCategory(Category category);

  Future<void> deleteCategory(int id);

  Future<List<Subtask>> getSubtasksForTask(int taskId);

  Future<Subtask> insertSubtask(Subtask subtask);

  Future<void> updateSubtask(Subtask subtask);

  Future<void> deleteSubtask(int id);

  Future<void> clearCompletedTasks();
}

/// Owns the SQLite connection and all raw SQL operations.
///
/// The UI never talks to this class directly. It always goes through the
/// services, which keeps SQL out of the widgets.
class DatabaseService implements TaskStore {
  DatabaseService._();

  /// One shared instance, so the database connection is reused.
  static final DatabaseService instance = DatabaseService._();

  static const String databaseName = 'todoapp.db';
  static const String tasksTable = 'tasks';
  static const String categoriesTable = 'categories';
  static const String subtasksTable = 'subtasks';
  static const int databaseVersion = 2;

  Database? _database;
  Future<Database>? _openingDatabase;

  /// Returns the open database, opening it only once.
  Future<Database> get database async {
    final Database? existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final Future<Database> opening = _openingDatabase ??= _openDatabase();
    try {
      return await opening;
    } catch (_) {
      // Allow a later call to retry if opening failed.
      _openingDatabase = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final String databasePath = p.join(await getDatabasesPath(), databaseName);

    final Database db = await openDatabase(
      databasePath,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );

    _database = db;
    return db;
  }

  /// Runs only the first time the database file is created.
  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $categoriesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE CHECK (length(trim(name)) > 0),
        color_value INTEGER NOT NULL,
        icon_code_point INTEGER NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
          CHECK (is_default IN (0, 1)),
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tasksTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL CHECK (length(trim(title)) > 0),
        description TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0
          CHECK (is_completed IN (0, 1)),
        created_at TEXT NOT NULL,
        category_id INTEGER,
        priority INTEGER NOT NULL DEFAULT 1,
        due_at TEXT,
        reminder_at TEXT,
        updated_at TEXT,
        completed_at TEXT,
        FOREIGN KEY (category_id) REFERENCES $categoriesTable (id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $subtasksTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        title TEXT NOT NULL CHECK (length(trim(title)) > 0),
        is_completed INTEGER NOT NULL DEFAULT 0
          CHECK (is_completed IN (0, 1)),
        created_at TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES $tasksTable (id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_due_at ON $tasksTable (due_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_category ON $tasksTable '
      '(category_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subtasks_task ON $subtasksTable '
      '(task_id)',
    );
  }

  /// Runs when [databaseVersion] is increased on an existing database.
  ///
  /// Version 1 only had tasks (id, title, description, is_completed,
  /// created_at). Version 2 adds categories, subtasks, priorities, due dates,
  /// reminders and timestamps. Existing rows are kept and back-filled.
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $categoriesTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE CHECK (length(trim(name)) > 0),
          color_value INTEGER NOT NULL,
          icon_code_point INTEGER NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0
            CHECK (is_default IN (0, 1)),
          created_at TEXT NOT NULL
        )
      ''');

      final Set<String> existingColumns = (await db.rawQuery(
        'PRAGMA table_info($tasksTable)',
      )).map((row) => row['name'] as String).toSet();

      Future<void> addColumn(String name, String definition) async {
        if (!existingColumns.contains(name)) {
          await db.execute(
            'ALTER TABLE $tasksTable ADD COLUMN $name $definition',
          );
        }
      }

      await addColumn(
        'category_id',
        'INTEGER REFERENCES $categoriesTable (id) ON DELETE SET NULL',
      );
      await addColumn('priority', 'INTEGER NOT NULL DEFAULT 1');
      await addColumn('due_at', 'TEXT');
      await addColumn('reminder_at', 'TEXT');
      await addColumn('updated_at', 'TEXT');
      await addColumn('completed_at', 'TEXT');

      await db.execute(
        'UPDATE $tasksTable SET updated_at = created_at '
        'WHERE updated_at IS NULL',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $subtasksTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          title TEXT NOT NULL CHECK (length(trim(title)) > 0),
          is_completed INTEGER NOT NULL DEFAULT 0
            CHECK (is_completed IN (0, 1)),
          created_at TEXT NOT NULL,
          FOREIGN KEY (task_id) REFERENCES $tasksTable (id) ON DELETE CASCADE
        )
      ''');

      await _createIndexes(db);
    }
  }

  @override
  Future<List<Task>> getTasks() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      tasksTable,
      orderBy: 'created_at ASC, id ASC',
    );
    final Map<int, List<Subtask>> subtasks = await _getAllSubtasksGrouped(db);

    return rows
        .map(
          (row) =>
              Task.fromMap(row)
                  .copyWith(subtasks: subtasks[row['id'] as int] ?? const []),
        )
        .toList(growable: false);
  }

  Future<Map<int, List<Subtask>>> _getAllSubtasksGrouped(Database db) async {
    final List<Map<String, Object?>> rows = await db.query(
      subtasksTable,
      orderBy: 'created_at ASC, id ASC',
    );
    final Map<int, List<Subtask>> grouped = {};
    for (final row in rows) {
      final Subtask subtask = Subtask.fromMap(row);
      grouped.putIfAbsent(subtask.taskId, () => []).add(subtask);
    }
    return grouped;
  }

  @override
  Future<Task?> getTaskById(int id) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      tasksTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final List<Subtask> subtasks = await getSubtasksForTask(id);
    return Task.fromMap(rows.first).copyWith(subtasks: subtasks);
  }

  @override
  Future<Task> insertTask(Task task) async {
    final Database db = await database;

    // The id is left out so SQLite can generate it with AUTOINCREMENT.
    final int id = await db.insert(tasksTable, task.toMap(includeId: false));

    return task.copyWith(id: id);
  }

  @override
  Future<void> updateTask(Task task) async {
    final Database db = await database;
    final int updatedRows = await db.update(
      tasksTable,
      task.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    if (updatedRows == 0) {
      throw StateError('Task with id ${task.id} was not found');
    }
  }

  @override
  Future<void> deleteTask(int id) async {
    final Database db = await database;
    await db.delete(tasksTable, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Category>> getCategories() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      categoriesTable,
      orderBy: 'is_default DESC, name COLLATE NOCASE ASC',
    );
    return rows.map((row) => Category.fromMap(row)).toList(growable: false);
  }

  @override
  Future<Category> insertCategory(Category category) async {
    final Database db = await database;
    final int id = await db.insert(
      categoriesTable,
      category.toMap(includeId: false),
    );
    return category.copyWith(id: id);
  }

  @override
  Future<void> updateCategory(Category category) async {
    final Database db = await database;
    final int updatedRows = await db.update(
      categoriesTable,
      category.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [category.id],
    );

    if (updatedRows == 0) {
      throw StateError('Category with id ${category.id} was not found');
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    final Database db = await database;
    await db.transaction((txn) async {
      // Keep tasks safe: unassign them before removing the category. The
      // foreign key already does this, but the explicit update also works on
      // databases created before foreign keys were enabled.
      await txn.update(
        tasksTable,
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete(categoriesTable, where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<List<Subtask>> getSubtasksForTask(int taskId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      subtasksTable,
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map((row) => Subtask.fromMap(row)).toList(growable: false);
  }

  @override
  Future<Subtask> insertSubtask(Subtask subtask) async {
    final Database db = await database;
    final int id = await db.insert(
      subtasksTable,
      subtask.toMap(includeId: false),
    );
    return subtask.copyWith(id: id);
  }

  @override
  Future<void> updateSubtask(Subtask subtask) async {
    final Database db = await database;
    final int updatedRows = await db.update(
      subtasksTable,
      subtask.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [subtask.id],
    );

    if (updatedRows == 0) {
      throw StateError('Subtask with id ${subtask.id} was not found');
    }
  }

  @override
  Future<void> deleteSubtask(int id) async {
    final Database db = await database;
    await db.delete(subtasksTable, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearCompletedTasks() async {
    final Database db = await database;
    await db.delete(tasksTable, where: 'is_completed = ?', whereArgs: [1]);
  }

  /// Closes the shared connection. Useful for tests or a clean shutdown.
  Future<void> close() async {
    final Database? db = _database;
    _database = null;
    _openingDatabase = null;
    await db?.close();
  }
}
