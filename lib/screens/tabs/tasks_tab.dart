import 'package:flutter/material.dart';
import 'package:mini_action_task/services/db_service.dart';
import 'package:mini_action_task/services/task_service.dart';
import 'package:mini_action_task/models/task.dart';
import 'package:mini_action_task/widgets/task_card.dart';
import 'package:mini_action_task/widgets/advance_task_dialog.dart';
import 'package:uuid/uuid.dart';
import '../task_edit_screen.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> with SingleTickerProviderStateMixin {
  final DBService _dbService = DBService();
  final TaskService _taskService = TaskService();
  static const List<String> _statusKeys = ['todo', 'in_progress', 'done', 'frozen', 'deleted'];
  static const List<String> _importanceOptions = ['日常', '习惯', '支线', '副本', '主线'];

  late TabController _tabController;
  Map<String, List<Task>> _tasksByStatus = {};
  bool _isLoading = true;
  String? _doneImportanceFilter;
  String? _deletedImportanceFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) return;
    setState(() {});
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final orderByMap = <String, String>{
      'todo': 'created_at DESC',
      'in_progress': '(priority * 10 + urgency) DESC, last_progress_at DESC, created_at DESC',
      'done': 'last_done_at DESC, last_progress_at DESC, created_at DESC',
      'frozen': 'frozen_at DESC, created_at DESC',
      'deleted': 'deleted_at DESC, created_at DESC',
    };
    final Map<String, List<Task>> loaded = {};
    for (final status in _statusKeys) {
      loaded[status] = await _dbService.getTasksByStatus(
        status: status,
        orderBy: orderByMap[status],
        limit: 200,
      );
    }
    setState(() {
      _tasksByStatus = loaded;
      _isLoading = false;
    });
  }

  List<Task> _getFilteredTasks(String status) {
    final list = _tasksByStatus[status] ?? [];
    if (status == 'done' && _doneImportanceFilter != null) {
      return list.where((t) => t.importance == _doneImportanceFilter).toList();
    }
    if (status == 'deleted' && _deletedImportanceFilter != null) {
      return list.where((t) => t.importance == _deletedImportanceFilter).toList();
    }
    return list;
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
    final energyController = TextEditingController(text: task.energyEstimate.toStringAsFixed(2));
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
      ),
    );

    if (confirm != null) {
      await _taskService.completeTask(task, actualEnergy: confirm);
      
      if (task.importance == '习惯') {
        if (!mounted) return;
        final recreate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('习惯打卡成功'),
            content: Text('要为明天重新创建一个 "${task.title}" 的任务吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('不用了')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('好的')),
            ],
          )
        );
        if (recreate == true) {
          final newTask = task.copyWith(
            id: const Uuid().v4(),
            status: 'todo',
            nextAction: '',
            createdAt: DateTime.now(),
            lastProgressAt: null,
            lastDoneAt: null,
            actionHistory: [],
            dueInDays: 1, 
          );
          await _dbService.insertTask(newTask);
        }
      }

      await _loadData();
    }
  }

  Future<void> _handleFreeze(Task task) async {
    final controller = TextEditingController(text: task.frozenReason ?? '');
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('冻结任务'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '冻结原因',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('冻结')),
        ],
      ),
    );
    if (reason == null) return;
    await _taskService.freezeTask(task, reason);
    await _loadData();
  }

  Future<void> _handleDelete(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除任务 "${task.title}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      )
    );

    if (confirm == true) {
      await _taskService.deleteTask(task);
      await _loadData();
    }
  }

  Future<void> _handleRestore(Task task) async {
    task.status = 'todo';
    task.frozenReason = null;
    task.frozenAt = null;
    task.deletedAt = null;
    await _dbService.updateTask(task);
    await _loadData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('任务已恢复至待选')));
  }

  void _navigateToEdit([Task? task]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskEditScreen(task: task)),
    );
    await _loadData();
  }

  String _formatDays(DateTime from, DateTime to) {
    final days = to.difference(from).inMinutes / 1440;
    return days.toStringAsFixed(2);
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildActionDurations(Task task, {required bool completed}) {
    if (task.actionHistory.isEmpty) {
      return [const Text('动作时长: 暂无记录', style: TextStyle(color: Colors.black54))];
    }
    final now = DateTime.now();
    final widgets = <Widget>[
      const Text('动作时长明细', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
    ];
    for (final item in task.actionHistory) {
      final action = (item['action'] ?? '').toString();
      final startedRaw = item['startedAt']?.toString();
      if (startedRaw == null || startedRaw.isEmpty) {
        continue;
      }
      final startedAt = DateTime.tryParse(startedRaw);
      if (startedAt == null) {
        continue;
      }
      final endedRaw = item['endedAt']?.toString();
      final endedAt = (endedRaw == null || endedRaw.isEmpty) ? null : DateTime.tryParse(endedRaw);
      final end = endedAt ?? now;
      final days = _formatDays(startedAt, end);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('• ${action.isEmpty ? '未命名动作' : action}: $days 天${completed ? '' : (endedAt == null ? '（当前进行中）' : '')}'),
        ),
      );
    }
    return widgets;
  }

  Widget _buildTaskItem(Task task, String currentTabStatus) {
    if (currentTabStatus == 'in_progress') {
      final now = DateTime.now();
      final durationDays = _formatDays(task.createdAt, now);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _handleAdvance(task)),
                ],
              ),
              Text('持续天数: $durationDays 天'),
              const SizedBox(height: 8),
              ..._buildActionDurations(task, completed: false),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: () => _navigateToEdit(task), child: const Text('编辑')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => _handleFreeze(task), child: const Text('冻结')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => _handleComplete(task), child: const Text('完成')),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (currentTabStatus == 'done') {
      final start = task.createdAt;
      final end = task.lastDoneAt ?? DateTime.now();
      final duration = _formatDays(start, end);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('起始时间: ${_formatTime(start)}'),
              Text('结束时间: ${_formatTime(end)}'),
              Text('持续: $duration 天'),
              Text('耗能: ${task.energyEstimate.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              ..._buildActionDurations(task, completed: true),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _handleDelete(task),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (currentTabStatus == 'frozen' || currentTabStatus == 'deleted') {
      final createdAt = _formatTime(task.createdAt);
      final frozenAt = task.frozenAt != null ? _formatTime(task.frozenAt!) : '未知';
      final deletedAt = task.deletedAt != null ? _formatTime(task.deletedAt!) : '未知';
      final reason = (task.frozenReason == null || task.frozenReason!.trim().isEmpty) ? '未填写' : task.frozenReason!;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(currentTabStatus == 'frozen' ? '状态: 已冻结' : '状态: 已删除'),
                    Text('创建时间: $createdAt'),
                    if (currentTabStatus == 'frozen') Text('冻结时间: $frozenAt'),
                    if (currentTabStatus == 'frozen') Text('冻结原因: $reason'),
                    if (currentTabStatus == 'deleted') Text('删除时间: $deletedAt'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.restore),
                onPressed: () => _handleRestore(task),
                tooltip: '恢复到待选',
              ),
            ],
          ),
        ),
      );
    }

    // Default 'todo' view
    return TaskCard(
      task: task,
      onEdit: () => _navigateToEdit(task),
      onDelete: () => _handleDelete(task),
      onAdvance: () => _handleAdvance(task),
      onComplete: () => _handleComplete(task),
      onFreeze: () => _handleFreeze(task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['待选', '进行中', '已完成', '冻结', '删除'];
    final statusKeys = ['todo', 'in_progress', 'done', 'frozen', 'deleted'];
    final currentStatus = statusKeys[_tabController.index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        actions: [
          if (currentStatus == 'done')
            PopupMenuButton<String>(
              onSelected: (v) => setState(() => _doneImportanceFilter = v == '全部' ? null : v),
              itemBuilder: (context) => [
                const PopupMenuItem(value: '全部', child: Text('全部')),
                ..._importanceOptions.map((e) => PopupMenuItem(value: e, child: Text(e))),
              ],
              icon: const Icon(Icons.filter_alt),
            ),
          if (currentStatus == 'deleted')
            PopupMenuButton<String>(
              onSelected: (v) => setState(() => _deletedImportanceFilter = v == '全部' ? null : v),
              itemBuilder: (context) => [
                const PopupMenuItem(value: '全部', child: Text('全部')),
                ..._importanceOptions.map((e) => PopupMenuItem(value: e, child: Text(e))),
              ],
              icon: const Icon(Icons.filter_alt),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: statusKeys.map((status) {
              final tasks = _getFilteredTasks(status);
              if (tasks.isEmpty) {
                return const Center(child: Text('列表为空'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (context, index) => _buildTaskItem(tasks[index], status),
              );
            }).toList(),
          ),
    );
  }
}
