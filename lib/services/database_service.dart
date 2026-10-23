import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

/// The storage contract used by [TaskService].
///
/// Today [DatabaseService] (SQLite) implements it. Later, an API data source
/// can implement the same contract for synchronization without changing the UI.
abstract class TaskStore {
  Future<List<Task>> getTasks();

  Future<Task?> getTaskById(int id);

  Future<Task> insertTask(Task task);

  Future<void> updateTask(Task task);

  Future<void> deleteTask(int id);
}

/// Owns the SQLite connection and all raw SQL operations.
///
/// The UI never talks to this class directly. It always goes through
/// [TaskService], which keeps SQL out of the widgets.
class DatabaseService implements TaskStore {
  DatabaseService._();

  /// One shared instance, so the database connection is reused.
  static final DatabaseService instance = DatabaseService._();

  static const String databaseName = 'todoapp.db';
  static const String tasksTable = 'tasks';
  static const int databaseVersion = 1;

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
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );

    _database = db;
    return db;
  }

  /// Runs only the first time the database file is created.
  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tasksTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL CHECK (length(trim(title)) > 0),
        description TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0
          CHECK (is_completed IN (0, 1)),
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Runs when [databaseVersion] is increased on an existing database.
  ///
  /// Future schema changes belong here, for example:
  /// ```dart
  /// if (oldVersion < 2) {
  ///   await db.execute('ALTER TABLE tasks ADD COLUMN due_at TEXT');
  /// }
  /// ```
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // No migrations yet; the app is still on version 1.
  }

  @override
  Future<List<Task>> getTasks() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      tasksTable,
      orderBy: 'created_at ASC, id ASC',
    );

    return rows.map((row) => Task.fromMap(row)).toList(growable: false);
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
    return Task.fromMap(rows.first);
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

  /// Closes the shared connection. Useful for tests or a clean shutdown.
  Future<void> close() async {
    final Database? db = _database;
    _database = null;
    _openingDatabase = null;
    await db?.close();
  }
}
