import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/category.dart';
import '../models/recurrence.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import 'category_service.dart';
import 'task_service.dart';

class ImportResult {
  const ImportResult({required this.tasks, required this.categories});

  final int tasks;
  final int categories;
}

/// Exports and imports the SQLite data as a portable JSON document.
class ExportService {
  ExportService({required this.taskService, required this.categoryService});

  final TaskService taskService;
  final CategoryService categoryService;

  Future<Map<String, dynamic>> buildExportData() async {
    final List<Task> tasks = await taskService.getTasks();
    final List<Category> categories = await categoryService.getCategories();
    final Map<int, String> categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    return {
      'app': 'todoapp',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories
          .map(
            (category) => {
              'name': category.name,
              'colorValue': category.colorValue,
              'iconCodePoint': category.iconCodePoint,
              'isDefault': category.isDefault,
            },
          )
          .toList(),
      'tasks': tasks
          .map(
            (task) => {
              'title': task.title,
              'description': task.description,
              'isCompleted': task.isCompleted,
              'priority': task.priority.name,
              'dueDate': task.dueDate?.toIso8601String(),
              'endAt': task.endAt?.toIso8601String(),
              'reminderAt': task.reminderAt?.toIso8601String(),
              'isAllDay': task.isAllDay,
              'recurrence': task.recurrence.value,
              'recurrenceInterval': task.recurrenceInterval,
              'recurrenceUnit': task.recurrenceUnit.value,
              'recurrenceWeekdays': task.recurrenceWeekdays,
              'recurrenceEndDate': task.recurrenceEndDate?.toIso8601String(),
              'recurrenceCount': task.recurrenceCount,
              'createdAt': task.createdAt.toIso8601String(),
              'updatedAt': task.updatedAt.toIso8601String(),
              'completedAt': task.completedAt?.toIso8601String(),
              'categoryName': task.categoryId == null
                  ? null
                  : categoryNames[task.categoryId],
              'subtasks': task.subtasks
                  .map(
                    (subtask) => {
                      'title': subtask.title,
                      'isCompleted': subtask.isCompleted,
                      'createdAt': subtask.createdAt.toIso8601String(),
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }

  /// Asks for a destination and writes the JSON export. Returns the saved path
  /// or `null` when the user cancelled.
  Future<String?> exportToFile() async {
    final Map<String, dynamic> data = await buildExportData();
    final String json = const JsonEncoder.withIndent('  ').convert(data);
    final Uint8List bytes = Uint8List.fromList(utf8.encode(json));
    final String fileName =
        'todo_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';

    try {
      final Uri? uri = await FilePicker.saveFile(
        dialogTitle: 'Save task backup',
        fileName: fileName,
        mimeType: 'application/json',
        bytes: bytes,
      );
      if (uri == null) return null;

      if (uri.scheme == 'file') return uri.toFilePath();
      return uri.toString();
    } catch (_) {
      // File pickers are unavailable on some platforms. Fall back to the app
      // documents directory so exporting still works.
      final Directory directory = await getApplicationDocumentsDirectory();
      final File file = File(p.join(directory.path, fileName));
      await file.writeAsString(json, flush: true);
      return file.path;
    }
  }

  /// Lets the user choose a JSON backup and imports its tasks and categories.
  Future<ImportResult?> importFromFile() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      dialogTitle: 'Choose task backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return null;

    final PlatformFile picked = files.single;
    final Uint8List bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('The selected file could not be read.');
    }

    return importJson(utf8.decode(bytes));
  }

  Future<ImportResult> importJson(String json) async {
    final dynamic decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('This is not a valid backup file.');
    }

    final dynamic rawTasks = decoded['tasks'];
    if (rawTasks is! List) {
      throw const FormatException('The backup does not contain a task list.');
    }

    final Map<String, Category> categoriesByName = {
      for (final category in await categoryService.getCategories())
        category.name.toLowerCase(): category,
    };

    int importedCategories = 0;
    final dynamic rawCategories = decoded['categories'];
    if (rawCategories is List) {
      for (final dynamic item in rawCategories) {
        if (item is! Map<String, dynamic>) continue;
        final String name = (item['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        if (categoriesByName.containsKey(name.toLowerCase())) continue;

        final Category created = await categoryService.addCategory(
          name: name,
          colorValue: (item['colorValue'] as num?)?.toInt() ?? 0xFF3F51B5,
          iconCodePoint: (item['iconCodePoint'] as num?)?.toInt() ?? 0xe2c7,
        );
        categoriesByName[name.toLowerCase()] = created;
        importedCategories++;
      }
    }

    int importedTasks = 0;
    for (final dynamic item in rawTasks) {
      if (item is! Map<String, dynamic>) continue;
      final String title = (item['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;

      final DateTime createdAt = _date(item['createdAt']) ?? DateTime.now();
      final String? categoryName = item['categoryName'] as String?;
      final List<Subtask> subtasks = [];
      final dynamic rawSubtasks = item['subtasks'];
      if (rawSubtasks is List) {
        for (final dynamic rawSubtask in rawSubtasks) {
          if (rawSubtask is! Map<String, dynamic>) continue;
          final String subtaskTitle = (rawSubtask['title'] as String? ?? '')
              .trim();
          if (subtaskTitle.isEmpty) continue;
          subtasks.add(
            Subtask(
              id: 0,
              taskId: 0,
              title: subtaskTitle,
              isCompleted: rawSubtask['isCompleted'] as bool? ?? false,
              createdAt: _date(rawSubtask['createdAt']) ?? createdAt,
            ),
          );
        }
      }

      await taskService.importTask(
        Task(
          id: 0,
          title: title,
          description: item['description'] as String? ?? '',
          isCompleted: item['isCompleted'] as bool? ?? false,
          createdAt: createdAt,
          categoryId: categoryName == null
              ? null
              : categoriesByName[categoryName.toLowerCase()]?.id,
          priority: TaskPriority.fromName(item['priority'] as String?),
          dueDate: _date(item['dueDate']),
          endAt: _date(item['endAt']),
          reminderAt: _date(item['reminderAt']),
          isAllDay: item['isAllDay'] as bool? ?? false,
          recurrence: RecurrencePattern.fromValue(item['recurrence']),
          recurrenceInterval:
              (item['recurrenceInterval'] as num?)?.toInt() ?? 1,
          recurrenceUnit: RecurrenceUnit.fromValue(item['recurrenceUnit']),
          recurrenceWeekdays: (item['recurrenceWeekdays'] as List<dynamic>? ??
                  const [])
              .whereType<num>()
              .map((day) => day.toInt())
              .toList(growable: false),
          recurrenceEndDate: _date(item['recurrenceEndDate']),
          recurrenceCount: (item['recurrenceCount'] as num?)?.toInt(),
          updatedAt: _date(item['updatedAt']) ?? createdAt,
          completedAt: _date(item['completedAt']),
          subtasks: subtasks,
        ),
      );
      importedTasks++;
    }

    return ImportResult(tasks: importedTasks, categories: importedCategories);
  }

  DateTime? _date(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
