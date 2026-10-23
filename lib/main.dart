import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/task_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.taskService});

  /// Optional injection point used by tests. The real app uses the shared
  /// [TaskService.instance].
  final TaskService? taskService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Tasks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: HomeScreen(taskService: taskService),
    );
  }
}
