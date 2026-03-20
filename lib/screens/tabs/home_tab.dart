import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mini_action_task/services/db_service.dart';
import 'package:mini_action_task/services/task_service.dart';
import 'package:mini_action_task/models/task.dart';
import 'package:mini_action_task/models/log_entry.dart';
import 'package:mini_action_task/widgets/recommended_task_card.dart';
import 'package:mini_action_task/widgets/advance_task_dialog.dart';
import 'package:mini_action_task/screens/task_edit_screen.dart';
import 'package:mini_action_task/main.dart' show onBackgroundRefreshRequested;
import 'dart:math';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final DBService _dbService = DBService();
  final TaskService _taskService = TaskService();
  static const MethodChannel _shortcutChannel = MethodChannel('mini_action_task/shortcut');

  List<Task> _activeTasks = [];
  List<Task> _recommendedTasks = [];
  List<LogEntry> _recentLogs = [];
  String _randomQuote = '';
  DateTime? _lastQuoteRefreshTime;
  static String _cachedQuote = '';
  static DateTime? _cachedQuoteRefreshTime;

  String _formatEnergy(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.replaceFirst(RegExp(r'\.$'), '');
  }

  final List<String> _quotes = [
    "千里之行，始于足下。",
    "流水不腐，户枢不蠹。",
    "业精于勤，荒于嬉。",
    "锲而舍之，朽木不折；锲而不舍，金石可镂。",
    "种一棵树最好的时间是十年前，其次是现在。",
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadQuotes();
    
    // 注册全局刷新回调
    onBackgroundRefreshRequested = () {
      if (mounted) {
        _refreshRecommendedTasks();
      }
    };
  }

  @override
  void dispose() {
    // 组件销毁时移除回调
    if (onBackgroundRefreshRequested != null) {
      onBackgroundRefreshRequested = null;
    }
    super.dispose();
  }

  Future<void> _loadQuotes() async {
    final now = DateTime.now();
    if (_cachedQuoteRefreshTime != null &&
        _cachedQuote.isNotEmpty &&
        now.difference(_cachedQuoteRefreshTime!).inMinutes < 5) {
      setState(() {
        _randomQuote = _cachedQuote;
        _lastQuoteRefreshTime = _cachedQuoteRefreshTime;
      });
      return;
    }

    final customQuotes = await _dbService.getQuotes();
    final pool = <String>{
      ..._quotes,
      ...customQuotes.map((e) => e.trim()).where((e) => e.isNotEmpty),
    }.toList();
    final picked = pool[Random().nextInt(pool.length)];
    setState(() {
      _randomQuote = picked;
      _lastQuoteRefreshTime = now;
      _cachedQuote = picked;
      _cachedQuoteRefreshTime = now;
    });
  }

  Future<void> _loadData() async {
    await _taskService.autoFreezeOverdueTasks();
    final tasks = await _dbService.getActiveTasks();
    final logs = await _dbService.getRecentLogs(days: 3);
    final recommended = _taskService.getRecommendedTasks(tasks, logs);

    setState(() {
      _activeTasks = tasks;
      _recentLogs = logs;
      _recommendedTasks = recommended;
    });
    await _syncRecommendedTaskWidget(recommended);
  }

  Future<void> _syncRecommendedTaskWidget(List<Task> recommended) async {
    if (kIsWeb) return;
    final top = recommended.isNotEmpty ? recommended.first : null;
    final title = top?.title ?? '暂无推荐任务';
    final nextAction = top == null
        ? '先新增一个任务开始吧'
        : (top.nextAction.trim().isEmpty ? '补一个下一步动作' : top.nextAction.trim().split('\n').first);
    try {
      await _shortcutChannel.invokeMethod('updateWidgetTask', {
        'title': title,
        'nextAction': nextAction,
      });
    } catch (_) {}
  }

  List<Task> _buildRecommendationPool() {
    final state = _taskService.getEnergyState(_recentLogs);
    final candidates = _activeTasks
        .where((t) => t.status == 'in_progress')
        .toList();
    List<Task> filtered;
    if (state == EnergyState.green) {
      filtered = List<Task>.from(candidates);
    } else if (state == EnergyState.yellow) {
      filtered = candidates.where((t) => t.energyEstimate <= 3).toList();
    } else {
      filtered = candidates.where((t) => t.lowEnergyOk && t.energyEstimate <= 2).toList();
    }
    if (filtered.isEmpty) {
      filtered = List<Task>.from(candidates);
    }
    filtered.sort((a, b) => _taskService.taskRankScore(b).compareTo(_taskService.taskRankScore(a)));
    return filtered;
  }

  void _refreshRecommendedTasks() {
    final pool = _buildRecommendationPool();
    if (pool.isEmpty) return;
    final count = _recommendedTasks.isEmpty ? 2 : _recommendedTasks.length;
    final currentIds = _recommendedTasks.map((e) => e.id).toSet();
    final nonOverlap = pool.where((t) => !currentIds.contains(t.id)).toList();
    final picked = <Task>[];
    final source = nonOverlap.isNotEmpty ? nonOverlap : pool;
    final maxPick = count > source.length ? source.length : count;
    int start = source.length == 1 ? 0 : Random().nextInt(source.length);
    for (int i = 0; i < maxPick; i++) {
      picked.add(source[(start + i) % source.length]);
    }
    if (picked.isNotEmpty) {
      setState(() {
        _recommendedTasks = picked;
      });
      _syncRecommendedTaskWidget(picked);
    }
  }

  Future<void> _handleAdvance(Task task) async {
    final result = await showAdvanceTaskDialog(
      context: context,
      initialNextActionText: task.nextAction,
    );
    if (result == null) return;
    final text = result.nextActionText.trim();
    if (text.isEmpty) return;
    await _taskService.applyNextActionsBatch(
      task: task,
      nextActionText: text,
      completedActionsInOrder: result.completedActionsInOrder,
    );
    await _loadData();
  }

  Future<void> _handleComplete(Task task) async {
    final energyController = TextEditingController(text: _formatEnergy(task.energyEstimate));
    final confirm = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完成任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('确定要完成任务 "${task.title}" 吗？'),
            const SizedBox(height: 12),
            TextField(
              controller: energyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '实际耗能',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final value = double.tryParse(energyController.text.trim());
              Navigator.pop(context, value);
            },
            child: const Text('确定'),
          ),
        ],
      )
    );

    if (confirm != null) {
      await _taskService.completeTask(task, actualEnergy: confirm);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final energyState = _taskService.getEnergyState(_recentLogs);
    final stateName = _taskService.getEnergyStateName(energyState);
    final energyTotal = _taskService.getRecentEnergyTotal(_recentLogs);

    Color energyColor = Colors.green;
    if (energyState == EnergyState.yellow) energyColor = Colors.orange;
    if (energyState == EnergyState.red) energyColor = Colors.red;

    return Scaffold(
      appBar: AppBar(title: const Text('今日')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Recommended Tasks (Moved to Top)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('下一步推荐', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _refreshRecommendedTasks,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新推荐',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recommendedTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('暂无推荐任务，去添加一个吧！', style: TextStyle(color: Colors.grey))),
              )
            else
              ..._recommendedTasks.map((t) => RecommendedTaskCard(
                task: t,
                onAdvance: () => _handleAdvance(t),
                onComplete: () => _handleComplete(t),
              )),
            
            const SizedBox(height: 24),

            // 2. Energy Status Card (Middle)
            Card(
              color: energyColor.withOpacity(0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: energyColor.withOpacity(0.5))),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('能量状态: $stateName', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: energyColor)),
                    const SizedBox(height: 4),
                    Text('最近3天消耗: ${_formatEnergy(energyTotal)} (完成任务越多，状态越好)', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: energyColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              energyState == EnergyState.red 
                                ? '当前处于低电量模式，系统优先推荐耗能较低的预热任务。' 
                                : energyState == EnergyState.yellow
                                  ? '状态逐渐回暖，可以开始处理日常任务了。'
                                  : '趁热打铁，可以着手更有挑战性的任务了！',
                              style: TextStyle(fontSize: 12, color: energyColor.withOpacity(0.8)),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // 3. Quote Card (Today's Reminder - Moved to Bottom)
            Card(
              elevation: 2,
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _randomQuote,
                  style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.brown),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskEditScreen()),
          );
          await _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
