import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'screens/task_details_screen.dart';
import 'services/notification_service.dart';
import 'services/task_service.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the launch payload before the first frame so a cold start from a
  // reminder opens the task directly instead of flashing the Home screen.
  final NotificationService notificationService = NotificationService.instance;
  await notificationService.initialize();
  final int? initialNotificationTaskId = await notificationService
      .getLaunchTaskId();

  runApp(MyApp(initialNotificationTaskId: initialNotificationTaskId));
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.taskService,
    this.appController,
    this.initialNotificationTaskId,
  });

  /// Optional injection point used by tests.
  final TaskService? taskService;
  final AppController? appController;

  /// Task id supplied when the app was launched by tapping a reminder.
  final int? initialNotificationTaskId;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.appController ?? AppController(taskService: widget.taskService);
    _controller.notificationService.setTaskSelectionHandler(
      _openTaskFromNotification,
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.notificationService.setTaskSelectionHandler(null);
    _controller.dispose();
    super.dispose();
  }

  void _openTaskFromNotification(int taskId) {
    // Wait for the navigator to be ready. This also covers a tap that happens
    // while the app is resuming from the background.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              TaskDetailsScreen(controller: _controller, taskId: taskId),
        ),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Route<dynamic> _buildRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => MainShell(controller: _controller),
    );
  }

  List<Route<dynamic>> _buildInitialRoutes(String initialRoute) {
    final int? taskId = widget.initialNotificationTaskId;
    return [
      _buildRoute(const RouteSettings(name: Navigator.defaultRouteName)),
      if (taskId != null)
        MaterialPageRoute<void>(
          builder: (_) =>
              TaskDetailsScreen(controller: _controller, taskId: taskId),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Todo App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _controller.settings.themeMode,
          initialRoute: Navigator.defaultRouteName,
          onGenerateRoute: _buildRoute,
          onGenerateInitialRoutes: _buildInitialRoutes,
        );
      },
    );
  }
}
