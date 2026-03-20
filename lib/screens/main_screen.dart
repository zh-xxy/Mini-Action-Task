import 'package:flutter/material.dart';
import 'package:mini_action_task/screens/tabs/home_tab.dart';
import 'package:mini_action_task/screens/tabs/tasks_tab.dart';
import 'package:mini_action_task/screens/tabs/summary_tab.dart';
import 'package:mini_action_task/screens/tabs/profile_tab.dart';
import 'task_edit_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const TasksTab(),
    const SummaryTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '今日'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '任务'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '汇总'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
      floatingActionButton: _currentIndex == 1 // Only show FAB on Tasks tab
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TaskEditScreen()),
                );
                // Trigger rebuild
                setState(() {}); 
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
