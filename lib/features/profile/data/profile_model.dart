class ProfileModel {
  final String id;
  final String displayName;
  final String? partnerId;
  final String? avatarUrl;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.displayName,
    this.partnerId,
    this.avatarUrl,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? 'User',
      partnerId: json['partner_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'partner_id': partnerId,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? displayName,
    String? partnerId,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      partnerId: partnerId ?? this.partnerId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
