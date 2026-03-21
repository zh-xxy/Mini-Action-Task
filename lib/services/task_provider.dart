import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/log_entry.dart';
import 'db_service.dart';
import 'task_service.dart';

class TaskProvider extends ChangeNotifier {
  final DBService _dbService = DBService();
  final TaskService _taskService = TaskService();

  List<Task> _allTasks = [];
  List<LogEntry> _recentLogs = [];
  bool _isLoading = false;

  List<Task> get allTasks => _allTasks;
  List<LogEntry> get recentLogs => _recentLogs;
  bool get isLoading => _isLoading;

  List<Task> get activeTasks => _allTasks.where((t) => t.status != 'deleted').toList();
  
  EnergyState get energyState => _taskService.getEnergyState(_recentLogs);
  double get recentEnergyTotal => _taskService.getRecentEnergyTotal(_recentLogs);
  String get energyStateName => _taskService.getEnergyStateName(energyState);

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    await _taskService.autoFreezeOverdueTasks();
    _allTasks = await _dbService.getAllTasks();

    // 如果是新用户，库里没任务，则插入 3 个引导任务
    if (_allTasks.isEmpty) {
      await _insertDefaultTasks();
      _allTasks = await _dbService.getAllTasks();
    }

    _recentLogs = await _dbService.getRecentLogs(days: 3); // 从 7 天改为 3 天

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _insertDefaultTasks() async {
    final uuid = const Uuid();
    final now = DateTime.now();
    final defaults = [
      Task(
        id: uuid.v4(),
        title: "欢迎使用 Mini Action Task",
        status: "in_progress",
        type: "任务说明",
        priority: 3,
        urgency: 3,
        importance: "主线",
        dueInDays: 7,
        energyEstimate: 5,
        lowEnergyOk: false,
        nextAction: "尝试点击右侧箭头推进动作\n查看统计页面的精力曲线",
        createdAt: now,
        actionHistory: [
          {'action': '了解 App 核心逻辑', 'startedAt': now.subtract(const Duration(minutes: 60)).toIso8601String(), 'endedAt': now.subtract(const Duration(minutes: 50)).toIso8601String()},
          {'action': '熟悉任务分级系统', 'startedAt': now.subtract(const Duration(minutes: 40)).toIso8601String(), 'endedAt': now.subtract(const Duration(minutes: 30)).toIso8601String()},
          {'action': '开始第一次下一步行动', 'startedAt': now.subtract(const Duration(minutes: 20)).toIso8601String(), 'endedAt': null}
        ],
      ),
      Task(
        id: uuid.v4(),
        title: "体验动作化管理",
        status: "todo",
        type: "练习",
        priority: 2,
        urgency: 1,
        importance: "支线",
        dueInDays: 3,
        energyEstimate: 2,
        lowEnergyOk: true,
        nextAction: "拆解你的第一个下一步动作\n设定一个可执行的微小目标",
        createdAt: now,
      ),
      Task(
        id: uuid.v4(),
        title: "每日心流复盘",
        status: "todo",
        type: "习惯",
        priority: 1,
        urgency: 1,
        importance: "习惯",
        dueInDays: 1,
        energyEstimate: 1,
        lowEnergyOk: true,
        nextAction: "查看统计页面的精力曲线\n记录今日的心情",
        createdAt: now,
      ),
    ];

    for (var t in defaults) {
      await _dbService.insertTask(t);
    }
  }

  Future<void> refresh() async {
    await loadData();
  }

  Future<void> advanceTask(Task task, String nextActionText) async {
    await _taskService.advanceTask(task, nextActionText);
    await loadData();
  }

  Future<void> applyNextActionsBatch({
    required Task task,
    required String nextActionText,
    required List<String> completedActionsInOrder,
  }) async {
    await _taskService.applyNextActionsBatch(
      task: task,
      nextActionText: nextActionText,
      completedActionsInOrder: completedActionsInOrder,
    );
    await loadData();
  }

  Future<void> completeTask(Task task, {double? actualEnergy}) async {
    await _taskService.completeTask(task, actualEnergy: actualEnergy);
    await loadData();
  }

  Future<void> freezeTask(Task task, String reason) async {
    await _taskService.freezeTask(task, reason);
    await loadData();
  }

  Future<void> deleteTask(Task task) async {
    await _taskService.deleteTask(task);
    await loadData();
  }
  
  List<Task> getRecommendedTasks() {
    return _taskService.getRecommendedTasks(activeTasks, _recentLogs);
  }
}
