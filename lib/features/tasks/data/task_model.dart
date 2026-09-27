class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String createdBy;
  final String assignedTo;
  final String status; // 'pending' | 'in_progress' | 'done'
  final String priority; // 'low' | 'medium' | 'high'
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.createdBy,
    required this.assignedTo,
    this.status = 'pending',
    this.priority = 'medium',
    this.dueDate,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isDone => status == 'done';
  bool get isInProgress => status == 'in_progress';
  bool get isPending => status == 'pending';

  bool get isOverdue {
    if (dueDate == null || isDone) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdBy: json['created_by'] as String,
      assignedTo: json['assigned_to'] as String,
      status: (json['status'] as String?) ?? 'pending',
      priority: (json['priority'] as String?) ?? 'medium',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String).toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'created_by': createdBy,
      'assigned_to': assignedTo,
      'status': status,
      'priority': priority,
      if (dueDate != null) 'due_date': dueDate!.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? createdBy,
    String? assignedTo,
    String? status,
    String? priority,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
