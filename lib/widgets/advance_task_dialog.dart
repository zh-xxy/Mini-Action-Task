import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AdvanceDialogResult {
  final String nextActionText;
  final List<String> completedActionsInOrder;

  const AdvanceDialogResult({
    required this.nextActionText,
    required this.completedActionsInOrder,
  });
}

class _ActionItem {
  final String id;
  final TextEditingController controller;
  bool done;

  _ActionItem({
    required this.id,
    required this.controller,
    required this.done,
  });
}

Future<AdvanceDialogResult?> showAdvanceTaskDialog({
  required BuildContext context,
  required String initialNextActionText,
}) async {
  return _showParseDialog(context: context, text: initialNextActionText);
}

Future<AdvanceDialogResult?> _showParseDialog({
  required BuildContext context,
  required String text,
}) async {
  final uuid = const Uuid();
  final initialLines = text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final items = initialLines
      .map(
        (e) => _ActionItem(
          id: uuid.v4(),
          controller: TextEditingController(text: e),
          done: false,
        ),
      )
      .toList();
  if (items.isEmpty) {
    items.add(
      _ActionItem(
        id: uuid.v4(),
        controller: TextEditingController(text: ''),
        done: false,
      ),
    );
  }

  return showDialog<AdvanceDialogResult>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('批量解析下一步动作'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: const Text(
                      '1. 一行代表一个动作；2. 勾选表示本次已完成；\n'
                      '3. 拖拽可调整顺序；4. “应用”后未勾选内容会保留为下一步动作。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: items.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = items.removeAt(oldIndex);
                          items.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          key: ValueKey(item.id),
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: item.done,
                            onChanged: (v) => setState(() => item.done = v ?? false),
                          ),
                          title: TextField(
                            controller: item.controller,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    items.removeAt(index);
                                    if (items.isEmpty) {
                                      items.add(
                                        _ActionItem(
                                          id: uuid.v4(),
                                          controller: TextEditingController(text: ''),
                                          done: false,
                                        ),
                                      );
                                    }
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          items.add(
                            _ActionItem(
                              id: uuid.v4(),
                              controller: TextEditingController(text: ''),
                              done: false,
                            ),
                          );
                        });
                      },
                      child: const Text('新增一条'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              TextButton(
                onPressed: () {
                  final completed = <String>[];
                  final pending = <String>[];
                  for (final item in items) {
                    final t = item.controller.text.trim();
                    if (t.isEmpty) continue;
                    if (item.done) {
                      completed.add(t);
                    } else {
                      pending.add(t);
                    }
                  }
                  Navigator.pop(
                    context,
                    AdvanceDialogResult(
                      nextActionText: pending.join('\n'),
                      completedActionsInOrder: completed,
                    ),
                  );
                },
                child: const Text('应用'),
              ),
            ],
          );
        },
      );
    },
  );
}

