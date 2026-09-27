class ReminderModel {
  final String id;
  final String title;
  final String? note;
  final String ownerId;
  final bool isShared;
  final DateTime remindAt;
  final bool isCompleted;
  final DateTime createdAt;

  ReminderModel({
    required this.id,
    required this.title,
    this.note,
    required this.ownerId,
    this.isShared = false,
    required this.remindAt,
    this.isCompleted = false,
    required this.createdAt,
  });

  bool get isPast => remindAt.isBefore(DateTime.now()) && !isCompleted;

  int get notificationId => id.hashCode;

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      title: json['title'] as String,
      note: json['note'] as String?,
      ownerId: json['owner_id'] as String,
      isShared: (json['is_shared'] as bool?) ?? false,
      remindAt: DateTime.parse(json['remind_at'] as String).toLocal(),
      isCompleted: (json['is_completed'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (note != null) 'note': note,
      'owner_id': ownerId,
      'is_shared': isShared,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'is_completed': isCompleted,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  ReminderModel copyWith({
    String? id,
    String? title,
    String? note,
    String? ownerId,
    bool? isShared,
    DateTime? remindAt,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      ownerId: ownerId ?? this.ownerId,
      isShared: isShared ?? this.isShared,
      remindAt: remindAt ?? this.remindAt,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
