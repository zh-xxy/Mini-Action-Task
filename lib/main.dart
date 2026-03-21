import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mini_action_task/services/task_provider.dart';
import 'package:mini_action_task/services/notification_service.dart';
import 'package:mini_action_task/screens/main_screen.dart';
import 'package:mini_action_task/screens/task_edit_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()..loadData()),
      ],
      child: const MyApp(),
    ),
  );
}

// 全局回调
Function? onBackgroundRefreshRequested;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppShell();
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  static const MethodChannel _shortcutChannel = MethodChannel('mini_action_task/shortcut');
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _shortcutChannel.setMethodCallHandler(_handleShortcutCall);
    _shortcutChannel.invokeMethod('ready');
  }

  Future<dynamic> _handleShortcutCall(MethodCall call) async {
    for (int i = 0; i < 20; i++) {
      if (_navigatorKey.currentContext != null && _navigatorKey.currentState != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final currentContext = _navigatorKey.currentContext;
    if (currentContext == null) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    switch (call.method) {
      case 'openRecommendedTasks':
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1)),
          (route) => false,
        );
        break;
      case 'openNewTask':
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1)),
          (route) => false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        navigator.push(MaterialPageRoute(builder: (_) => const TaskEditScreen()));
        break;
      case 'refreshRecommendation':
        Provider.of<TaskProvider>(currentContext, listen: false).rotateRecommendation();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Mini Action Task',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
