import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/log_entry.dart';
import 'db_service.dart';
import 'task_service.dart';

class TaskProvider extends ChangeNotifier {
  final DBService _dbService = DBService();
  final TaskService _taskService = TaskService();
  static const MethodChannel _shortcutChannel = MethodChannel('mini_action_task/shortcut');

  List<Task> _allTasks = [];
  List<LogEntry> _recentLogs = [];
  bool _isLoading = false;

  int _recommendationOffset = 0;

  List<Task> get allTasks => _allTasks;
  List<LogEntry> get recentLogs => _recentLogs;
  bool get isLoading => _isLoading;

  List<Task> get activeTasks => _allTasks.where((t) => t.status != 'deleted').toList();
  
  EnergyState get energyState => _taskService.getEnergyState(_recentLogs);
  double get recentEnergyTotal => _taskService.getRecentEnergyTotal(_recentLogs);
  String get energyStateName => _taskService.getEnergyStateName(energyState);

  void rotateRecommendation() {
    _recommendationOffset++;
    notifyListeners();
    _syncWidgetRecommendation();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    await _taskService.autoFreezeOverdueTasks();
    _allTasks = await _dbService.getAllTasks();

    // 如果是新用户，库里没任务，则插入 3 个引导任务
    // 判断是否是新用户的逻辑修改为：不仅当前没任务，还要判断是不是已经有被彻底删除的记录
    // 为了简化，我们可以检查 shared_preferences 里是否标记过已初始化，或者直接检查 logs 表是否有记录
    // 这里我们检查如果有 logs 记录，说明用户不是第一次使用，只是把任务删光了
    if (_allTasks.isEmpty) {
      final hasLogs = await _dbService.getAllLogs().then((logs) => logs.isNotEmpty);
      if (!hasLogs) {
        await _insertDefaultTasks();
        _allTasks = await _dbService.getAllTasks();
      }
    }

    _recentLogs = await _dbService.getRecentLogs(days: 3); // 从 7 天改为 3 天
    await _syncWidgetRecommendation();

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
        energyEstimate: 1,
        lowEnergyOk: false,
        nextAction: "尝试点击右侧箭头推进动作\n查看统计页面的精力曲线",
        createdAt: now,
        actionHistory: [
          {'action': '了解 App 核心逻辑', 'startedAt': now.subtract(const Duration(minutes: 60)).toIso8601String(), 'endedAt': now.subtract(const Duration(minutes: 50)).toIso8601String()},
          {'action': '熟悉任务分级系统', 'startedAt': now.subtract(const Duration(minutes: 40)).toIso8601String(), 'endedAt': now.subtract(const Duration(minutes: 30)).toIso8601String()},
          {'action': '开始第一次子动作', 'startedAt': now.subtract(const Duration(minutes: 20)).toIso8601String(), 'endedAt': null}
        ],
      ),
      Task(
        id: uuid.v4(),
        title: "任务动作拆分",
        status: "in_progress",
        type: "练习",
        priority: 2,
        urgency: 1,
        importance: "支线",
        dueInDays: 3,
        energyEstimate: 1.5,
        lowEnergyOk: true,
        nextAction: "拆解你的第一个子动作\n设定一个可执行的微小目标",
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
      Task(
        id: uuid.v4(),
        title: "安装桌面小组件",
        status: "in_progress",
        type: "任务说明",
        priority: 2,
        urgency: 2,
        importance: "支线",
        dueInDays: 3,
        energyEstimate: 1,
        lowEnergyOk: true,
        nextAction: "回到手机桌面\n长按屏幕添加小组件\n找到并添加 Mini Action Task 小组件",
        createdAt: now,
      ),
      Task(
        id: uuid.v4(),
        title: "早睡",
        status: "todo",
        type: "习惯",
        priority: 1,
        urgency: 1,
        importance: "习惯",
        dueInDays: 1,
        energyEstimate: 1,
        lowEnergyOk: true,
        nextAction: "到点躺床闭眼三分钟",
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

  Future<void> hardDeleteTask(Task task) async {
    await _taskService.hardDeleteTask(task);
    await loadData();
  }
  
  Future<void> insertTask(Task task) async {
    await _dbService.insertTask(task);
    await loadData();
  }

  Future<void> updateTask(Task task) async {
    await _dbService.updateTask(task);
    await loadData();
  }

  List<Task> getRecommendedTasks() {
    return _taskService.getRecommendedTasks(activeTasks, _recentLogs, offset: _recommendationOffset);
  }

  Future<void> _syncWidgetRecommendation() async {
    final state = _taskService.getEnergyState(_recentLogs);
    List<Task> candidates = activeTasks.where((t) => t.status == 'in_progress').toList();
    List<Task> filtered = [];
    if (state == EnergyState.green) {
      filtered = List.from(candidates);
    } else if (state == EnergyState.yellow) {
      filtered = candidates.where((t) => t.energyEstimate <= 3).toList();
    } else {
      filtered = candidates.where((t) => t.lowEnergyOk && t.energyEstimate <= 2).toList();
    }
    if (filtered.isEmpty) {
      filtered = List.from(candidates);
    }
    filtered.sort((a, b) => _taskService.taskRankScore(b).compareTo(_taskService.taskRankScore(a)));

    final list = filtered.map((t) => {
      'title': t.title,
      'nextAction': _firstActionLine(t.nextAction ?? '')
    }).toList();

    try {
      await _shortcutChannel.invokeMethod('updateWidgetTasks', {
        'tasks': list,
      });
    } catch (_) {}
  }

  String _firstActionLine(String text) {
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isNotEmpty) return line;
    }
    return '先新增一个任务开始吧';
  }
}
