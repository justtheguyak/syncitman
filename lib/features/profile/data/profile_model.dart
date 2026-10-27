class ProfileModel {
  final String id;
  final String displayName;
  final String? partnerId;
  final String? rawAvatarUrl;
  final String? fcmToken;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.displayName,
    this.partnerId,
    this.rawAvatarUrl,
    this.fcmToken,
    required this.createdAt,
  });

  /// Returns clean avatar string (data:image..., http..., or emoji:...) stripped of metadata tags
  String? get avatarUrl {
    final raw = rawAvatarUrl;
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains('|||FCM:')) {
      final parts = raw.split('|||FCM:');
      final clean = parts[0].trim();
      return clean.isEmpty ? null : clean;
    }
    return raw;
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final raw = json['avatar_url'] as String?;
    String? cleanAvatar;
    String? token = json['fcm_token'] as String?;

    if (raw != null) {
      if (raw.contains('|||FCM:')) {
        final parts = raw.split('|||FCM:');
        cleanAvatar = parts[0].trim().isEmpty ? null : parts[0].trim();
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          token ??= parts[1].trim();
        }
      } else {
        cleanAvatar = raw;
      }
    }

    return ProfileModel(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? 'User',
      partnerId: json['partner_id'] as String?,
      rawAvatarUrl: cleanAvatar,
      fcmToken: token,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    String? combined = avatarUrl;
    if (fcmToken != null && fcmToken!.isNotEmpty) {
      combined = '${avatarUrl ?? ""}|||FCM:$fcmToken';
    }
    return {
      'id': id,
      'display_name': displayName,
      'partner_id': partnerId,
      'avatar_url': combined,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? displayName,
    String? partnerId,
    String? avatarUrl,
    String? fcmToken,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      partnerId: partnerId ?? this.partnerId,
      rawAvatarUrl: avatarUrl ?? this.avatarUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
