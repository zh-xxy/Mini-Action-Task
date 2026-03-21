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
    double parseDouble(dynamic value, double defaultValue) {
      if (value == null || value.toString().isEmpty) return defaultValue;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    DateTime parseDateTime(dynamic value, DateTime defaultValue) {
      if (value == null || value.toString().isEmpty || value.toString() == 'null') return defaultValue;
      return DateTime.tryParse(value.toString()) ?? defaultValue;
    }

    return LogEntry(
      id: map['id']?.toString() ?? '',
      taskId: map['task_id']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      energyValue: parseDouble(map['energy_value'], 0.0),
      note: map['note']?.toString() ?? '',
      createdAt: parseDateTime(map['created_at'], DateTime.now()),
    );
  }
}