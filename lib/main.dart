import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mini_action_task/services/task_provider.dart';
import 'package:mini_action_task/services/notification_service.dart';
import 'package:mini_action_task/screens/main_screen.dart';

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
    return MaterialApp(
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
