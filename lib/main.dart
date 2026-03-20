import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/main_screen.dart';
import 'screens/task_edit_screen.dart';
import 'services/db_service.dart';
import 'models/task.dart';
import 'models/log_entry.dart';

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();
const MethodChannel _shortcutChannel = MethodChannel('mini_action_task/shortcut');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    print("Running on Web");
  }
  
  try {
    await _initDemoData();
  } catch (e) {
    print("Init demo data failed: $e");
  }
  _shortcutChannel.setMethodCallHandler((call) async {
    if (call.method == 'openNewTask') {
      _appNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const TaskEditScreen()),
      );
    }
  });
  
  runApp(const MyApp());
}

Future<void> _initDemoData() async {
  final dbService = DBService();
  final tasks = await dbService.getAllTasks();
  if (tasks.isEmpty) {
    final uuid = const Uuid();
    
    final task1 = Task(
      id: uuid.v4(),
      title: '写周报',
      status: 'todo',
      importance: '主线',
      dueInDays: 1,
      energyEstimate: 3.0,
      nextAction: '收集本周数据',
      priority: 5,
      urgency: 5,
      lowEnergyOk: false,
      createdAt: DateTime.now(),
    );

    final task2 = Task(
      id: uuid.v4(),
      title: '清理电脑桌面',
      status: 'todo',
      importance: '日常',
      dueInDays: 0,
      energyEstimate: 0.5,
      nextAction: '把不需要的文件扔进回收站',
      priority: 2,
      urgency: 1,
      lowEnergyOk: true,
      createdAt: DateTime.now(),
    );

    final task3 = Task(
      id: uuid.v4(),
      title: '喝一杯水，站起来活动一下',
      status: 'todo',
      importance: '习惯',
      dueInDays: 0,
      energyEstimate: 0.1,
      nextAction: '去接水',
      priority: 1,
      urgency: 2,
      lowEnergyOk: true,
      createdAt: DateTime.now(),
    );

    await dbService.insertTask(task1);
    await dbService.insertTask(task2);
    await dbService.insertTask(task3);
    
    await dbService.insertLog(LogEntry(
        id: uuid.v4(),
        taskId: task1.id,
        action: 'create',
        energyValue: 0,
        createdAt: DateTime.now(),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini Action Task',
      navigatorKey: _appNavigatorKey,
      routes: {
        '/': (context) => const MainScreen(),
        '/new-task': (context) => const TaskEditScreen(),
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
