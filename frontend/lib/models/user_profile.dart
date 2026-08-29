class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String subscriptionTier;
  final int messagesUsedToday;
  final int dailyMessageLimit;
  final DateTime? memberSince;
  final DateTime? updatedAt;
  final String? language;
  final String? timezone;
  final DateTime? dateOfBirth;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.subscriptionTier,
    required this.messagesUsedToday,
    required this.dailyMessageLimit,
    this.memberSince,
    this.updatedAt,
    this.language,
    this.timezone,
    this.dateOfBirth,
  });

  bool get isPremium => subscriptionTier.toLowerCase() == 'premium';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'],
      subscriptionTier: json['subscriptionTier'] ?? 'free',
      messagesUsedToday: json['messagesUsedToday'] ?? 0,
      dailyMessageLimit: json['dailyMessageLimit'] ?? 0,
      memberSince: json['memberSince'] != null
          ? DateTime.tryParse(json['memberSince'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      language: json['language'],
      timezone: json['timezone'],
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'])
          : null,
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? language,
    String? timezone,
    DateTime? dateOfBirth,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscriptionTier: subscriptionTier,
      messagesUsedToday: messagesUsedToday,
      dailyMessageLimit: dailyMessageLimit,
      memberSince: memberSince,
      updatedAt: updatedAt,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}
