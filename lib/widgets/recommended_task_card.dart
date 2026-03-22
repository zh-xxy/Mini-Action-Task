import 'package:flutter/material.dart';
import '../models/task.dart';

class RecommendedTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onAdvance;
  final VoidCallback onComplete;

  const RecommendedTaskCard({
    super.key,
    required this.task,
    required this.onAdvance,
    required this.onComplete,
  });

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200, width: 1.5),
      ),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _firstNonEmptyLine(task.nextAction).isEmpty ? "补一个子动作" : _firstNonEmptyLine(task.nextAction),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              task.importance,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ),
                          Text(
                            task.title,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('天数: ${task.dueInDays}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(width: 16),
                Text('能量: ${_formatEnergy(task.energyEstimate)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('推进'),
                  onPressed: onAdvance,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('完成'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: onComplete,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
