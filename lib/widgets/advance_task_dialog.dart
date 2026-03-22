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
            title: const Text('编辑子动作'),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
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
                        return Padding(
                          key: ValueKey(item.id),
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Transform.scale(
                                scale: 0.7,
                                child: Checkbox(
                                  value: item.done,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (v) => setState(() => item.done = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: TextField(
                                  controller: item.controller,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
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
                                icon: const Icon(Icons.delete_outline, size: 20),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  child: Icon(Icons.drag_handle, size: 20),
                                ),
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
