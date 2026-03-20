import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mini_action_task/services/db_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final DBService _dbService = DBService();
  String _version = '1.0.3';
  String _name = 'User';
  String _signature = '点击编辑签名';
  String _avatarPath = '';
  double _totalExp = 0;
  double _todayExp = 0;
  int _level = 1;
  double _currentLevelExp = 0;
  double _needExpForNext = 10;
  String _levelTitle = '见习行动者';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadCustomQuotes();
    _loadVersion();
    _loadExperience();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _dbService.getUserProfile();
    setState(() {
      _name = profile['name']!;
      _signature = profile['signature']!;
      _avatarPath = profile['avatarPath']!;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _version = '1.0.3';
      });
    }
  }

  double _expNeedForLevel(int level) {
    return 10 + (level - 1) * 5;
  }

  String _titleForLevel(int level) {
    if (level >= 35) return '🏆 传说执行官';
    if (level >= 25) return '🛡️ 战术总监';
    if (level >= 18) return '⚔️ 高阶推进者';
    if (level >= 12) return '🔥 稳定输出者';
    if (level >= 6) return '🚀 行动加速者';
    return '🌱 见习行动者';
  }

  Future<void> _loadExperience() async {
    final logs = await _dbService.getAllLogs();
    final now = DateTime.now();
    double total = 0;
    double today = 0;
    for (final log in logs) {
      if (log.action != 'done') continue;
      total += log.energyValue;
      final t = log.createdAt;
      if (t.year == now.year && t.month == now.month && t.day == now.day) {
        today += log.energyValue;
      }
    }

    int level = 1;
    double remain = total;
    double need = _expNeedForLevel(level);
    while (remain >= need) {
      remain -= need;
      level++;
      need = _expNeedForLevel(level);
    }

    if (!mounted) return;
    setState(() {
      _totalExp = total;
      _todayExp = today;
      _level = level;
      _currentLevelExp = remain;
      _needExpForNext = need;
      _levelTitle = _titleForLevel(level);
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarPath = pickedFile.path;
      });
      _saveProfile();
    }
  }

  void _editName() {
    final controller = TextEditingController(text: _name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              setState(() => _name = controller.text);
              _saveProfile();
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _editSignature() {
    final controller = TextEditingController(text: _signature);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改签名'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              setState(() => _signature = controller.text);
              _saveProfile();
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _saveProfile() {
    _dbService.saveUserProfile(_name, _signature, _avatarPath);
  }

  Future<void> _loadCustomQuotes() async {
    await _dbService.getQuotes();
  }

  void _editQuotes() async {
    final quotes = await _dbService.getQuotes();
    final initialText = quotes.join('\n');
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: initialText);
        return AlertDialog(
          title: const Text('今日提醒语录库'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('每行一句，回车分隔'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final text = controller.text;
                final quotes = text.split('\n').where((s) => s.trim().isNotEmpty).toList();
                await _dbService.saveQuotes(quotes);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存 ${quotes.length} 条提醒')));
                if (mounted) Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      }
    );
  }

  // --- New Backup & Restore Methods ---

  void _handleBackup() async {
    try {
      final path = await _dbService.backupDatabase();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('备份成功: $path')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('备份失败: $e')));
    }
  }

  void _handleRestore() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      try {
        await _dbService.restoreDatabase(result.files.single.path!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据库已恢复，请重启应用以生效')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('恢复失败: $e')));
      }
    }
  }

  void _handleImportCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null && result.files.single.path != null) {
      try {
        final count = await _dbService.importTasksFromCsv(result.files.single.path!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('成功导入 $count 条任务')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  void _exportTasks() async {
    try {
      final path = await _dbService.exportTasksCsv();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tasks 已导出至: $path')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: GestureDetector(
              onTap: _editName,
              child: Text(_name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            accountEmail: GestureDetector(
              onTap: _editSignature,
              child: Text(_signature),
            ),
            currentAccountPicture: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                backgroundImage: _avatarPath.isNotEmpty ? FileImage(File(_avatarPath)) : null,
                child: _avatarPath.isEmpty ? const Icon(Icons.person, size: 40) : null,
              ),
            ),
            decoration: const BoxDecoration(color: Colors.blue),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Card(
              elevation: 0,
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lv.$_level  $_levelTitle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('总经验 ${_totalExp.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _needExpForNext <= 0 ? 0 : (_currentLevelExp / _needExpForNext).clamp(0, 1),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '距离下一等级还差 ${(_needExpForNext - _currentLevelExp).clamp(0, _needExpForNext).toStringAsFixed(1)} 经验',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(
                          label: Text('今日 +${_todayExp.toStringAsFixed(1)} EXP'),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(_todayExp >= 5 ? '⚡ 今日高能' : '🧭 保持推进'),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(_level >= 10 ? '🎯 十级成就' : '🎯 向十级冲刺'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('数据管理', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: const Text('备份数据库'),
            subtitle: const Text('将当前数据保存为 .db 文件'),
            onTap: _handleBackup,
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('恢复数据库'),
            subtitle: const Text('从 .db 文件中恢复所有数据'),
            onTap: _handleRestore,
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('导出任务 (CSV)'),
            onTap: _exportTasks,
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('导入任务 (CSV)'),
            onTap: _handleImportCsv,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.format_quote),
            title: const Text('自定义今日提醒'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editQuotes,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App 版本'),
            subtitle: Text(_version),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
