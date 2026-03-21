import 'package:flutter/material.dart';
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
    _recentLogs = await _dbService.getRecentLogs(days: 5); // 之前改成的5天

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadData();
  }

  // 封装常用的 TaskService 操作，并自动通知 UI
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
