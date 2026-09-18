import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskCategory { school, work }

class TaskModel {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskCategory category;
  final bool isDone;
  final int notifyDaysBefore; // 0, 1, 2 o 3
  final int notifyHour; // 0-23, hora del día del aviso
  final int notifyMinute; // 0-59
  final DateTime? lastNudgeSentAt; // última vez que se envió el recordatorio semanal

  TaskModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.category,
    this.isDone = false,
    this.notifyDaysBefore = 1,
    this.notifyHour = 12,
    this.notifyMinute = 0,
    this.lastNudgeSentAt,
  });

  TaskModel copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    TaskCategory? category,
    bool? isDone,
    int? notifyDaysBefore,
    int? notifyHour,
    int? notifyMinute,
    DateTime? lastNudgeSentAt,
  }) {
    return TaskModel(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      isDone: isDone ?? this.isDone,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      notifyHour: notifyHour ?? this.notifyHour,
      notifyMinute: notifyMinute ?? this.notifyMinute,
      lastNudgeSentAt: lastNudgeSentAt ?? this.lastNudgeSentAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'category': category.name,
      'isDone': isDone,
      'notifyDaysBefore': notifyDaysBefore,
      'notifyHour': notifyHour,
      'notifyMinute': notifyMinute,
      'lastNudgeSentAt':
          lastNudgeSentAt != null ? Timestamp.fromDate(lastNudgeSentAt!) : null,
    };
  }

  factory TaskModel.fromMap(String id, Map<String, dynamic> map) {
    return TaskModel(
      id: id,
      ownerId: map['ownerId'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      category: TaskCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => TaskCategory.school,
      ),
      isDone: map['isDone'] as bool? ?? false,
      notifyDaysBefore: map['notifyDaysBefore'] as int? ?? 1,
      notifyHour: map['notifyHour'] as int? ?? 12,
      notifyMinute: map['notifyMinute'] as int? ?? 0,
      lastNudgeSentAt: map['lastNudgeSentAt'] != null
          ? (map['lastNudgeSentAt'] as Timestamp).toDate()
          : null,
    );
  }
}
