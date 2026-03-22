import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mini_action_task/services/db_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mini_action_task/services/notification_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final DBService _dbService = DBService();
  static final Uri _releaseUri = Uri.parse('https://github.com/zh-xxy/Mini-Action-Task/releases');
  String _version = '1.0.6';
  String _name = 'User';
  String _signature = '点击编辑签名';
  String _avatarPath = '';
  double _totalExp = 0;
  double _todayExp = 0;
  int _level = 1;
  double _currentLevelExp = 0;
  double _needExpForNext = 10;
  String _levelTitle = '见习行动者';
  int _autoFreezeOverdueDays = 10;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadCustomQuotes();
    _loadVersion();
    _loadExperience();
    _loadAutoFreezeOverdueDays();
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
        _version = '1.0.6';
      });
    }
  }

  Future<void> _loadAutoFreezeOverdueDays() async {
    final value = await _dbService.getAutoFreezeOverdueDays();
    if (!mounted) return;
    setState(() {
      _autoFreezeOverdueDays = value;
    });
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

  String _formatEnergy(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.replaceFirst(RegExp(r'\.$'), '');
  }

  List<String> _achievementLabels() {
    final labels = <String>['今日 +${_formatEnergy(_todayExp)} EXP'];

    String levelProgress;
    if (_level < 5) {
      levelProgress = '🎯 向五级冲刺';
    } else if (_level < 10) {
      levelProgress = '🏅 五级达成，向十级冲刺';
    } else if (_level < 15) {
      levelProgress = '🎯 十级成就，向十五级冲刺';
    } else {
      levelProgress = '🌟 里程碑';
    }
    labels.add(levelProgress);

    String stateLabel;
    if (_todayExp >= 8) {
      stateLabel = '🔥 今日爆发';
    } else if (_todayExp >= 5) {
      stateLabel = '⚡ 今日高能';
    } else if (_todayExp > 0) {
      stateLabel = '✅ 今日推进';
    } else {
      stateLabel = '🧭 保持推进';
    }
    labels.add(stateLabel);
    if (_level < 5) {
      labels.add('🌱 新手起步');
    }

    return labels;
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('备份成功'),
            content: Text('已备份至: $path\n\n【重要提示】\n备份文件默认保存在应用私有目录下。请务必前往文件管理器将.db文件复制到其他目录（但有些系统可能不支持复制.db文件，则优先导出csv），否则卸载app后备份文件也会一并丢失！'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      }
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
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入数据'),
        content: const Text('为了完整恢复您的数据（包括任务列表、历史统计、经验等级、愿望清单等），建议先后导入 "tasks_export" 和 "logs_export" 两个 CSV 文件。\n\n点击“继续”选择其中一个文件进行导入。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('继续选择文件')),
        ],
      ),
    );

    if (proceed != true) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null && result.files.single.path != null) {
      try {
        final path = result.files.single.path!;
        CsvImportResult importResult;
        bool isTask = false;
        final kind = await _dbService.detectCsvFileKind(path);
        if (kind == CsvFileKind.tasks) {
          isTask = true;
          importResult = await _dbService.importTasksFromCsv(path);
        } else if (kind == CsvFileKind.logs) {
          importResult = await _dbService.importLogsFromCsv(path);
        } else {
          throw Exception('无法识别 CSV 类型，请确认文件为正确的导出格式');
        }
        
        if (mounted) {
          String message = '成功导入 ${importResult.successCount} 条';
          if (importResult.failureCount > 0) {
            message += '，失败 ${importResult.failureCount} 条';
          }
          if (isTask) {
            message += '。提示：记得再次点击导入以选择 logs 文件。';
          }
          message += '\n【注意】请重新打开 App 以刷新并查看最新任务数据。';
          if (importResult.errors.isNotEmpty) {
            final preview = importResult.errors.take(2).join('；');
            message += '\n错误示例：$preview';
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  void _exportAllCsv() async {
    try {
      final taskPath = await _dbService.exportTasksCsv();
      final logPath = await _dbService.exportLogsCsv();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('导出成功'),
            content: Text('已导出:\nTasks: $taskPath\nLogs (包含愿望清单): $logPath\n\n【重要提示】\n备份文件默认保存在应用私有目录下。请务必前往文件管理器将这两个.csv文件复制/移动到其他目录，否则卸载app后备份文件也会一并丢失！'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  void _editAutoFreezeOverdueDays() async {
    final controller = TextEditingController(text: _autoFreezeOverdueDays.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动冻结阈值'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '超过剩余天数后自动冻结',
            suffixText: '天',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.pop(context, parsed);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final safe = value < 0 ? 0 : value;
    await _dbService.saveAutoFreezeOverdueDays(safe);
    if (!mounted) return;
    setState(() {
      _autoFreezeOverdueDays = safe;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('自动冻结阈值已更新')));
  }

  Future<void> _openUrl(Uri uri) async {
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('链接打开失败')));
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
                        Text('总经验 ${_formatEnergy(_totalExp)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
                      '距离下一等级还差 ${_formatEnergy((_needExpForNext - _currentLevelExp).clamp(0, _needExpForNext))} 经验',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _achievementLabels()
                          .map((label) => Chip(label: Text(label), visualDensity: VisualDensity.compact))
                          .toList(),
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
            title: const Text('导出全部数据 (CSV)'),
            subtitle: const Text('连带导出任务与动作日志'),
            onTap: _exportAllCsv,
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('导入数据 (CSV)'),
            subtitle: const Text('建议先后导入 tasks 和 logs 文件以完整恢复'),
            onTap: _handleImportCsv,
          ),
          ListTile(
            leading: const Icon(Icons.settings_suggest),
            title: const Text('自动冻结设置'),
            subtitle: Text('任务超期 ${_autoFreezeOverdueDays} 天自动冻结'),
            onTap: _editAutoFreezeOverdueDays,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.format_quote),
            title: const Text('自定义今日提醒语录库'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editQuotes,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App 版本'),
            subtitle: Text(_version),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('测试提醒通知'),
            subtitle: const Text('点击发送一条测试通知'),
            onTap: () {
              NotificationService().testNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已发送测试通知，请留意顶部状态栏')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('检查更新'),
            subtitle: const Text('查看 GitHub Releases'),
            onTap: () => _openUrl(_releaseUri),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
