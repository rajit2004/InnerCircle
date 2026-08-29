class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String subscriptionTier;
  final int messagesUsedToday;
  final int dailyMessageLimit;
  final DateTime? memberSince;
  final DateTime? updatedAt;
  final String? language;
  final String? timezone;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    required this.subscriptionTier,
    required this.messagesUsedToday,
    required this.dailyMessageLimit,
    this.memberSince,
    this.updatedAt,
    this.language,
    this.timezone,
  });

  bool get isPremium => subscriptionTier.toLowerCase() == 'premium';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
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
    );
  }
}
