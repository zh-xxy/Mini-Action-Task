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
    if (call.method == 'openRecommendedTasks' || call.method == 'refreshRecommendation') {
      _appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen(initialIndex: 0)),
        (route) => false,
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
      nextAction: '整理本周完成事项\n补齐关键数据截图\n写出三条风险说明',
      priority: 5,
      urgency: 5,
      lowEnergyOk: false,
      createdAt: DateTime.now(),
    );

    final task2 = Task(
      id: uuid.v4(),
      title: '清理电脑桌面',
      status: 'in_progress',
      importance: '日常',
      dueInDays: 0,
      energyEstimate: 1,
      nextAction: '归档项目文档到资料夹\n清空下载目录临时文件\n整理截图并统一命名',
      priority: 2,
      urgency: 1,
      lowEnergyOk: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lastProgressAt: DateTime.now().subtract(const Duration(hours: 4)),
      actionHistory: [
        {
          'action': '删除明显无用的安装包',
          'startedAt': DateTime.now().subtract(const Duration(days: 1, hours: 6)).toIso8601String(),
          'endedAt': DateTime.now().subtract(const Duration(days: 1, hours: 5)).toIso8601String(),
        },
        {
          'action': '归档项目文档到资料夹',
          'startedAt': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
          'endedAt': null,
        }
      ],
    );

    final task3 = Task(
      id: uuid.v4(),
      title: '喝一杯水，站起来活动一下',
      status: 'in_progress',
      importance: '习惯',
      dueInDays: 0,
      energyEstimate: 0.5,
      nextAction: '先喝完一杯温水\n做两分钟肩颈拉伸\n原地走动三分钟',
      priority: 1,
      urgency: 2,
      lowEnergyOk: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastProgressAt: DateTime.now().subtract(const Duration(minutes: 40)),
      actionHistory: [
        {
          'action': '先喝完一杯温水',
          'startedAt': DateTime.now().subtract(const Duration(minutes: 40)).toIso8601String(),
          'endedAt': null,
        }
      ],
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
