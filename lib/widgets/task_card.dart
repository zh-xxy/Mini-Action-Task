import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdvance;
  final VoidCallback onComplete;
  final VoidCallback? onFreeze;

  const TaskCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.onAdvance,
    required this.onComplete,
    this.onFreeze,
  });

  String _getStatusText(String status) {
    switch (status) {
      case 'todo': return '待选';
      case 'in_progress': return '进行中';
      case 'done': return '已完成';
      case 'frozen': return '冻结';
      case 'deleted': return '已删除';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey;
    if (task.status == 'todo') statusColor = Colors.blue;
    if (task.status == 'in_progress') statusColor = Colors.orange;
    if (task.status == 'done') statusColor = Colors.green;

    // 通用按钮样式，缩小内边距和最小宽度
    final textButtonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.nextAction.isEmpty ? '无下一步动作' : task.nextAction,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: task.status == 'done' ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '所属: ${task.title}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_getStatusText(task.status), style: TextStyle(fontSize: 12, color: statusColor)),
                )
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(label: Text(task.importance), visualDensity: VisualDensity.compact),
                Chip(label: Text('剩 ${task.dueInDays} 天'), visualDensity: VisualDensity.compact),
                Chip(label: Text('能量 ${task.energyEstimate}'), visualDensity: VisualDensity.compact),
              ],
            ),
            const Divider(),
            // 恢复了冻结按钮，并保持紧凑布局
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 2,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('编辑'),
                  style: textButtonStyle,
                  onPressed: onEdit,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('删除', style: TextStyle(color: Colors.red)),
                  style: textButtonStyle,
                  onPressed: onDelete,
                ),
                if (task.status != 'done')
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('推进'),
                    style: textButtonStyle,
                    onPressed: onAdvance,
                  ),
                if ((task.status == 'todo' || task.status == 'in_progress') && onFreeze != null)
                  TextButton.icon(
                    icon: const Icon(Icons.ac_unit, size: 16),
                    label: const Text('冻结'),
                    style: textButtonStyle,
                    onPressed: onFreeze,
                  ),
                if (task.status != 'done')
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('完成'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 36),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onComplete,
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
