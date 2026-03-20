class LogEntry {
  String id;
  String taskId;
  String action; // advance / done / delete / create / edit
  double energyValue;
  String note;
  DateTime createdAt;

  LogEntry({
    required this.id,
    required this.taskId,
    required this.action,
    required this.energyValue,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'action': action,
      'energy_value': energyValue,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'],
      taskId: map['task_id'],
      action: map['action'],
      energyValue: map['energy_value'],
      note: map['note'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}