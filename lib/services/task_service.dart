import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/log_entry.dart';
import 'db_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

enum EnergyState { green, yellow, red }

class TaskService {
  final DBService _dbService = DBService();
  final _uuid = const Uuid();

  String _firstNonEmptyLine(String text) {
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isNotEmpty) return line;
    }
    return '';
  }

  String _formatEnergy(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.replaceFirst(RegExp(r'\.$'), '');
  }

  int _countActionLines(String text) {
    return text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).length;
  }

  String _packLogNote({required int units, String note = ''}) {
    final safeUnits = units < 1 ? 1 : units;
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) return 'units=$safeUnits';
    return 'units=$safeUnits|$cleanNote';
  }

  String _normalizeActionName(String text) => text.trim();

  String _historyActionName(Map<String, dynamic> item) => _normalizeActionName((item['action'] ?? '').toString());

  bool _containsActionName(List<Map<String, dynamic>> history, String actionName) {
    final normalized = _normalizeActionName(actionName);
    if (normalized.isEmpty) return false;
    return history.any((h) => _historyActionName(h) == normalized);
  }

  Future<void> advanceTask(Task task, String nextActionText) async {
    final now = DateTime.now();
    final trimmedText = nextActionText.trim();
    final nextAction = _normalizeActionName(_firstNonEmptyLine(trimmedText));
    task.nextAction = trimmedText;
    task.lastProgressAt = now;
    if (['todo', 'frozen'].contains(task.status)) {
      task.status = 'in_progress';
      task.frozenReason = null;
      task.frozenAt = null;
    }
    
    List<Map<String, dynamic>> history = List.from(task.actionHistory);
    final hasActionInHistory = _containsActionName(history, nextAction);
    final isRunningSame = history.isNotEmpty && history.last['endedAt'] == null && _historyActionName(history.last) == nextAction;
    final canStartNewAction = nextAction.isNotEmpty && (!hasActionInHistory || isRunningSame);
    int completionUnits = 0;
    // 如果最后一个动作还没结束，且动作内容一致，则不新增，只保持进行中
    if (history.isNotEmpty && history.last['endedAt'] == null) {
        if (_historyActionName(history.last) == nextAction) {
            // 内容一致，不操作
        } else {
            if (canStartNewAction) {
              history.last['endedAt'] = now.toIso8601String();
              completionUnits += 1;
              history.add({
                'action': nextAction,
                'startedAt': now.toIso8601String(),
                'endedAt': null,
              });
            }
        }
    } else if (canStartNewAction) {
        history.add({
          'action': nextAction,
          'startedAt': now.toIso8601String(),
          'endedAt': null,
        });
    }
    task.actionHistory = history;

    await _dbService.updateTask(task);

    final log = LogEntry(
      id: _uuid.v4(),
      taskId: task.id,
      action: 'advance',
      energyValue: 0,
      note: _packLogNote(units: completionUnits),
      createdAt: now,
    );
    await _dbService.insertLog(log);
  }

  Future<void> applyNextActionsBatch({
    required Task task,
    required String nextActionText,
    required List<String> completedActionsInOrder,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final trimmedText = nextActionText.trim();
    final nextAction = _normalizeActionName(_firstNonEmptyLine(trimmedText));

    task.nextAction = trimmedText;
    task.lastProgressAt = now;
    if (['todo', 'frozen'].contains(task.status)) {
      task.status = 'in_progress';
      task.frozenReason = null;
      task.frozenAt = null;
    }

    final history = task.actionHistory.map((e) => Map<String, dynamic>.from(e)).toList();
    final isRunningSame = history.isNotEmpty && history.last['endedAt'] == null && _historyActionName(history.last) == nextAction;
    final canStartNewAction = nextAction.isNotEmpty && (!_containsActionName(history, nextAction) || isRunningSame);
    int completionUnits = 0;
    
    // 1. 处理已勾选完成的动作
    if (completedActionsInOrder.isNotEmpty) {
      final cleaned = completedActionsInOrder.map(_normalizeActionName).where((e) => e.isNotEmpty).toList();
      
      // 如果当前有一个正在进行的动作，先处理它
      Map<String, dynamic>? openEntry;
      if (history.isNotEmpty && history.last['endedAt'] == null) {
        openEntry = history.removeLast();
      }

      for (var actionName in cleaned) {
        // 检查这个动作是否已经存在于历史中（防止重复添加）
        bool alreadyExists = _containsActionName(history, actionName);
        if (!alreadyExists) {
            history.add({
              'action': actionName,
              'startedAt': nowIso,
              'endedAt': nowIso,
            });
            completionUnits += 1;
        }
      }
      
      // 如果之前的 openEntry 不在 cleaned 列表中，且名称不等于新的 nextAction，则关闭它
      if (openEntry != null) {
          final openAction = _historyActionName(openEntry);
          if (!cleaned.contains(openAction) && openAction != nextAction) {
            if (canStartNewAction) {
              openEntry['endedAt'] = nowIso;
              completionUnits += 1;
            }
            history.add(openEntry);
          }
      }
    } else {
      // 没有勾选完成，仅关闭当前的 openEntry (如果存在且动作变了)
      if (history.isNotEmpty && history.last['endedAt'] == null) {
        if (_historyActionName(history.last) != nextAction && canStartNewAction) {
          history.last['endedAt'] = nowIso;
          completionUnits += 1;
        }
      }
    }

    // 2. 开启新的进行中动作 (Next Action)
    if (nextAction.isNotEmpty) {
      // 检查最后一条是否已经是这个动作且在进行中
      bool isRunning = history.isNotEmpty && 
                        _historyActionName(history.last) == nextAction && 
                        history.last['endedAt'] == null;
      if (!isRunning && canStartNewAction) {
        history.add({
          'action': nextAction,
          'startedAt': nowIso,
          'endedAt': null,
        });
      }
    }

    task.actionHistory = history;

    await _dbService.updateTask(task);
    final log = LogEntry(
      id: _uuid.v4(),
      taskId: task.id,
      action: 'advance',
      energyValue: 0,
      note: _packLogNote(units: completionUnits),
      createdAt: now,
    );
    await _dbService.insertLog(log);
  }

  Future<void> completeTask(Task task, {double? actualEnergy}) async {
    task.status = 'done';
    task.lastProgressAt = DateTime.now();
    task.lastDoneAt = DateTime.now();
    task.frozenReason = null;
    task.frozenAt = null;
    task.energyEstimate = actualEnergy ?? task.energyEstimate;
    
    List<Map<String, dynamic>> history = List.from(task.actionHistory);
    int completionUnits = _countActionLines(task.nextAction);
    if (history.isNotEmpty && history.last['endedAt'] == null) {
      history.last['endedAt'] = DateTime.now().toIso8601String();
      if (completionUnits == 0) {
        completionUnits = 1;
      }
    }
    if (completionUnits == 0) completionUnits = 1;
    task.actionHistory = history;

    await _dbService.updateTask(task);

    final energyGained = actualEnergy ?? task.energyEstimate;

    final log = LogEntry(
      id: _uuid.v4(),
      taskId: task.id,
      action: 'done',
      energyValue: energyGained,
      note: _packLogNote(
        units: completionUnits,
        note: actualEnergy != null ? '实际耗能: ${_formatEnergy(actualEnergy)}' : '',
      ),
      createdAt: DateTime.now(),
    );
    await _dbService.insertLog(log);
  }

  Future<void> freezeTask(Task task, String reason) async {
    task.status = 'frozen';
    task.frozenReason = reason.trim().isEmpty ? '未填写' : reason.trim();
    task.frozenAt = DateTime.now();
    await _dbService.updateTask(task);
    final log = LogEntry(
      id: _uuid.v4(),
      taskId: task.id,
      action: 'freeze',
      energyValue: 0,
      note: task.frozenReason ?? '',
      createdAt: DateTime.now(),
    );
    await _dbService.insertLog(log);
  }

  Future<void> deleteTask(Task task) async {
    await _dbService.softDeleteTask(task);
    final log = LogEntry(
      id: _uuid.v4(),
      taskId: task.id,
      action: 'delete',
      energyValue: 0,
      createdAt: DateTime.now(),
    );
    await _dbService.insertLog(log);
  }

  Future<void> hardDeleteTask(Task task) async {
    await _dbService.hardDeleteTask(task.id);
  }

  Future<int> autoFreezeOverdueTasks({int? overdueDays}) async {
    final threshold = overdueDays ?? await _dbService.getAutoFreezeOverdueDays();
    final allTasks = await _dbService.getAllTasks();
    final now = DateTime.now();
    int frozenCount = 0;
    for (final task in allTasks) {
      if (task.status != 'todo' && task.status != 'in_progress') continue;
      if (task.dueInDays >= -threshold) continue;
      task.status = 'frozen';
      task.frozenReason = '超时';
      task.frozenAt = now;
      await _dbService.updateTask(task);
      await _dbService.insertLog(
        LogEntry(
          id: _uuid.v4(),
          taskId: task.id,
          action: 'freeze',
          energyValue: 0,
          note: '超时',
          createdAt: now,
        ),
      );
      frozenCount++;
    }
    return frozenCount;
  }

  String getEnergyStateName(EnergyState state) {
    switch (state) {
      case EnergyState.green: return '🟢 满电状态 (适合攻坚)';
      case EnergyState.yellow: return '🟡 逐渐升温 (适合日常)';
      case EnergyState.red: return '🔴 低电量模式 (先做点小事预热吧)';
    }
  }

  EnergyState getEnergyState(List<LogEntry> recentLogs) {
    double total = getRecentEnergyTotal(recentLogs);
    // 阈值调整为 5 和 12
    if (total < 5) return EnergyState.red;      
    if (total <= 12) return EnergyState.yellow;  
    return EnergyState.green;
  }

  double getRecentEnergyTotal(List<LogEntry> recentLogs) {
    double total = 0;
    for (var log in recentLogs) {
      if (log.action == 'done') {
        total += log.energyValue;
      }
    }
    return total;
  }

  int _importanceScore(String importance) {
    switch (importance) {
      case '主线': return 5;
      case '副本': return 4;
      case '支线': return 3;
      case '习惯': return 2;
      case '日常': return 1;
      default: return 0;
    }
  }

  double taskRankScore(Task task) {
    double score = 0;
    if (task.status == 'in_progress') score += 10000;
    if (task.nextAction.isNotEmpty) score += 5000;
    
    score += _importanceScore(task.importance) * 1000;
    score += task.priority * 100;
    score += task.urgency * 10;
    score -= task.dueInDays; // smaller dueInDays gets higher score
    
    if (task.lastProgressAt != null) {
        final daysAgo = DateTime.now().difference(task.lastProgressAt!).inDays;
        score -= daysAgo; // lastProgressAt 越近越优先
    }
    
    final createdDaysAgo = DateTime.now().difference(task.createdAt).inDays;
    score -= createdDaysAgo * 0.1; // createdAt 越近越优先

    return score;
  }

  List<Task> getRecommendedTasks(List<Task> tasks, List<LogEntry> recentLogs, {int offset = 0}) {
    final state = getEnergyState(recentLogs);
    
    List<Task> candidates = tasks.where((t) => t.status == 'in_progress').toList();
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

    filtered.sort((a, b) => taskRankScore(b).compareTo(taskRankScore(a)));

    int count = 3;
    if (state == EnergyState.yellow || state == EnergyState.red) count = 2;

    if (filtered.isEmpty) return [];

    int safeOffset = offset % filtered.length;
    List<Task> rotated = [];
    for (int i = 0; i < filtered.length; i++) {
      rotated.add(filtered[(i + safeOffset) % filtered.length]);
    }

    return rotated.take(count).toList();
  }
}
