import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/log_entry.dart';
import '../services/db_service.dart';

class TaskEditScreen extends StatefulWidget {
  final Task? task;

  const TaskEditScreen({super.key, this.task});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final DBService _dbService = DBService();

  late String _title;
  late String _nextAction;
  late String _note;
  late String _importance;
  late String _type;
  late int _priority;
  late int _urgency;
  late int _dueInDays;
  late double _energyEstimate;
  late bool _lowEnergyOk;
  late String _status;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = t?.title ?? '';
    _nextAction = t?.nextAction ?? '';
    _note = t?.note ?? '';
    _importance = t?.importance ?? '日常';
    _type = t?.type ?? 'task';
    
    // Default values logic
    if (t == null) {
      _priority = _getPriorityByType(_importance);
      _urgency = 1;
      _dueInDays = 3;
      _energyEstimate = 0;
      _lowEnergyOk = false;
      _status = 'todo';
    } else {
      _priority = t.priority;
      _urgency = t.urgency;
      _dueInDays = t.dueInDays;
      _energyEstimate = t.energyEstimate;
      _lowEnergyOk = t.lowEnergyOk;
      _status = t.status;
    }
  }

  int _getPriorityByType(String type) {
    switch (type) {
      case '主线': return 5;
      case '副本': return 4;
      case '支线': return 3;
      case '习惯': return 2;
      case '日常': return 1;
      default: return 1;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final isNew = widget.task == null;
    final uuid = const Uuid();
    final now = DateTime.now();

    final task = isNew
        ? Task(id: uuid.v4(), title: _title, createdAt: now)
        : widget.task!.copyWith(
            actionHistory: widget.task!.actionHistory
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          );

    task.title = _title;
    task.nextAction = _nextAction;
    task.note = _note;
    task.importance = _importance;
    task.type = _type;
    task.priority = _priority;
    task.urgency = _urgency;
    task.dueInDays = _dueInDays;
    task.energyEstimate = _energyEstimate;
    task.lowEnergyOk = _lowEnergyOk;
    task.status = _status;
    if (_status == 'frozen') {
      task.frozenAt ??= now;
      task.frozenReason ??= '手动冻结';
    } else {
      task.frozenReason = null;
      task.frozenAt = null;
    }

    final trimmedNextAction = task.nextAction.trim();
    final firstLine = trimmedNextAction
        .split('\n')
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final shouldInitFirstActionHistory = trimmedNextAction.isNotEmpty &&
        task.actionHistory.isEmpty &&
        task.status == 'in_progress' &&
        (isNew || (widget.task?.nextAction.trim().isEmpty ?? false));
    if (shouldInitFirstActionHistory) {
      task.actionHistory = [
        {
          'action': firstLine,
          'startedAt': now.toIso8601String(),
          'endedAt': null,
        }
      ];
      task.lastProgressAt ??= now;
    }

    if (isNew) {
      await _dbService.insertTask(task);
      await _dbService.insertLog(
        LogEntry(
          id: uuid.v4(),
          taskId: task.id,
          action: 'create',
          energyValue: 0,
          createdAt: now,
        ),
      );
    } else {
      await _dbService.updateTask(task);
      await _dbService.insertLog(
        LogEntry(
          id: uuid.v4(),
          taskId: task.id,
          action: 'edit',
          energyValue: 0,
          createdAt: now,
        ),
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? '新增任务' : '编辑任务'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: _title,
              decoration: const InputDecoration(
                labelText: '任务标题',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入标题' : null,
              onSaved: (v) => _title = (v ?? '').trim(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _nextAction,
              decoration: const InputDecoration(
                labelText: '下一步动作',
                hintText: '支持批量输入，每一行代表一个动作',
                helperText: '',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.multiline,
              minLines: 4,
              maxLines: 7,
              onSaved: (v) => _nextAction = (v ?? '').trim(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _note,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.multiline,
              maxLines: 6,
              onSaved: (v) => _note = (v ?? '').trim(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _importance,
              decoration: const InputDecoration(
                labelText: '类型',
                border: OutlineInputBorder(),
              ),
              items: ['日常', '习惯', '支线', '副本', '主线']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _importance = v;
                  _priority = _getPriorityByType(v);
                });
              },
              onSaved: (v) => _importance = v ?? '日常',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    // Update key to force rebuild when _priority changes programmatically
                    key: ValueKey('priority_$_priority'),
                    initialValue: _priority.toString(),
                    decoration: const InputDecoration(
                      labelText: '优先级',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => int.tryParse(v ?? '') == null ? '请输入整数' : null,
                    onSaved: (v) => _priority = int.tryParse(v ?? '') ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('urgency_$_urgency'),
                    initialValue: _urgency.toString(),
                    decoration: const InputDecoration(
                      labelText: '紧急度',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => int.tryParse(v ?? '') == null ? '请输入整数' : null,
                    onSaved: (v) => _urgency = int.tryParse(v ?? '') ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('due_$_dueInDays'),
                    initialValue: widget.task == null ? '' : _dueInDays.toString(),
                    decoration: const InputDecoration(
                      labelText: '剩余天数',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return null;
                      return int.tryParse(text) == null ? '请输入整数' : null;
                    },
                    onSaved: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return;
                      _dueInDays = int.tryParse(text) ?? _dueInDays;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('energy_$_energyEstimate'),
                    initialValue: widget.task == null ? '' : _energyEstimate.toString(),
                    decoration: const InputDecoration(
                      labelText: '预估能量',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return null;
                      return double.tryParse(text) == null ? '请输入数字' : null;
                    },
                    onSaved: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return;
                      _energyEstimate = double.tryParse(text) ?? _energyEstimate;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('低能量可做'),
              value: _lowEnergyOk,
              onChanged: (v) => setState(() => _lowEnergyOk = v),
              contentPadding: EdgeInsets.zero,
            ),
            // Removed Status dropdown field from here
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
