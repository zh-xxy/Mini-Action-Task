import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/log_entry.dart';
import '../models/task.dart';

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  Database? _db;
  final List<Task> _mockTasks = [];
  final List<LogEntry> _mockLogs = [];

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await initDatabase();
    return _db!;
  }

  Future<Database> initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not supported on Web');
    }
    final path = join(await getDatabasesPath(), 'offline_task_app.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT,
            status TEXT,
            type TEXT,
            priority INTEGER,
            urgency INTEGER,
            importance TEXT,
            due_in_days INTEGER,
            due_date TEXT,
            energy_estimate REAL,
            low_energy_ok INTEGER,
            next_action TEXT,
            note TEXT,
            parent_id TEXT,
            created_at TEXT,
            last_progress_at TEXT,
            last_done_at TEXT,
            deleted_at TEXT,
            frozen_reason TEXT,
            frozen_at TEXT,
            action_history TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE logs (
            id TEXT PRIMARY KEY,
            task_id TEXT,
            action TEXT,
            energy_value REAL,
            note TEXT,
            created_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN due_date TEXT');
          await db.execute('ALTER TABLE tasks ADD COLUMN frozen_reason TEXT');
          await db.execute('ALTER TABLE tasks ADD COLUMN frozen_at TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE tasks ADD COLUMN note TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE tasks ADD COLUMN deleted_at TEXT');
        }
      },
    );
  }

  Future<void> insertTask(Task task) async {
    if (kIsWeb) {
      final index = _mockTasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        _mockTasks[index] = task;
      } else {
        _mockTasks.add(task);
      }
      return;
    }
    final db = await database;
    await db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTask(Task task) async {
    if (kIsWeb) {
      final index = _mockTasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        _mockTasks[index] = task;
      }
      return;
    }
    final db = await database;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> softDeleteTask(Task task) async {
    task.status = 'deleted';
    task.deletedAt = DateTime.now();
    await updateTask(task);
  }

  Future<List<Task>> getAllTasks() async {
    if (kIsWeb) return _mockTasks;
    final db = await database;
    final maps = await db.query('tasks');
    return maps.map((e) => Task.fromMap(e)).toList();
  }

  Future<List<Task>> getTasksByStatus({
    required String status,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (kIsWeb) {
      final list = _mockTasks.where((t) => t.status == status).toList();
      if (status == 'in_progress') {
        list.sort((a, b) => (b.priority * 10 + b.urgency).compareTo(a.priority * 10 + a.urgency));
      } else if (status == 'done') {
        list.sort((a, b) => (b.lastDoneAt ?? b.lastProgressAt ?? b.createdAt).compareTo(a.lastDoneAt ?? a.lastProgressAt ?? a.createdAt));
      } else {
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      if (offset != null && offset > 0 && offset < list.length) {
        final sliced = list.sublist(offset);
        if (limit != null && limit < sliced.length) return sliced.sublist(0, limit);
        return sliced;
      }
      if (limit != null && limit < list.length) return list.sublist(0, limit);
      return list;
    }
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return maps.map((e) => Task.fromMap(e)).toList();
  }

  Future<List<Task>> getActiveTasks() async {
    if (kIsWeb) return _mockTasks.where((t) => t.status != 'deleted').toList();
    final db = await database;
    final maps = await db.query('tasks', where: 'status != ?', whereArgs: ['deleted']);
    return maps.map((e) => Task.fromMap(e)).toList();
  }

  Future<void> insertLog(LogEntry log) async {
    if (kIsWeb) {
      _mockLogs.add(log);
      return;
    }
    final db = await database;
    await db.insert('logs', log.toMap());
  }

  Future<List<LogEntry>> getRecentLogs({int days = 3}) async {
    if (kIsWeb) {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      return _mockLogs.where((l) => l.createdAt.isAfter(cutoff) || l.createdAt.isAtSameMomentAs(cutoff)).toList();
    }
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final maps = await db.query('logs', where: 'created_at >= ?', whereArgs: [cutoff]);
    return maps.map((e) => LogEntry.fromMap(e)).toList();
  }

  Future<List<LogEntry>> getAllLogs() async {
    if (kIsWeb) return _mockLogs;
    final db = await database;
    final maps = await db.query('logs');
    return maps.map((e) => LogEntry.fromMap(e)).toList();
  }

  // --- CSV Export/Import ---

  Future<String> exportTasksCsv() async {
    if (kIsWeb) {
      throw UnsupportedError('Export is not supported on Web');
    }
    final tasks = await getAllTasks();
    final rows = <List<dynamic>>[];
    rows.add([
      'id', 'title', 'status', 'type', 'priority', 'urgency', 'importance',
      'due_in_days', 'energy_estimate', 'low_energy_ok', 'next_action', 'note',
      'parent_id', 'created_at', 'last_progress_at', 'last_done_at', 'deleted_at', 'action_history'
    ]);
    for (final t in tasks) {
      final m = t.toMap();
      rows.add([
        m['id'], m['title'], m['status'], m['type'], m['priority'], m['urgency'], m['importance'],
        m['due_in_days'], m['energy_estimate'], m['low_energy_ok'], m['next_action'], m['note'],
        m['parent_id'], m['created_at'], m['last_progress_at'], m['last_done_at'], m['deleted_at'], m['action_history']
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/tasks_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    return file.path;
  }

  Future<int> importTasksFromCsv(String filePath) async {
    final file = File(filePath);
    final csvString = await file.readAsString();
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
    
    if (rows.isEmpty) return 0;
    
    // Assume first row is header
    final header = rows[0].map((e) => e.toString()).toList();
    int count = 0;
    
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final Map<String, dynamic> map = {};
      for (int j = 0; j < header.length; j++) {
        if (j < row.length) {
          map[header[j]] = row[j];
        }
      }
      try {
        final task = Task.fromMap(map);
        await insertTask(task);
        count++;
      } catch (e) {
        print('Error importing row $i: $e');
      }
    }
    return count;
  }

  Future<String> exportLogsCsv() async {
    if (kIsWeb) {
      throw UnsupportedError('Export is not supported on Web');
    }
    final logs = await getAllLogs();
    final rows = <List<dynamic>>[];
    rows.add(['id', 'task_id', 'action', 'energy_value', 'note', 'created_at']);
    for (final l in logs) {
      final m = l.toMap();
      rows.add([m['id'], m['task_id'], m['action'], m['energy_value'], m['note'], m['created_at']]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/logs_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    return file.path;
  }

  // --- Database Backup/Restore ---

  Future<String> backupDatabase() async {
    if (kIsWeb) throw UnsupportedError('Backup is not supported on Web');
    
    final dbPath = join(await getDatabasesPath(), 'offline_task_app.db');
    final file = File(dbPath);
    
    if (!await file.exists()) throw Exception('Database file not found');
    
    final backupDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final backupPath = join(backupDir.path, 'mini_action_task_backup_${DateTime.now().millisecondsSinceEpoch}.db');
    
    await file.copy(backupPath);
    return backupPath;
  }

  Future<void> restoreDatabase(String backupFilePath) async {
    if (kIsWeb) throw UnsupportedError('Restore is not supported on Web');
    
    final dbPath = join(await getDatabasesPath(), 'offline_task_app.db');
    
    // Close existing connection
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    
    final backupFile = File(backupFilePath);
    await backupFile.copy(dbPath);
    
    // Re-initialize
    await database;
  }

  // --- Other Data ---

  Future<void> saveQuotes(List<String> quotes) async {
    if (kIsWeb) return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/custom_quotes.txt');
    await file.writeAsString(quotes.join('\n'));
  }

  Future<List<String>> getQuotes() async {
    if (kIsWeb) return [];
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/custom_quotes.txt');
      if (await file.exists()) {
        final content = await file.readAsString();
        return content.split('\n').where((s) => s.trim().isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, String>> getUserProfile() async {
    if (kIsWeb) return {'name': 'User', 'signature': '点击编辑签名', 'avatarPath': ''};
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user_profile.txt');
      if (await file.exists()) {
        final lines = (await file.readAsString()).split('\n');
        return {
          'name': lines.isNotEmpty ? lines[0] : 'User',
          'signature': lines.length > 1 ? lines[1] : '点击编辑签名',
          'avatarPath': lines.length > 2 ? lines[2] : '',
        };
      }
    } catch (_) {}
    return {'name': 'User', 'signature': '点击编辑签名', 'avatarPath': ''};
  }

  Future<void> saveUserProfile(String name, String signature, String avatarPath) async {
    if (kIsWeb) return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/user_profile.txt');
    await file.writeAsString('$name\n$signature\n$avatarPath');
  }

  Future<int> getAutoFreezeOverdueDays() async {
    if (kIsWeb) return 10;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/auto_freeze_overdue_days.txt');
      if (!await file.exists()) return 10;
      final text = (await file.readAsString()).trim();
      final parsed = int.tryParse(text);
      if (parsed == null || parsed < 0) return 10;
      return parsed;
    } catch (_) {
      return 10;
    }
  }

  Future<void> saveAutoFreezeOverdueDays(int days) async {
    if (kIsWeb) return;
    final safe = days < 0 ? 0 : days;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/auto_freeze_overdue_days.txt');
    await file.writeAsString(safe.toString());
  }

}
