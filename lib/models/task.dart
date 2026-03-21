import 'dart:convert';


class Task {
  String id;
  String title;
  String status; // todo / in_progress / done / frozen / deleted
  String type;
  int priority;
  int urgency;
  String importance; // 日常 / 习惯 / 支线 / 副本 / 主线
  DateTime? dueDate;
  double energyEstimate;
  bool lowEnergyOk;
  String nextAction;
  String note;
  String? parentId;
  DateTime createdAt;
  DateTime? lastProgressAt;
  DateTime? lastDoneAt;
  DateTime? deletedAt;
  String? frozenReason;
  DateTime? frozenAt;
  List<Map<String, dynamic>> actionHistory;

  Task({
    required this.id,
    required this.title,
    this.status = 'todo',
    this.type = 'task',
    this.priority = 0,
    this.urgency = 0,
    this.importance = '日常',
    int dueInDays = 0,
    this.dueDate,
    this.energyEstimate = 1.0,
    this.lowEnergyOk = false,
    this.nextAction = '',
    this.note = '',
    this.parentId,
    required this.createdAt,
    this.lastProgressAt,
    this.lastDoneAt,
    this.deletedAt,
    this.frozenReason,
    this.frozenAt,
    this.actionHistory = const [],
  }) {
    dueDate ??= DateTime.now().add(Duration(days: dueInDays));
  }

  int get dueInDays {
    if (dueDate == null) return 0;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  set dueInDays(int value) {
    dueDate = DateTime.now().add(Duration(days: value));
  }

  Task copyWith({
    String? id,
    String? title,
    String? status,
    String? type,
    int? priority,
    int? urgency,
    String? importance,
    int? dueInDays,
    DateTime? dueDate,
    double? energyEstimate,
    bool? lowEnergyOk,
    String? nextAction,
    String? note,
    String? parentId,
    DateTime? createdAt,
    DateTime? lastProgressAt,
    DateTime? lastDoneAt,
    DateTime? deletedAt,
    String? frozenReason,
    DateTime? frozenAt,
    List<Map<String, dynamic>>? actionHistory,
  }) {
    final nextDueDate = dueDate ?? (dueInDays != null ? DateTime.now().add(Duration(days: dueInDays)) : this.dueDate);
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      urgency: urgency ?? this.urgency,
      importance: importance ?? this.importance,
      dueDate: nextDueDate,
      energyEstimate: energyEstimate ?? this.energyEstimate,
      lowEnergyOk: lowEnergyOk ?? this.lowEnergyOk,
      nextAction: nextAction ?? this.nextAction,
      note: note ?? this.note,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
      lastDoneAt: lastDoneAt ?? this.lastDoneAt,
      deletedAt: deletedAt ?? this.deletedAt,
      frozenReason: frozenReason ?? this.frozenReason,
      frozenAt: frozenAt ?? this.frozenAt,
      actionHistory: actionHistory ?? this.actionHistory.map((item) => Map<String, dynamic>.from(item)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'type': type,
      'priority': priority,
      'urgency': urgency,
      'importance': importance,
      'due_in_days': dueInDays,
      'due_date': dueDate?.toIso8601String(),
      'energy_estimate': energyEstimate,
      'low_energy_ok': lowEnergyOk ? 1 : 0,
      'next_action': nextAction,
      'note': note,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
      'last_progress_at': lastProgressAt?.toIso8601String(),
      'last_done_at': lastDoneAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'frozen_reason': frozenReason,
      'frozen_at': frozenAt?.toIso8601String(),
      'action_history': jsonEncode(actionHistory),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic value, int defaultValue) {
      if (value == null || value.toString().isEmpty) return defaultValue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    double parseDouble(dynamic value, double defaultValue) {
      if (value == null || value.toString().isEmpty) return defaultValue;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    bool parseBool(dynamic value, bool defaultValue) {
      if (value == null || value.toString().isEmpty) return defaultValue;
      if (value is bool) return value;
      if (value is int) return value == 1;
      return value.toString() == '1' || value.toString().toLowerCase() == 'true';
    }

    DateTime? parseDateTime(dynamic value) {
      if (value == null || value.toString().isEmpty || value.toString() == 'null') return null;
      return DateTime.tryParse(value.toString());
    }

    return Task(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      status: map['status']?.toString() ?? 'todo',
      type: map['type']?.toString() ?? 'task',
      priority: parseInt(map['priority'], 0),
      urgency: parseInt(map['urgency'], 0),
      importance: map['importance']?.toString() ?? '日常',
      dueDate: parseDateTime(map['due_date']) ?? DateTime.now().add(Duration(days: parseInt(map['due_in_days'], 0))),
      energyEstimate: parseDouble(map['energy_estimate'], 1.0),
      lowEnergyOk: parseBool(map['low_energy_ok'], false),
      nextAction: map['next_action']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      parentId: map['parent_id']?.toString().isNotEmpty == true ? map['parent_id']?.toString() : null,
      createdAt: parseDateTime(map['created_at']) ?? DateTime.now(),
      lastProgressAt: parseDateTime(map['last_progress_at']),
      lastDoneAt: parseDateTime(map['last_done_at']),
      deletedAt: parseDateTime(map['deleted_at']),
      frozenReason: map['frozen_reason']?.toString().isNotEmpty == true ? map['frozen_reason']?.toString() : null,
      frozenAt: parseDateTime(map['frozen_at']),
      actionHistory: List<Map<String, dynamic>>.from(jsonDecode((map['action_history']?.toString() ?? '').isEmpty ? '[]' : map['action_history'].toString())),
    );
  }
}
