import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'services/task_service.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.taskService, this.appController});

  /// Optional injection point used by tests.
  final TaskService? taskService;
  final AppController? appController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.appController ?? AppController(taskService: widget.taskService);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Todo App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _controller.settings.themeMode,
          home: MainShell(controller: _controller),
        );
      },
    );
  }
}
