import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mini_action_task/services/task_provider.dart';
import 'package:mini_action_task/services/task_service.dart';
import 'package:mini_action_task/models/task.dart';
import 'package:mini_action_task/widgets/recommended_task_card.dart';
import 'package:mini_action_task/widgets/advance_task_dialog.dart';
import 'package:mini_action_task/screens/task_edit_screen.dart';
import 'dart:math';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _randomQuote = '';
  bool _isRefreshingRecommendation = false;
  static String _cachedQuote = '';
  static DateTime? _cachedQuoteRefreshTime;

  final List<String> _quotes = [
    "千里之行，始于足下。",
    "锲而舍之，朽木不折；锲而不舍，金石可镂。",
    "种一棵树最好的时间是十年前，其次是现在。",
    "为难于其易，为大于其细。",
  ];

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    final now = DateTime.now();
    if (_cachedQuoteRefreshTime != null &&
        _cachedQuote.isNotEmpty &&
        now.difference(_cachedQuoteRefreshTime!).inMinutes < 5) {
      setState(() {
        _randomQuote = _cachedQuote;
      });
      return;
    }

    setState(() {
      _randomQuote = _quotes[Random().nextInt(_quotes.length)];
      _cachedQuote = _randomQuote;
      _cachedQuoteRefreshTime = now;
    });
  }

  String _formatEnergy(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _handleAdvance(Task task) async {
    final result = await showAdvanceTaskDialog(
      context: context,
      initialNextActionText: task.nextAction,
    );
    if (result == null) return;
    final text = result.nextActionText.trim();
    if (text.isEmpty) return;
    
    await Provider.of<TaskProvider>(context, listen: false).applyNextActionsBatch(
      task: task,
      nextActionText: text,
      completedActionsInOrder: result.completedActionsInOrder,
    );
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
      await Provider.of<TaskProvider>(context, listen: false).completeTask(task, actualEnergy: confirm);
    }
  }

  Future<void> _refreshRecommendation(TaskProvider provider) async {
    if (_isRefreshingRecommendation) return;
    setState(() {
      _isRefreshingRecommendation = true;
    });
    // 增加短暂延迟，让用户能感知到刷新动作
    await Future.delayed(const Duration(milliseconds: 400));
    provider.rotateRecommendation();
    if (!mounted) return;
    setState(() {
      _isRefreshingRecommendation = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('推荐已刷新'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        final recommendedTasks = provider.getRecommendedTasks();
        final energyState = provider.energyState;
        final energyTotal = provider.recentEnergyTotal;
        final stateName = provider.energyStateName;

        Color energyColor = Colors.green;
        if (energyState == EnergyState.yellow) energyColor = Colors.orange;
        if (energyState == EnergyState.red) energyColor = Colors.red;

        return Scaffold(
          appBar: AppBar(title: const Text('今日')),
          body: RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('下一步推荐', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () => _refreshRecommendation(provider),
                      icon: _isRefreshingRecommendation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      tooltip: '刷新',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recommendedTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('暂无推荐任务，去添加一个吧！', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ...recommendedTasks.map((t) => RecommendedTaskCard(
                    task: t,
                    onAdvance: () => _handleAdvance(t),
                    onComplete: () => _handleComplete(t),
                  )),
                
                const SizedBox(height: 24),

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
                        Text('最近3天行动能量: ${_formatEnergy(energyTotal)}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
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
              provider.refresh();
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
