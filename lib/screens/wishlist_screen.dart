import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../services/db_service.dart';

class WishlistItem {
  final String id;
  final String title;
  final double costExp;
  bool isRedeemed;
  DateTime? redeemedAt;

  WishlistItem({
    required this.id,
    required this.title,
    required this.costExp,
    this.isRedeemed = false,
    this.redeemedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'costExp': costExp,
      'isRedeemed': isRedeemed,
      'redeemedAt': redeemedAt?.toIso8601String(),
    };
  }

  factory WishlistItem.fromMap(Map<String, dynamic> map) {
    return WishlistItem(
      id: map['id'],
      title: map['title'],
      costExp: (map['costExp'] as num).toDouble(),
      isRedeemed: map['isRedeemed'] ?? false,
      redeemedAt: map['redeemedAt'] != null ? DateTime.parse(map['redeemedAt']) : null,
    );
  }
}

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  double _currentExp = 0.0;
  List<WishlistItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Calculate total experience points from completed tasks
    final logs = await DBService().getAllLogs();
    double totalExp = 0;
    for (final log in logs) {
      if (log.action == 'done') {
        totalExp += log.energyValue;
      }
    }
    
    // Read spent experience points from SharedPreferences
    final spentExp = prefs.getDouble('spent_exp') ?? 0.0;
    
    _currentExp = totalExp - spentExp;
    if (_currentExp < 0) _currentExp = 0; // Prevent negative experience
    
    final itemsJson = prefs.getStringList('wishlist_items') ?? [];
    _items = itemsJson.map((e) => WishlistItem.fromMap(jsonDecode(e))).toList();
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveData({double? addedSpentExp}) async {
    final prefs = await SharedPreferences.getInstance();
    if (addedSpentExp != null) {
      final currentSpent = prefs.getDouble('spent_exp') ?? 0.0;
      await prefs.setDouble('spent_exp', currentSpent + addedSpentExp);
    }
    
    final itemsJson = _items.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList('wishlist_items', itemsJson);
  }

  void _showAddDialog() {
    final titleController = TextEditingController();
    final costController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加愿望'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '愿望名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '所需经验值'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              final cost = double.tryParse(costController.text.trim()) ?? 0.0;
              if (title.isNotEmpty && cost > 0) {
                setState(() {
                  _items.add(WishlistItem(
                    id: const Uuid().v4(),
                    title: title,
                    costExp: cost,
                  ));
                });
                _saveData();
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _redeemItem(WishlistItem item) {
    if (_currentExp >= item.costExp) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认兑换'),
          content: Text('确定要花费 ${item.costExp} 经验值兑换 "${item.title}" 吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentExp -= item.costExp;
                  item.isRedeemed = true;
                  item.redeemedAt = DateTime.now();
                });
                _saveData(addedSpentExp: item.costExp);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('成功兑换：${item.title}')),
                );
              },
              child: const Text('兑换'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('经验值不足，快去完成任务积攒经验吧！')),
      );
    }
  }
  
  void _deleteItem(WishlistItem item) {
     setState(() {
        _items.removeWhere((element) => element.id == item.id);
     });
     _saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeItems = _items.where((e) => !e.isRedeemed).toList();
    final redeemedItems = _items.where((e) => e.isRedeemed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('愿望清单'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Column(
              children: [
                const Text('当前可用经验值', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  _currentExp.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('完成任务会自动将能量转化为经验值', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (activeItems.isEmpty && redeemedItems.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text('还没有愿望，点击右下角添加一个吧！', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                
                if (activeItems.isNotEmpty) ...[
                  const Text('待兑换', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...activeItems.map((item) {
                    final progress = (_currentExp / item.costExp).clamp(0.0, 1.0);
                    final canRedeem = _currentExp >= item.costExp;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                  onPressed: () => _deleteItem(item),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[200],
                                      color: canRedeem ? Colors.green : Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('${_currentExp.toStringAsFixed(0)} / ${item.costExp.toStringAsFixed(0)}'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: canRedeem ? () => _redeemItem(item) : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canRedeem ? Colors.green : null,
                                  foregroundColor: canRedeem ? Colors.white : null,
                                ),
                                child: Text(canRedeem ? '立即兑换' : '经验不足'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                if (redeemedItems.isNotEmpty) ...[
                  const Text('已实现', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  ...redeemedItems.map((item) {
                    String dateStr = '';
                    if (item.redeemedAt != null) {
                      dateStr = '${item.redeemedAt!.year}-${item.redeemedAt!.month.toString().padLeft(2, '0')}-${item.redeemedAt!.day.toString().padLeft(2, '0')}';
                    }
                    return Card(
                      color: Colors.grey[100],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          item.title,
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                        subtitle: dateStr.isNotEmpty ? Text('实现于: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
